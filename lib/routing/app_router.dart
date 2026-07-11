import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ledger_lite/blocs/auth/auth_bloc.dart';
import 'package:ledger_lite/features/dashboard/dashboard_screen.dart';
import 'package:ledger_lite/features/transactions/transactions_screen.dart';
import 'package:ledger_lite/features/analytics/analytics_screen.dart';
import 'package:ledger_lite/features/settings/settings_screen.dart';
import 'package:ledger_lite/features/lock/lock_screen.dart';
import 'package:ledger_lite/widgets/adaptive_scaffold.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final GlobalKey<NavigatorState> _shellNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'shell');

class AppRouter {
  static GoRouter router(AuthBloc authBloc) {
    return GoRouter(
      navigatorKey: _rootNavigatorKey,
      initialLocation: '/dashboard',
      redirect: (context, state) {
        final authState = authBloc.state;
        // Use the bloc's in-memory cache instead of awaiting a fresh
        // SharedPreferences read on every single navigation.
        final isEnabled = authBloc.isLockEnabledSync;

        final loggingIn = state.matchedLocation == '/lock';
        
        if (isEnabled && authState is AuthLocked && !loggingIn) {
          return '/lock';
        }
        if ((!isEnabled || authState is AuthUnlocked) && loggingIn) {
          return '/dashboard';
        }
        return null;
      },
      routes: [
        GoRoute(
          path: '/lock',
          parentNavigatorKey: _rootNavigatorKey,
          builder: (context, state) => const LockScreen(),
        ),
        ShellRoute(
          navigatorKey: _shellNavigatorKey,
          builder: (context, state, child) {
            return AdaptiveScaffold(child: child);
          },
          routes: [
            GoRoute(
              path: '/dashboard',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: DashboardScreen(),
              ),
            ),
            GoRoute(
              path: '/transactions',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: TransactionsScreen(),
              ),
            ),
            GoRoute(
              path: '/analytics',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: AnalyticsScreen(),
              ),
            ),
            GoRoute(
              path: '/settings',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: SettingsScreen(),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
