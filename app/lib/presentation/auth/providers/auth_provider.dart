import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/auth_repository.dart';

/// Provides the auth repository.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

/// State for auth operations (loading, error).
class AuthState {
  final bool isLoading;
  final String? error;

  const AuthState({this.isLoading = false, this.error});
  const AuthState.initial() : isLoading = false, error = null;
  const AuthState.loading() : isLoading = true, error = null;
  const AuthState.error(String message) : isLoading = false, error = message;
}

/// Notifier for auth operations.
class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repo;

  AuthNotifier(this._repo) : super(const AuthState.initial());

  Future<bool> signIn({required String email, required String password}) async {
    state = const AuthState.loading();
    final result = await _repo.signIn(email: email, password: password);
    if (result.success) {
      state = const AuthState.initial();
      return true;
    } else {
      state = AuthState.error(result.error ?? 'Sign in failed');
      return false;
    }
  }

  Future<bool> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    state = const AuthState.loading();
    final result = await _repo.signUp(
      email: email,
      password: password,
      displayName: displayName,
    );
    if (result.success) {
      state = const AuthState.initial();
      return true;
    } else {
      state = AuthState.error(result.error ?? 'Sign up failed');
      return false;
    }
  }

  Future<void> signOut() async {
    await _repo.signOut();
    state = const AuthState.initial();
  }

  Future<bool> resetPassword(String email) async {
    state = const AuthState.loading();
    final result = await _repo.resetPassword(email);
    if (result.success) {
      state = const AuthState.initial();
      return true;
    } else {
      state = AuthState.error(result.error ?? 'Password reset failed');
      return false;
    }
  }

  void clearError() {
    state = const AuthState.initial();
  }
}

/// Provides the auth state notifier.
final authNotifierProvider = StateNotifierProvider<AuthNotifier, AuthState>((
  ref,
) {
  final repo = ref.watch(authRepositoryProvider);
  return AuthNotifier(repo);
});
