import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import '../../features/admin/presentation/pages/admin_home_page.dart';
import '../../features/admin/presentation/pages/admin_issue_details_page.dart';
import '../../features/admin/presentation/pages/mark_resolved_page.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/auth/presentation/pages/forgot_password_page.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/no_access_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/auth/presentation/pages/reset_password_page.dart';
import '../../features/auth/presentation/pages/splash_page.dart';
import '../../features/feedback/presentation/pages/resolution_feedback_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/reports/presentation/pages/issue_details_page.dart';
import '../../features/reports/presentation/pages/report_issue_page.dart';
import '../../features/student_dashboard/presentation/pages/student_home_page.dart';
import 'routes.dart';

/// Builds the router. Guards are for usability only; authorization is
/// enforced by the API server.
GoRouter createRouter(AuthBloc authBloc) {
  return GoRouter(
    initialLocation: Routes.splash,
    refreshListenable: _BlocRefresh(authBloc.stream),
    redirect: (context, state) =>
        redirectFor(authState: authBloc.state, location: state.matchedLocation),
    routes: [
      GoRoute(path: Routes.splash, builder: (_, _) => const SplashPage()),
      GoRoute(path: Routes.login, builder: (_, _) => const LoginPage()),
      GoRoute(path: Routes.register, builder: (_, _) => const RegisterPage()),
      GoRoute(
        path: Routes.forgotPassword,
        builder: (_, _) => const ForgotPasswordPage(),
      ),
      GoRoute(
        path: Routes.resetPassword,
        builder: (_, _) => const ResetPasswordPage(),
      ),
      GoRoute(path: Routes.home, builder: (_, _) => const StudentHomePage()),
      GoRoute(path: Routes.report, builder: (_, _) => const ReportIssuePage()),
      GoRoute(path: Routes.noAccess, builder: (_, _) => const NoAccessPage()),
      GoRoute(path: Routes.profile, builder: (_, _) => const ProfilePage()),
      GoRoute(
        path: Routes.issuePattern,
        builder: (_, state) =>
            IssueDetailsPage(issueId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: Routes.issueFeedbackPattern,
        builder: (_, state) =>
            ResolutionFeedbackPage(issueId: state.pathParameters['id']!),
      ),
      GoRoute(path: Routes.admin, builder: (_, _) => const AdminHomePage()),
      GoRoute(
        path: Routes.adminIssuePattern,
        builder: (_, state) =>
            AdminIssueDetailsPage(issueId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: Routes.adminResolvePattern,
        builder: (_, state) =>
            MarkResolvedPage(issueId: state.pathParameters['id']!),
      ),
    ],
  );
}

/// Pure redirect logic, exposed for testing.
@visibleForTesting
String? redirectFor({required AuthState authState, required String location}) {
  final isPublic = Routes.publicRoutes.contains(location);

  switch (authState.session) {
    case SessionStatus.unknown:
      return location == Routes.splash ? null : Routes.splash;
    case SessionStatus.unauthenticated:
      return isPublic ? null : Routes.login;
    case SessionStatus.authenticated:
      final landing = authState.isAdmin ? Routes.admin : Routes.home;
      if (isPublic || location == Routes.splash) return landing;
      // Fail closed: non-admins never see admin routes; they get the
      // "Facilities staff only" screen instead.
      if (location.startsWith(Routes.admin) && !authState.isAdmin) {
        return Routes.noAccess;
      }
      return null;
  }
}

class _BlocRefresh extends ChangeNotifier {
  _BlocRefresh(Stream<AuthState> stream) {
    _subscription = stream
        .map((s) => (s.session, s.user?.role))
        .distinct()
        .listen((_) => notifyListeners());
  }

  late final StreamSubscription<Object?> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
