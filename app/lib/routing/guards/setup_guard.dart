import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Redirects users who haven't completed setup to onboarding.
/// This guard is applied inside the app after profile data is loaded.
String? setupGuard(BuildContext context, GoRouterState state, bool setupCompleted) {
  final isOnboardingRoute = state.matchedLocation.startsWith('/onboarding');

  if (!setupCompleted && !isOnboardingRoute) {
    return '/onboarding/welcome';
  }

  if (setupCompleted && isOnboardingRoute) {
    return '/dashboard';
  }

  return null;
}
