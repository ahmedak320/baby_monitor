import 'package:flutter/material.dart';

import '../../../utils/biometric_helper.dart';
import '../../common/widgets/pin_dialog_helper.dart';

/// Widget that triggers biometric/PIN authentication for switching children.
/// Falls back to a PIN dialog (with forgot-PIN flow) if biometrics are
/// unavailable.
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
    final bioAvailable = await BiometricHelper.isAvailable;

    if (bioAvailable) {
      final success = await BiometricHelper.authenticateForChildSwitch();
      if (success) {
        onAuthenticated();
        return;
      }
    }

    // Fallback: shared PIN dialog with forgot-PIN support
    if (context.mounted) {
      final passed = await showPinAuthDialog(context);
      if (passed) onAuthenticated();
    }
  }
}
