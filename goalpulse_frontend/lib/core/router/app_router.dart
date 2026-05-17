import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';
import '../../features/auth/auth_provider.dart';
import '../../features/auth/login_page.dart';
import '../../features/auth/forgot_password_page.dart';
import '../../features/dashboard/employee_dashboard_page.dart';
import '../../features/dashboard/manager_dashboard_page.dart';
import '../../features/dashboard/admin_dashboard_page.dart';
import '../../features/shared/placeholder_page.dart';
import '../../features/employee/goals/goal_builder_page.dart';
import '../../features/employee/goals/goal_sheet_view_page.dart';
import '../../features/manager/approvals/pending_approvals_page.dart';
import '../../features/manager/approvals/goal_review_page.dart';
import '../../features/employee/checkins/quarterly_checkin_page.dart';
import '../../features/employee/checkins/progress_history_page.dart';
import '../../features/manager/checkins/team_checkins_page.dart';
import '../../features/manager/checkins/checkin_detail_page.dart';
import '../../features/manager/shared_goals/shared_goals_page.dart';

// ── Router provider ───────────────────────────────────────────────────────

final appRouterProvider = Provider<GoRouter>((ref) {
  final authNotifier = _AuthRouterNotifier(ref);

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: authNotifier,
    redirect: (context, state) => authNotifier.redirect(state),
    routes: [
      // ── Public routes ──────────────────────────────────────────────────
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (_, __) => const LoginPage(),
      ),
      GoRoute(
        path: '/forgot-password',
        name: 'forgot-password',
        builder: (_, __) => const ForgotPasswordPage(),
      ),

      // ── Employee routes ────────────────────────────────────────────────
      GoRoute(path: '/employee', redirect: (_, __) => '/employee/dashboard'),
      GoRoute(
        path: '/employee/dashboard',
        name: 'employee-dashboard',
        builder: (_, __) => const EmployeeDashboardPage(),
      ),
      GoRoute(
        path: '/employee/goals',
        name: 'employee-goals',
        builder: (_, __) => const GoalBuilderPage(),
      ),
      GoRoute(
        path: '/employee/goals/create',
        name: 'employee-goals-create',
        builder: (_, __) => const GoalBuilderPage(),
      ),
      GoRoute(
        path: '/employee/goals/view',
        name: 'employee-goals-view',
        builder: (_, __) => const GoalSheetViewPage(),
      ),
      GoRoute(
        path: '/employee/checkins',
        name: 'employee-checkins',
        builder: (_, __) => const QuarterlyCheckinPage(),
      ),
      GoRoute(
        path: '/employee/progress',
        name: 'employee-progress',
        builder: (_, __) => const ProgressHistoryPage(),
      ),

      // ── Manager routes ─────────────────────────────────────────────────
      GoRoute(path: '/manager', redirect: (_, __) => '/manager/dashboard'),
      GoRoute(
        path: '/manager/dashboard',
        name: 'manager-dashboard',
        builder: (_, __) => const ManagerDashboardPage(),
      ),
      GoRoute(
        path: '/manager/approvals',
        name: 'manager-approvals',
        builder: (_, __) => const PendingApprovalsPage(),
      ),
      GoRoute(
        path: '/manager/approvals/:goalId',
        name: 'manager-approval-detail',
        builder: (_, state) => GoalReviewPage(
            goalId: state.pathParameters['goalId']!),
      ),
      GoRoute(
        path: '/manager/checkins',
        name: 'manager-checkins',
        builder: (_, __) => const TeamCheckinsPage(),
      ),
      GoRoute(
        path: '/manager/checkins/:checkinId',
        name: 'manager-checkin-detail',
        builder: (_, state) => CheckinDetailPage(
            checkinId: state.pathParameters['checkinId']!),
      ),
      GoRoute(
        path: '/manager/shared-goals',
        name: 'manager-shared-goals',
        builder: (_, __) => const SharedGoalsPage(),
      ),
      GoRoute(
        path: '/manager/analytics',
        name: 'manager-analytics',
        builder: (_, __) => const PlaceholderPage(
            title: 'Analytics', role: UserRole.manager),
      ),

      // ── Admin routes ───────────────────────────────────────────────────
      GoRoute(path: '/admin', redirect: (_, __) => '/admin/dashboard'),
      GoRoute(
        path: '/admin/dashboard',
        name: 'admin-dashboard',
        builder: (_, __) => const AdminDashboardPage(),
      ),
      GoRoute(
        path: '/admin/users',
        name: 'admin-users',
        builder: (_, __) => const PlaceholderPage(
            title: 'Users', role: UserRole.admin),
      ),
      GoRoute(
        path: '/admin/cycles',
        name: 'admin-cycles',
        builder: (_, __) => const PlaceholderPage(
            title: 'Cycles', role: UserRole.admin),
      ),
      GoRoute(
        path: '/admin/shared-goals',
        name: 'admin-shared-goals',
        builder: (_, __) => const PlaceholderPage(
            title: 'Shared Goals', role: UserRole.admin),
      ),
      GoRoute(
        path: '/admin/escalations',
        name: 'admin-escalations',
        builder: (_, __) => const PlaceholderPage(
            title: 'Escalations', role: UserRole.admin),
      ),
      GoRoute(
        path: '/admin/audit-log',
        name: 'admin-audit-log',
        builder: (_, __) => const PlaceholderPage(
            title: 'Audit Log', role: UserRole.admin),
      ),
      GoRoute(
        path: '/admin/analytics',
        name: 'admin-analytics',
        builder: (_, __) => const PlaceholderPage(
            title: 'Analytics', role: UserRole.admin),
      ),
      GoRoute(
        path: '/admin/reports',
        name: 'admin-reports',
        builder: (_, __) => const PlaceholderPage(
            title: 'Reports', role: UserRole.admin),
      ),
      GoRoute(
        path: '/admin/goal-unlock',
        name: 'admin-goal-unlock',
        builder: (_, __) => const PlaceholderPage(
            title: 'Goal Unlock', role: UserRole.admin),
      ),
    ],
  );
});

