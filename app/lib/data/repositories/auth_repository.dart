import 'package:supabase_flutter/supabase_flutter.dart';

import '../datasources/local/local_cache.dart';
import '../datasources/remote/supabase_client.dart';

/// Result type for auth operations.
class AuthResult {
  final bool success;
  final String? error;

  const AuthResult({required this.success, this.error});
  const AuthResult.success() : success = true, error = null;
  const AuthResult.failure(String message)
      : success = false,
        error = message;
}

/// Repository handling authentication with Supabase.
class AuthRepository {
  final _auth = SupabaseClientWrapper.auth;

  /// Sign up with email and password.
  Future<AuthResult> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      await _auth.signUp(
        email: email,
        password: password,
        data: displayName != null ? {'display_name': displayName} : null,
      );
      return const AuthResult.success();
    } on AuthException catch (e) {
      return AuthResult.failure(e.message);
    } catch (e) {
      return AuthResult.failure('An unexpected error occurred');
    }
  }

  /// Sign in with email and password.
  Future<AuthResult> signIn({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithPassword(email: email, password: password);
      return const AuthResult.success();
    } on AuthException catch (e) {
      return AuthResult.failure(e.message);
    } catch (e) {
      return AuthResult.failure('An unexpected error occurred');
    }
  }

  /// Sign in with Google OAuth.
  Future<AuthResult> signInWithGoogle() async {
    try {
      await _auth.signInWithOAuth(OAuthProvider.google);
      return const AuthResult.success();
    } on AuthException catch (e) {
      return AuthResult.failure(e.message);
    } catch (e) {
      return AuthResult.failure('An unexpected error occurred');
    }
  }

  /// Sign out.
  Future<void> signOut() async {
    await LocalCache.clearAll();
    await _auth.signOut();
  }

  /// Send password reset email.
  Future<AuthResult> resetPassword(String email) async {
    try {
      await _auth.resetPasswordForEmail(email);
      return const AuthResult.success();
    } on AuthException catch (e) {
      return AuthResult.failure(e.message);
    } catch (e) {
      return AuthResult.failure('An unexpected error occurred');
    }
  }

  /// Get current session.
  Session? get currentSession => _auth.currentSession;

  /// Get current user.
  User? get currentUser => _auth.currentUser;

  /// Stream of auth state changes.
  Stream<AuthState> get authStateChanges => _auth.onAuthStateChange;
}
