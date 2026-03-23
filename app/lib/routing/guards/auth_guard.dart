import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/datasources/remote/supabase_client.dart';

/// Redirects unauthenticated users to the login screen.
String? authGuard(BuildContext context, GoRouterState state) {
  final isAuthenticated = SupabaseClientWrapper.isAuthenticated;
  final isAuthRoute =
      state.matchedLocation == '/login' || state.matchedLocation == '/signup';

  if (!isAuthenticated && !isAuthRoute) {
    return '/login';
  }

  if (isAuthenticated && isAuthRoute) {
    return '/dashboard';
  }

  return null;
}
