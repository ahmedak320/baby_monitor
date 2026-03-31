import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../../data/datasources/local/preferences_cache.dart';
import '../../data/datasources/remote/supabase_client.dart';
import '../../utils/biometric_helper.dart';
import '../../utils/pbkdf2.dart';

/// Service for PIN management and parental control authentication.
class ParentalControlService {
  /// Hash a PIN using PBKDF2-HMAC-SHA256 with the given salt.
  static String hashPin(String pin, Uint8List salt) {
    final derived = Pbkdf2.derive(pin, salt, iterations: 100000, keyLength: 32);
    return Pbkdf2.toHex(derived);
  }

  /// Legacy hash for migration — plain SHA-256 (no salt).
  static String _legacyHashPin(String pin) {
    final bytes = utf8.encode(pin);
    return sha256.convert(bytes).toString();
  }

  /// Set the parent's PIN with a random 16-byte salt.
  static Future<void> setPin(String pin) async {
    final userId = SupabaseClientWrapper.currentUserId;
    if (userId == null) return;

    final salt = Uint8List(16);
    final rng = Random.secure();
    for (var i = 0; i < 16; i++) {
      salt[i] = rng.nextInt(256);
    }

    final hash = hashPin(pin, salt);
    final saltHex = Pbkdf2.toHex(salt);

    await SupabaseClientWrapper.client
        .from('parent_profiles')
        .update({'pin_hash': hash, 'pin_salt': saltHex})
        .eq('id', userId);
  }

  /// Verify a PIN against the stored hash.
  ///
  /// Supports legacy (unsalted SHA-256) and new (PBKDF2) formats.
  /// Legacy hashes are automatically upgraded to PBKDF2 on successful verify.
  static Future<bool> verifyPin(String pin) async {
    final userId = SupabaseClientWrapper.currentUserId;
    if (userId == null) return false;

    final row = await SupabaseClientWrapper.client
        .from('parent_profiles')
        .select('pin_hash, pin_salt')
        .eq('id', userId)
        .maybeSingle();

    if (row == null || row['pin_hash'] == null) return false;

    final storedHash = row['pin_hash'] as String;
    final storedSalt = row['pin_salt'] as String?;

    if (storedSalt == null || storedSalt.isEmpty) {
      // Legacy: plain SHA-256 — verify and auto-upgrade
      final legacyHash = _legacyHashPin(pin);
      if (storedHash == legacyHash) {
        // Auto-upgrade to PBKDF2
        await setPin(pin);
        return true;
      }
      return false;
    }

    // New: PBKDF2 verification
    final salt = Pbkdf2.fromHex(storedSalt);
    final computedHash = hashPin(pin, salt);
    return storedHash == computedHash;
  }

  /// Check if the current user has a PIN set.
  static Future<bool> hasPinSet() async {
    final userId = SupabaseClientWrapper.currentUserId;
    if (userId == null) return false;

    final row = await SupabaseClientWrapper.client
        .from('parent_profiles')
        .select('pin_hash')
        .eq('id', userId)
        .maybeSingle();

    return row != null && row['pin_hash'] != null;
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
