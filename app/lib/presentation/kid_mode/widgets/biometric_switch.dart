import 'package:flutter/material.dart';

import '../../../utils/biometric_helper.dart';

/// Widget that triggers biometric/PIN authentication for switching children.
/// Falls back to a simple PIN dialog if biometrics are unavailable.
class BiometricSwitch extends StatelessWidget {
  final VoidCallback onAuthenticated;
  final Widget child;

  const BiometricSwitch({
    super.key,
    required this.onAuthenticated,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _authenticate(context),
      child: child,
    );
  }

  Future<void> _authenticate(BuildContext context) async {
    final bioAvailable = await BiometricHelper.isAvailable;

    if (bioAvailable) {
      final success = await BiometricHelper.authenticateForChildSwitch();
      if (success) {
        onAuthenticated();
      }
    } else {
      // Fallback: show a simple PIN dialog
      if (context.mounted) {
        final passed = await _showPinDialog(context);
        if (passed) {
          onAuthenticated();
        }
      }
    }
  }

  Future<bool> _showPinDialog(BuildContext context) async {
    final controller = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter Parent PIN'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          obscureText: true,
          maxLength: 4,
          decoration: const InputDecoration(
            hintText: '4-digit PIN',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // TODO: Verify against stored PIN hash
              Navigator.pop(context, controller.text.length == 4);
            },
            child: const Text('Verify'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result ?? false;
  }
}
