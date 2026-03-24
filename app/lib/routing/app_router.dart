import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../presentation/common/widgets/responsive_layout.dart';
import '../presentation/auth/screens/login_screen.dart';
import '../presentation/auth/screens/signup_screen.dart';
import '../presentation/onboarding/screens/welcome_screen.dart';
import '../presentation/onboarding/screens/add_child_screen.dart';
import '../presentation/onboarding/screens/filter_setup_screen.dart';
import '../presentation/onboarding/screens/channel_suggestions_screen.dart';
import '../presentation/onboarding/screens/content_prefs_screen.dart';
import '../presentation/onboarding/screens/setup_complete_screen.dart';
import '../presentation/kid_mode/screens/kid_video_player_screen.dart';
import '../presentation/kid_mode/screens/kid_home_screen.dart';
import '../presentation/kid_mode/screens/child_select_screen.dart';
import '../presentation/kid_mode/screens/kid_search_screen.dart';
import '../presentation/parent_dashboard/screens/about_screen.dart';
import '../presentation/parent_dashboard/screens/feedback_screen.dart';
import '../presentation/parent_dashboard/screens/dashboard_screen.dart';
import '../presentation/parent_dashboard/screens/tablet_dashboard_screen.dart';
import '../presentation/parent_dashboard/screens/child_activity_screen.dart';
import '../presentation/parent_dashboard/screens/filtered_content_screen.dart';
import '../presentation/parent_dashboard/screens/channel_management_screen.dart';
import '../presentation/parent_dashboard/screens/filter_settings_screen.dart';
import '../presentation/parent_dashboard/screens/subscription_screen.dart';
import '../presentation/parent_dashboard/screens/screen_time_settings_screen.dart';
import '../presentation/parent_dashboard/screens/content_schedule_screen.dart';
import '../presentation/parent_dashboard/screens/offline_playlists_screen.dart';
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
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: '/onboarding/add-child',
        name: RouteNames.addChild,
        builder: (context, state) => const AddChildScreen(),
      ),
      GoRoute(
        path: '/onboarding/filter-setup',
        name: RouteNames.filterSetup,
        builder: (context, state) => const FilterSetupScreen(),
      ),
      GoRoute(
        path: '/onboarding/channels',
        name: RouteNames.channelSuggestions,
        builder: (context, state) => const ChannelSuggestionsScreen(),
      ),
      GoRoute(
        path: '/onboarding/content-prefs',
        name: 'contentPrefs',
        builder: (context, state) => const ContentPrefsScreen(),
      ),
      GoRoute(
        path: '/onboarding/complete',
        name: RouteNames.setupComplete,
        builder: (context, state) => const SetupCompleteScreen(),
      ),

      // --- Parent Dashboard routes ---
      GoRoute(
        path: '/dashboard',
        name: RouteNames.dashboard,
        builder: (context, state) => ResponsiveLayout(
          phone: const DashboardScreen(),
          tablet: const TabletDashboardScreen(),
        ),
        routes: [
          GoRoute(
            path: 'child-activity/:childId',
            name: RouteNames.childActivity,
            builder: (context, state) => ChildActivityScreen(
              childId: state.pathParameters['childId'] ?? '',
            ),
          ),
          GoRoute(
            path: 'filtered-content',
            name: RouteNames.filteredContent,
            builder: (context, state) => const FilteredContentScreen(),
          ),
          GoRoute(
            path: 'channels',
            name: RouteNames.channelManagement,
            builder: (context, state) => const ChannelManagementScreen(),
          ),
          GoRoute(
            path: 'filter-settings',
            name: RouteNames.filterSettings,
            builder: (context, state) => const FilterSettingsScreen(),
          ),
          GoRoute(
            path: 'screen-time',
            name: RouteNames.screenTimeSettings,
            builder: (context, state) => const ScreenTimeSettingsScreen(
              childId: '', // TODO: pass from parent
              childName: 'Child',
            ),
          ),
          GoRoute(
            path: 'content-schedule',
            name: RouteNames.contentSchedule,
            builder: (context, state) => const ContentScheduleScreen(
              childId: '', // TODO: pass from parent
              childName: 'Child',
            ),
          ),
          GoRoute(
            path: 'offline-playlists',
            name: RouteNames.offlinePlaylists,
            builder: (context, state) => const OfflinePlaylistsScreen(),
          ),
          GoRoute(
            path: 'subscription',
            name: RouteNames.subscription,
            builder: (context, state) => const SubscriptionScreen(),
          ),
          GoRoute(
            path: 'about',
            name: RouteNames.about,
            builder: (context, state) => const AboutScreen(),
          ),
          GoRoute(
            path: 'feedback',
            name: RouteNames.feedback,
            builder: (context, state) => const FeedbackScreen(),
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
        builder: (context, state) => const ChildSelectScreen(),
      ),
      GoRoute(
        path: '/kid/home',
        name: RouteNames.kidHome,
        builder: (context, state) => const KidHomeScreen(),
      ),
      GoRoute(
        path: '/kid/player/:videoId',
        name: RouteNames.kidPlayer,
        builder: (context, state) => KidVideoPlayerScreen(
          videoId: state.pathParameters['videoId'] ?? '',
          videoTitle: state.uri.queryParameters['title'],
        ),
      ),
      GoRoute(
        path: '/kid/categories',
        name: RouteNames.kidCategories,
        builder: (context, state) => const _PlaceholderScreen('Categories'),
      ),
      GoRoute(
        path: '/kid/search',
        name: RouteNames.kidSearch,
        builder: (context, state) => const KidSearchScreen(),
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
