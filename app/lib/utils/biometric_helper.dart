import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// Abstraction over biometric/PIN authentication for adult verification.
class BiometricHelper {
  static final _auth = LocalAuthentication();

  /// Check if biometric authentication is available.
  static Future<bool> get isAvailable async {
    if (kIsWeb) return false;
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isDeviceSupported = await _auth.isDeviceSupported();
      return canCheck || isDeviceSupported;
    } on PlatformException {
      return false;
    }
  }

  /// Get available biometric types.
  static Future<List<BiometricType>> get availableBiometrics async {
    if (kIsWeb) return [];
    try {
      return await _auth.getAvailableBiometrics();
    } on PlatformException {
      return [];
    }
  }

  /// Authenticate the user with biometrics or device PIN.
  /// Returns true if authentication succeeded.
  /// On web, always returns true (biometrics not available).
  static Future<bool> authenticate({
    String reason = 'Verify your identity to continue',
  }) async {
    if (kIsWeb) return true;
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false, // Allow PIN/pattern as fallback
        ),
      );
    } on PlatformException {
      return false;
    }
  }

  /// Authenticate specifically for switching child profiles.
  static Future<bool> authenticateForChildSwitch() {
    return authenticate(
      reason: 'Verify to switch child profile',
    );
  }

  /// Authenticate for exiting kid mode.
  static Future<bool> authenticateForExitKidMode() {
    return authenticate(
      reason: 'Verify to exit kid mode',
    );
  }
}
