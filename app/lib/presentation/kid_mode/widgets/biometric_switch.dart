import 'package:flutter/material.dart';

import '../../../data/datasources/local/preferences_cache.dart';
import '../../../utils/biometric_helper.dart';
import 'pin_reset_dialog.dart';

/// Widget that triggers biometric/PIN authentication for switching children.
/// Falls back to a simple PIN dialog if biometrics are unavailable.
/// Includes brute-force protection with exponential lockout via shared
/// [PreferencesCache] state.
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
    return GestureDetector(onTap: () => _authenticate(context), child: child);
  }

  Future<void> _authenticate(BuildContext context) async {
    // Check shared lockout before proceeding
    if (PreferencesCache.isPinLockedOut) {
      final remaining = PreferencesCache.pinLockoutRemainingSeconds;
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Too many failed attempts. Try again in $remaining seconds.',
            ),
          ),
        );
      }
      return;
    }

    final bioAvailable = await BiometricHelper.isAvailable;

    if (bioAvailable) {
      final success = await BiometricHelper.authenticateForChildSwitch();
      if (success) {
        await PreferencesCache.resetPinLockout();
        onAuthenticated();
        return;
      }
    }

    // Biometric failed or unavailable — fall back to PIN dialog
    if (context.mounted) {
      final passed = await showPinVerificationDialog(context);
      if (passed) {
        await PreferencesCache.resetPinLockout();
        onAuthenticated();
      }
    }
  }
}
