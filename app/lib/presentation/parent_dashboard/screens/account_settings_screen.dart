import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/datasources/remote/supabase_client.dart';
import '../../../data/repositories/profile_repository.dart';
import '../../../domain/services/parental_control_service.dart';
import '../../../routing/route_names.dart';
import '../../../utils/biometric_helper.dart';

class AccountSettingsScreen extends ConsumerStatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  ConsumerState<AccountSettingsScreen> createState() =>
      _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends ConsumerState<AccountSettingsScreen> {
  bool _isDeletingChild = false;
  bool _isDeletingAccount = false;

  // Brute-force protection for PIN fallback
  static int _pinAttempts = 0;
  static DateTime? _lockoutUntil;
  static int _lockoutDurationSeconds = 30;
  static const int _maxPinAttempts = 5;

  static void _resetPinCounters() {
    _pinAttempts = 0;
    _lockoutUntil = null;
    _lockoutDurationSeconds = 30;
  }

  /// Re-authenticate the user via biometrics or a PIN dialog fallback.
  /// Returns true if the user successfully authenticated.
  Future<bool> _reauthenticate() async {
    final biometricSuccess = await BiometricHelper.authenticate(
      reason: 'Verify your identity to continue',
    );
    if (biometricSuccess) return true;

    // Check lockout before showing PIN dialog
    if (_lockoutUntil != null && DateTime.now().isBefore(_lockoutUntil!)) {
      final remaining = _lockoutUntil!.difference(DateTime.now()).inSeconds;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Too many failed attempts. Try again in $remaining seconds.',
            ),
          ),
        );
      }
      return false;
    }

    // Fallback: show a PIN dialog that verifies against the stored hash
    if (!mounted) return false;
    final pinController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final remainingAttempts = _maxPinAttempts - _pinAttempts;
            return AlertDialog(
              title: const Text('Enter PIN'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: pinController,
                    obscureText: true,
                    maxLength: 4,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(hintText: '4-digit PIN'),
                  ),
                  if (remainingAttempts < _maxPinAttempts)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '$remainingAttempts attempts remaining',
                        style: TextStyle(
                          color: remainingAttempts <= 2
                              ? Colors.red
                              : Colors.orange,
                          fontSize: 13,
                        ),
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final pin = pinController.text;
                    if (pin.length != 4) return;
                    final verified =
                        await ParentalControlService.verifyPin(pin);
                    if (ctx.mounted) {
                      if (verified) {
                        _resetPinCounters();
                        Navigator.pop(ctx, true);
                      } else {
                        _pinAttempts++;
                        if (_pinAttempts >= _maxPinAttempts) {
                          _lockoutUntil = DateTime.now().add(
                            Duration(seconds: _lockoutDurationSeconds),
                          );
                          _lockoutDurationSeconds =
                              (_lockoutDurationSeconds * 2).clamp(30, 3600);
                          _pinAttempts = 0;
                          if (ctx.mounted) {
                            Navigator.pop(ctx, false);
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Too many failed attempts. Locked for '
                                  '${_lockoutDurationSeconds ~/ 2} seconds.',
                                ),
                              ),
                            );
                          }
                        } else {
                          pinController.clear();
                          setDialogState(() {});
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Incorrect PIN. '
                                '${_maxPinAttempts - _pinAttempts} attempts remaining.',
                              ),
                            ),
                          );
                        }
                      }
                    }
                  },
                  child: const Text('Confirm'),
                ),
              ],
            );
          },
        );
      },
    );
    pinController.dispose();
    return result ?? false;
  }

  Future<void> _deleteChildProfile(String childId, String childName) async {
    // Require re-authentication before showing the confirmation dialog
    final authenticated = await _reauthenticate();
    if (!authenticated || !mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Child Profile'),
        content: Text(
          'Are you sure you want to delete "$childName"\'s profile? '
          'This will permanently remove all their watch history, '
          'screen time data, and preferences. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isDeletingChild = true);
    try {
      await SupabaseClientWrapper.client.rpc(
        'delete_child_data',
        params: {'target_child_id': childId},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$childName\'s profile deleted')),
        );
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete profile. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isDeletingChild = false);
    }
  }

  Future<void> _deleteAccount() async {
    // Require re-authentication before showing the confirmation dialog
    final authenticated = await _reauthenticate();
    if (!authenticated || !mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'Are you sure you want to delete your entire account? '
          'This will permanently remove all child profiles, watch history, '
          'preferences, and all associated data. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete My Account'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isDeletingAccount = true);
    try {
      final userId = SupabaseClientWrapper.currentUserId;
      if (userId == null) return;

      await SupabaseClientWrapper.client.rpc(
        'delete_parent_account',
        params: {'target_user_id': userId},
      );

      await SupabaseClientWrapper.auth.signOut();

      if (mounted) {
        context.goNamed(RouteNames.login);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete account. Please try again.'),
          ),
        );
        setState(() => _isDeletingAccount = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = SupabaseClientWrapper.currentUserId;

    return Scaffold(
      appBar: AppBar(title: const Text('Account Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Account info
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Account',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    SupabaseClientWrapper.auth.currentUser?.email ?? 'No email',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Child profiles section
          const Text(
            'Child Profiles',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (userId != null)
            FutureBuilder(
              future: ProfileRepository().getChildren(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final children = snapshot.data ?? [];
                if (children.isEmpty) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No child profiles'),
                    ),
                  );
                }
                return Column(
                  children: children.map((child) {
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text(
                            child.name.isNotEmpty
                                ? child.name[0].toUpperCase()
                                : '?',
                          ),
                        ),
                        title: Text(child.name),
                        trailing: _isDeletingChild
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.red,
                                ),
                                onPressed: () =>
                                    _deleteChildProfile(child.id, child.name),
                              ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),

          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 16),

          // Danger zone
          const Text(
            'Danger Zone',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Deleting your account is permanent and cannot be undone. '
            'All child profiles, watch history, and preferences will be removed.',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isDeletingAccount ? null : _deleteAccount,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: _isDeletingAccount
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.red,
                      ),
                    )
                  : const Icon(Icons.delete_forever),
              label: Text(
                _isDeletingAccount ? 'Deleting...' : 'Delete My Account',
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
