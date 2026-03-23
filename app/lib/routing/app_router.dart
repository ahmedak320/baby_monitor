import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../presentation/auth/screens/login_screen.dart';
import '../presentation/auth/screens/signup_screen.dart';
import 'guards/auth_guard.dart';
import 'route_names.dart';

/// Provides the GoRouter instance.
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/login',
    redirect: authGuard,
    routes: [
      // --- Auth routes ---
      GoRoute(
        path: '/login',
        name: RouteNames.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        name: RouteNames.signup,
        builder: (context, state) => const SignupScreen(),
      ),

      // --- Onboarding routes ---
      GoRoute(
        path: '/onboarding/welcome',
        name: RouteNames.welcome,
        builder: (context, state) => const _PlaceholderScreen('Welcome'),
      ),
      GoRoute(
        path: '/onboarding/add-child',
        name: RouteNames.addChild,
        builder: (context, state) => const _PlaceholderScreen('Add Child'),
      ),
      GoRoute(
        path: '/onboarding/filter-setup',
        name: RouteNames.filterSetup,
        builder: (context, state) => const _PlaceholderScreen('Filter Setup'),
      ),
      GoRoute(
        path: '/onboarding/channels',
        name: RouteNames.channelSuggestions,
        builder: (context, state) =>
            const _PlaceholderScreen('Channel Suggestions'),
      ),
      GoRoute(
        path: '/onboarding/complete',
        name: RouteNames.setupComplete,
        builder: (context, state) =>
            const _PlaceholderScreen('Setup Complete'),
      ),

      // --- Parent Dashboard routes ---
      GoRoute(
        path: '/dashboard',
        name: RouteNames.dashboard,
        builder: (context, state) => const _PlaceholderScreen('Dashboard'),
        routes: [
          GoRoute(
            path: 'child-activity/:childId',
            name: RouteNames.childActivity,
            builder: (context, state) =>
                const _PlaceholderScreen('Child Activity'),
          ),
          GoRoute(
            path: 'filtered-content',
            name: RouteNames.filteredContent,
            builder: (context, state) =>
                const _PlaceholderScreen('Filtered Content'),
          ),
          GoRoute(
            path: 'channels',
            name: RouteNames.channelManagement,
            builder: (context, state) =>
                const _PlaceholderScreen('Channel Management'),
          ),
          GoRoute(
            path: 'filter-settings',
            name: RouteNames.filterSettings,
            builder: (context, state) =>
                const _PlaceholderScreen('Filter Settings'),
          ),
          GoRoute(
            path: 'screen-time',
            name: RouteNames.screenTimeSettings,
            builder: (context, state) =>
                const _PlaceholderScreen('Screen Time Settings'),
          ),
          GoRoute(
            path: 'content-schedule',
            name: RouteNames.contentSchedule,
            builder: (context, state) =>
                const _PlaceholderScreen('Content Schedule'),
          ),
          GoRoute(
            path: 'offline-playlists',
            name: RouteNames.offlinePlaylists,
            builder: (context, state) =>
                const _PlaceholderScreen('Offline Playlists'),
          ),
          GoRoute(
            path: 'subscription',
            name: RouteNames.subscription,
            builder: (context, state) =>
                const _PlaceholderScreen('Subscription'),
          ),
          GoRoute(
            path: 'edit-child/:childId',
            name: RouteNames.childProfileEdit,
            builder: (context, state) =>
                const _PlaceholderScreen('Edit Child Profile'),
          ),
        ],
      ),

      // --- Kid Mode routes ---
      GoRoute(
        path: '/kid/select',
        name: RouteNames.childSelect,
        builder: (context, state) => const _PlaceholderScreen('Select Child'),
      ),
      GoRoute(
        path: '/kid/home',
        name: RouteNames.kidHome,
        builder: (context, state) => const _PlaceholderScreen('Kid Home'),
      ),
      GoRoute(
        path: '/kid/player/:videoId',
        name: RouteNames.kidPlayer,
        builder: (context, state) => const _PlaceholderScreen('Video Player'),
      ),
      GoRoute(
        path: '/kid/categories',
        name: RouteNames.kidCategories,
        builder: (context, state) => const _PlaceholderScreen('Categories'),
      ),
      GoRoute(
        path: '/kid/search',
        name: RouteNames.kidSearch,
        builder: (context, state) => const _PlaceholderScreen('Kid Search'),
      ),
    ],
  );
});

/// Temporary placeholder screen for routes not yet implemented.
class _PlaceholderScreen extends StatelessWidget {
  final String title;
  const _PlaceholderScreen(this.title);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Text(
          '$title\nComing Soon',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
      ),
    );
  }
}
