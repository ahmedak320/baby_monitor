import 'package:supabase_flutter/supabase_flutter.dart';

/// Central Supabase client accessor.
class SupabaseClientWrapper {
  SupabaseClientWrapper._();

  static SupabaseClient get client => Supabase.instance.client;
  static GoTrueClient get auth => client.auth;

  /// Current authenticated user, or null.
  static User? get currentUser => auth.currentUser;

  /// Current user ID, or null.
  static String? get currentUserId => currentUser?.id;

  /// Whether user is authenticated.
  static bool get isAuthenticated => currentUser != null;

  /// Listen to auth state changes.
  static Stream<AuthState> get authStateChanges => auth.onAuthStateChange;
}
