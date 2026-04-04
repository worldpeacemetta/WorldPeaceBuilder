import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'providers/auth_provider.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/daily_log/log_history_screen.dart';
import 'screens/daily_log/day_detail_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/food_db/food_db_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/profile/badges_screen.dart';
import 'screens/profile/general_screen.dart';
import 'screens/profile/daily_goals_screen.dart';
import 'screens/profile/body_stats_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authNotifier = ref.watch(authStateProvider.notifier);

  return GoRouter(
    initialLocation: '/dashboard',
    refreshListenable: authNotifier,
    redirect: (context, state) {
      final session = Supabase.instance.client.auth.currentSession;
      final isLoggedIn = session != null;
      final isAuthRoute = state.matchedLocation == '/auth';
      final isOnboarding = state.matchedLocation == '/onboarding';

      if (!isLoggedIn && !isAuthRoute) return '/auth';
      if (isLoggedIn && isAuthRoute) {
        final meta = Supabase.instance.client.auth.currentUser?.userMetadata;
        return _onboardingDone(meta) ? '/log' : '/onboarding';
      }
      if (isLoggedIn && !isOnboarding) {
        final meta = Supabase.instance.client.auth.currentUser?.userMetadata;
        if (!_onboardingDone(meta)) return '/onboarding';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/auth',
        builder: (context, state) => const AuthScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      // Full-screen badges list — above shell so it has no nav bar
      GoRoute(
        path: '/badges',
        builder: (context, state) => const BadgesScreen(),
      ),
      // Profile sub-screens — above shell so they have no nav bar
      GoRoute(
        path: '/profile/general',
        builder: (context, state) => const GeneralScreen(),
      ),
      GoRoute(
        path: '/profile/goals',
        builder: (context, state) => const DailyGoalsScreen(),
      ),
      GoRoute(
        path: '/profile/stats',
        builder: (context, state) => const BodyStatsScreen(),
      ),
      // Full-screen day detail — must be above StatefulShellRoute so it has no nav bar
      GoRoute(
        path: '/log/:date',
        builder: (context, state) {
          final date = state.pathParameters['date']!;
          return DayDetailScreen(date: date);
        },
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => HomeScreen(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/log',
              builder: (context, state) => const LogHistoryScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/dashboard',
              builder: (context, state) => const DashboardScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/foods',
              builder: (context, state) => const FoodDbScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/profile',
              builder: (context, state) => const ProfileScreen(),
            ),
          ]),
        ],
      ),
    ],
  );
});

// Existing users have display_username but no onboarding_done flag —
// treat either signal as onboarding complete.
bool _onboardingDone(Map<String, dynamic>? meta) {
  if (meta == null) return false;
  if (meta['onboarding_done'] == true) return true;
  final name = meta['display_username'] as String?;
  return name != null && name.isNotEmpty;
}
