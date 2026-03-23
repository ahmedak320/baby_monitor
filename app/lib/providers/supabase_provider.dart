import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/datasources/remote/supabase_client.dart';

/// Provides the Supabase client instance.
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return SupabaseClientWrapper.client;
});

/// Stream of auth state changes.
final authStateProvider = StreamProvider<AuthState>((ref) {
  return SupabaseClientWrapper.authStateChanges;
});
