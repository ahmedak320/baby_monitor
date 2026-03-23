import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/datasources/remote/supabase_client.dart';
import '../data/repositories/profile_repository.dart';

/// Provides the currently authenticated Supabase user.
final currentAuthUserProvider = Provider<User?>((ref) {
  return SupabaseClientWrapper.currentUser;
});

/// Provides the auth repository.
final authRepositoryProvider = Provider<dynamic>((ref) {
  return SupabaseClientWrapper.auth;
});

/// Provides the parent profile for the current user.
final parentProfileProvider = FutureProvider<ParentProfile?>((ref) async {
  final repo = ProfileRepository();
  return repo.getParentProfile();
});

/// Provides the list of children for the current user.
final childrenProvider = FutureProvider<List<ChildProfile>>((ref) async {
  final repo = ProfileRepository();
  return repo.getChildren();
});
