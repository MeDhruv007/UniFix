abstract final class Routes {
  static const String splash = '/splash';
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String resetPassword = '/reset-password';

  /// Student shell: Home · Feed · (+) · Mine · Profile tabs.
  static const String home = '/home';
  static const String report = '/report';
  static const String issuePattern = '/issues/:id';
  static const String issueFeedbackPattern = '/issues/:id/feedback';
  static const String profile = '/profile';

  /// Shown when a student opens an admin route (design screen 16).
  static const String noAccess = '/no-access';

  /// Admin shell: Overview · Queue · All issues · Profile tabs.
  static const String admin = '/admin';
  static const String adminIssuePattern = '/admin/issues/:id';
  static const String adminResolvePattern = '/admin/issues/:id/resolve';

  static String issueDetails(String id) => '/issues/$id';
  static String issueFeedback(String id) => '/issues/$id/feedback';
  static String adminIssueDetails(String id) => '/admin/issues/$id';
  static String adminResolve(String id) => '/admin/issues/$id/resolve';

  static const Set<String> publicRoutes = {
    login,
    register,
    forgotPassword,
    resetPassword,
  };
}
