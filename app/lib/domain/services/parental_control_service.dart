import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import '../../data/datasources/local/preferences_cache.dart';
import '../../data/datasources/remote/supabase_client.dart';
import '../../utils/biometric_helper.dart';

/// Service for PIN management and parental control authentication.
class ParentalControlService {
  /// Hash a PIN for secure storage.
  static String hashPin(String pin) {
    final bytes = utf8.encode(pin);
    return sha256.convert(bytes).toString();
  }

  /// Set the parent's PIN.
  static Future<void> setPin(String pin) async {
    final hash = hashPin(pin);
    final userId = SupabaseClientWrapper.currentUserId;
    if (userId == null) return;

    await SupabaseClientWrapper.client
        .from('parent_profiles')
        .update({'pin_hash': hash}).eq('id', userId);
  }

  /// Verify a PIN against the stored hash.
  static Future<bool> verifyPin(String pin) async {
    final userId = SupabaseClientWrapper.currentUserId;
    if (userId == null) return false;

    final row = await SupabaseClientWrapper.client
        .from('parent_profiles')
        .select('pin_hash')
        .eq('id', userId)
        .maybeSingle();

    if (row == null || row['pin_hash'] == null) return false;
    return row['pin_hash'] == hashPin(pin);
  }

  /// Authenticate parent: try biometric first, fall back to PIN.
  static Future<bool> authenticateParent() async {
    // Try biometric
    if (await BiometricHelper.isAvailable) {
      final success = await BiometricHelper.authenticate(
        reason: 'Verify your identity',
      );
      if (success) return true;
    }

    // Biometric failed or unavailable — caller should show PIN dialog
    return false;
  }

  /// Generate a math problem for the parental gate.
  static ({String question, int answer}) generateMathProblem() {
    final rng = Random();
    final a = 10 + rng.nextInt(30);
    final b = 10 + rng.nextInt(30);
    return (question: '$a + $b', answer: a + b);
  }

  /// Check if kid mode is currently active.
  static bool get isKidModeActive => PreferencesCache.isKidModeActive;

  /// Enter kid mode.
  static Future<void> enterKidMode() async {
    await PreferencesCache.setKidModeActive(true);
  }

  /// Exit kid mode.
  static Future<void> exitKidMode() async {
    await PreferencesCache.setKidModeActive(false);
  }
}