// ── Redirect logic ─────────────────────────────────────────────────────────

class _AuthRouterNotifier extends ChangeNotifier {
  _AuthRouterNotifier(this._ref) {
    _ref.listen<AsyncValue<User?>>(authStateProvider, (_, __) {
      notifyListeners();
    });
    _ref.listen<AsyncValue<String?>>(userRoleProvider, (_, __) {
      notifyListeners();
    });
  }

  final Ref _ref;

  String? redirect(GoRouterState state) {
    final authAsync = _ref.read(authStateProvider);
    final roleAsync = _ref.read(userRoleProvider);

    if (authAsync.isLoading) return null;

    final user = authAsync.valueOrNull;
    final isLoggedIn = user != null;
    final isOnLogin = state.matchedLocation == '/login' ||
        state.matchedLocation == '/forgot-password';

    if (!isLoggedIn) {
      return isOnLogin ? null : '/login';
    }

    if (roleAsync.isLoading) return null;
    final role = roleAsync.valueOrNull;

    if (isOnLogin) {
      return _dashboardFor(role);
    }

    final loc = state.matchedLocation;
    if (role == 'employee' && !loc.startsWith('/employee')) {
      return '/employee/dashboard';
    }
    if (role == 'manager' && !loc.startsWith('/manager')) {
      return '/manager/dashboard';
    }
    if (role == 'admin' && !loc.startsWith('/admin')) {
      return '/admin/dashboard';
    }

    return null;
  }

  String _dashboardFor(String? role) => switch (role) {
        'manager' => '/manager/dashboard',
        'admin' => '/admin/dashboard',
        _ => '/employee/dashboard',
      };
}
