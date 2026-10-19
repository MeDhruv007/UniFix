import 'package:bloc_test/bloc_test.dart';
import 'package:fixmycampus/core/routing/routes.dart';
import 'package:fixmycampus/core/theme/app_theme.dart';
import 'package:fixmycampus/core/utils/photo_picker.dart';
import 'package:fixmycampus/features/auth/domain/entities/app_user.dart';
import 'package:fixmycampus/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:fixmycampus/features/reports/domain/entities/issue.dart';
import 'package:fixmycampus/features/reports/domain/entities/issue_enums.dart';
import 'package:fixmycampus/features/reports/domain/repositories/issue_repository.dart';
import 'package:fixmycampus/features/reports/presentation/bloc/issue_details_cubit.dart';
import 'package:fixmycampus/features/reports/presentation/bloc/issue_form_cubit.dart';
import 'package:fixmycampus/features/reports/presentation/bloc/issue_list_bloc.dart';
import 'package:fixmycampus/features/reports/presentation/pages/report_issue_page.dart';
import 'package:fixmycampus/features/student_dashboard/presentation/bloc/student_stats_cubit.dart';
import 'package:fixmycampus/features/student_dashboard/presentation/pages/student_home_page.dart';
import 'package:fixmycampus/injection_container.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

/// Shared setup for the student-area widget tests: mocked repository and
/// photo picker, real blocs registered in [getIt], a 360×780 phone.

class MockIssueRepository extends Mock implements IssueRepository {}

class MockPhotoPicker extends Mock implements PhotoPicker {}

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

const student = AppUser(
  uid: 'u1',
  displayName: 'Aarav Shah',
  email: 'aarav@adit.ac.in',
  role: UserRole.student,
  campusId: 'adit-main',
  isActive: true,
);

Issue issue({
  String id = 'i1',
  String title = 'Ceiling fan not working',
  IssueCategory category = IssueCategory.electrical,
  IssueStatus status = IssueStatus.inProgress,
  IssuePriority priority = IssuePriority.medium,
  String reporterId = 'u1',
  String? assignedToName = 'R. Mehta',
  int number = 482,
}) => Issue(
  id: id,
  campusId: 'adit-main',
  title: title,
  description: 'Fan does not start at all.',
  category: category,
  buildingId: 'engineering-block',
  locationDetail: 'Room 204',
  reporterId: reporterId,
  status: status,
  priority: priority,
  assignedToName: assignedToName,
  number: number,
  createdAt: DateTime.now().subtract(const Duration(hours: 2)),
);

class StudentHarness {
  StudentHarness() {
    repo = MockIssueRepository();
    picker = MockPhotoPicker();
    auth = MockAuthBloc();
    whenListen(
      auth,
      const Stream<AuthState>.empty(),
      initialState: const AuthState(
        session: SessionStatus.authenticated,
        user: student,
      ),
    );
    when(() => repo.watchStats(mine: any(named: 'mine')))
        .thenAnswer((_) => Stream.value(const IssueStats()));
    when(() => repo.watchIssue(any())).thenAnswer((_) => Stream.value(issue()));
    when(() => repo.watchUpdates(any()))
        .thenAnswer((_) => const Stream.empty());

    getIt
      ..reset()
      ..registerFactory<IssueListBloc>(() => IssueListBloc(repository: repo))
      ..registerFactory<IssueFormCubit>(
        () => IssueFormCubit(repository: repo, photoPicker: picker),
      )
      ..registerFactoryParam<IssueDetailsCubit, String, void>(
        (id, _) => IssueDetailsCubit(repository: repo, issueId: id),
      )
      ..registerFactory<StudentStatsCubit>(
        () => StudentStatsCubit(repository: repo),
      );
  }

  late final MockIssueRepository repo;
  late final MockPhotoPicker picker;
  late final MockAuthBloc auth;

  /// Answers `watchIssues` through [respond] for every filter.
  void issues(List<Issue> Function(IssueFilter filter) respond) {
    when(
      () => repo.watchIssues(
        filter: any(named: 'filter'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer(
      (inv) =>
          Stream.value(respond(inv.namedArguments[#filter] as IssueFilter)),
    );
  }

  Future<GoRouter> pump(WidgetTester tester, {String at = Routes.home}) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: at,
      routes: [
        GoRoute(path: Routes.home, builder: (_, _) => const StudentHomePage()),
        GoRoute(
          path: Routes.report,
          builder: (_, _) => const ReportIssuePage(),
        ),
        GoRoute(
          path: Routes.issuePattern,
          builder: (_, s) =>
              Scaffold(body: Text('details ${s.pathParameters['id']}')),
        ),
      ],
    );
    await tester.pumpWidget(
      BlocProvider<AuthBloc>.value(
        value: auth,
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
          // No looping animations, so frames settle.
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
        ),
      ),
    );
    await settle(tester);
    return router;
  }
}

/// Pumps a few frames (spinners never "settle", so avoid pumpAndSettle).
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void registerStudentFallbacks() {
  registerFallbackValue(const IssueFilter());
  registerFallbackValue(PhotoSource.gallery);
  registerFallbackValue(
    const NewIssueInput(
      title: '',
      description: '',
      category: IssueCategory.other,
      buildingId: '',
      locationDetail: '',
    ),
  );
}
