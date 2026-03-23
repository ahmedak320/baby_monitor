import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Prevents navigation outside kid mode screens when kid mode is active.
/// The parental gate must be passed to exit.
String? childModeGuard(
  BuildContext context,
  GoRouterState state,
  bool isInKidMode,
) {
  final isKidRoute = state.matchedLocation.startsWith('/kid');

  if (isInKidMode && !isKidRoute) {
    return '/kid/home';
  }

  return null;
}
