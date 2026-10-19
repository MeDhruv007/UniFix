import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:fixmycampus/core/errors/failures.dart';
import 'package:fixmycampus/core/theme/app_theme.dart';
import 'package:fixmycampus/core/utils/photo_picker.dart';
import 'package:fixmycampus/core/widgets/state_views.dart';
import 'package:fixmycampus/features/admin/presentation/bloc/admin_dashboard_cubit.dart';
import 'package:fixmycampus/features/admin/presentation/bloc/admin_issue_cubit.dart';
import 'package:fixmycampus/features/admin/presentation/pages/mark_resolved_page.dart';
import 'package:fixmycampus/features/admin/presentation/widgets/admin_format.dart';
import 'package:fixmycampus/features/admin/presentation/widgets/admin_overview_tab.dart';
import 'package:fixmycampus/features/admin/presentation/widgets/triage_queue_tab.dart';
import 'package:fixmycampus/features/admin/presentation/widgets/update_issue_sheet.dart';
import 'package:fixmycampus/features/auth/domain/entities/app_user.dart';
import 'package:fixmycampus/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:fixmycampus/features/reports/domain/entities/issue.dart';
import 'package:fixmycampus/features/reports/domain/entities/issue_enums.dart';
import 'package:fixmycampus/features/reports/domain/entities/issue_update.dart';
import 'package:fixmycampus/features/reports/domain/repositories/issue_repository.dart';
import 'package:fixmycampus/features/reports/presentation/bloc/issue_details_cubit.dart';
import 'package:fixmycampus/features/reports/presentation/bloc/issue_list_bloc.dart';
import 'package:fixmycampus/injection_container.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockIssueRepository extends Mock implements IssueRepository {}

class _MockPhotoPicker extends Mock implements PhotoPicker {}

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

const _admin = AppUser(
  uid: 'a1',
  displayName: 'Rohan Mehta',
  email: 'rohan@adit.edu',
  role: UserRole.admin,
  campusId: 'adit-main',
  isActive: true,
);

const _stats = IssueStats(
  open: 128,
  urgent: 7,
  unassigned: 19,
  reopened: 4,
  createdLast24h: 12,
  resolvedThisWeek: 34,
  avgResolutionHours: 57.6,
  openByCategory: {
    IssueCategory.electrical: 38,
    IssueCategory.plumbing: 27,
    IssueCategory.cleanliness: 22,
    IssueCategory.it: 18,
    IssueCategory.furniture: 13,
    IssueCategory.safety: 7,
  },
);

Issue _issue({
  String id = 'i1',
  IssueStatus status = IssueStatus.reported,
  IssuePriority priority = IssuePriority.high,
  String title = 'Washbasin leaking in the first floor washroom',
}) => Issue(
  id: id,
  campusId: 'adit-main',
  title: title,
  description: 'Water everywhere.',
  category: IssueCategory.plumbing,
  buildingId: 'hostel',
  locationDetail: '1F washroom',
  reporterId: 'u1',
  status: status,
  priority: priority,
  number: 479,
  createdAt: DateTime.now().subtract(const Duration(hours: 5)),
);

void main() {
  late _MockIssueRepository repo;
  late _MockPhotoPicker picker;
  late _MockAuthBloc auth;

  setUpAll(() {
    registerFallbackValue(IssueStatus.reported);
    registerFallbackValue(IssuePriority.medium);
    registerFallbackValue(const IssueFilter());
  });

  setUp(() {
    repo = _MockIssueRepository();
    picker = _MockPhotoPicker();
    auth = _MockAuthBloc();
    when(() => auth.state).thenReturn(
      const AuthState(session: SessionStatus.authenticated, user: _admin),
    );
    when(() => repo.listStaff()).thenAnswer(
      (_) async => const [
        StaffMember(id: 's1', displayName: 'Sana Patel'),
        StaffMember(id: 'a1', displayName: 'Rohan Mehta'),
      ],
    );
    getIt
      ..allowReassignment = true
      ..registerFactory<AdminIssueCubit>(
        () => AdminIssueCubit(repository: repo, photoPicker: picker),
      );
  });

  tearDown(() async {
    await getIt.reset();
  });

  Future<void> pump(WidgetTester tester, Widget child) async {
    tester.view
      ..physicalSize = const Size(360 * 3, 780 * 3)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      RepositoryProvider<IssueRepository>.value(
        value: repo,
        child: BlocProvider<AuthBloc>.value(
          value: auth,
          child: MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(body: child),
          ),
        ),
      ),
    );
  }

  group('AdminFormat', () {
    test('resolution', () {
      expect(AdminFormat.resolution(null), '—');
      expect(AdminFormat.resolution(5), '5h');
      expect(AdminFormat.resolution(57.6), '2.4d');
      expect(AdminFormat.resolution(48), '2d');
    });
  });

  group('Overview', () {
    Future<QueuePreset?> pumpOverview(
      WidgetTester tester,
      Stream<IssueStats> stats,
    ) async {
      when(() => repo.watchStats()).thenAnswer((_) => stats);
      QueuePreset? opened;
      await pump(
        tester,
        BlocProvider(
          create: (_) => AdminDashboardCubit(repository: repo)..start(),
          child: AdminOverviewTab(onOpenQueue: (p) => opened = p),
        ),
      );
      await tester.pump();
      return opened;
    }

    testWidgets('loading', (tester) async {
      await pumpOverview(tester, StreamController<IssueStats>().stream);
      expect(find.byType(LoadingView), findsOneWidget);
      expect(find.text('Hello, Rohan'), findsOneWidget);
    });

    testWidgets('loaded renders stats; tiles open the queue', (tester) async {
      when(() => repo.watchStats()).thenAnswer((_) => Stream.value(_stats));
      QueuePreset? opened;
      await pump(
        tester,
        BlocProvider(
          create: (_) => AdminDashboardCubit(repository: repo)..start(),
          child: AdminOverviewTab(onOpenQueue: (p) => opened = p),
        ),
      );
      await tester.pump();
      expect(find.text('128'), findsOneWidget);
      expect(find.text('+12 since yesterday'), findsOneWidget);
      expect(find.text('2.4d'), findsOneWidget);
      expect(find.text('Electrical'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Urgent'));
      expect(opened, QueuePreset.urgent);
      await tester.tap(find.text('Unassigned'));
      expect(opened, QueuePreset.unassigned);
    });

    testWidgets('error with retry', (tester) async {
      await pumpOverview(tester, Stream.error(const NetworkFailure()));
      expect(find.byType(ErrorView), findsOneWidget);
    });
  });

  group('Queue', () {
    Future<void> pumpQueue(
      WidgetTester tester,
      Stream<List<Issue>> Function() issues,
    ) async {
      when(() => repo.watchStats()).thenAnswer((_) => Stream.value(_stats));
      when(
        () => repo.watchIssues(
          filter: any(named: 'filter'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) => issues());
      await pump(
        tester,
        MultiBlocProvider(
          providers: [
            BlocProvider(
              create: (_) => AdminDashboardCubit(repository: repo)..start(),
            ),
            BlocProvider(
              create: (_) =>
                  IssueListBloc(repository: repo)
                    ..add(const IssueListSubscribed(queueDefaultFilter)),
            ),
          ],
          child: const TriageQueueTab(),
        ),
      );
      await tester.pump();
      await tester.pump();
    }

    testWidgets('loaded cards, chips and assign sheet', (tester) async {
      await pumpQueue(
        tester,
        () => Stream.value([
          _issue(priority: IssuePriority.urgent),
          _issue(id: 'i2', priority: IssuePriority.low, title: 'Tube light'),
        ]),
      );
      expect(find.text('Needs triage'), findsOneWidget);
      expect(find.text('19 unassigned issues'), findsOneWidget);
      expect(find.text('FMC-0479 · 5h'), findsNWidgets(2));
      expect(find.text('Assign'), findsNWidgets(2));
      expect(tester.takeException(), isNull);

      // Oldest toggles the sort.
      await tester.ensureVisible(find.text('Oldest'));
      await tester.tap(find.text('Oldest'));
      await tester.pump();
      await tester.pump();
      verify(
        () => repo.watchIssues(
          filter: const IssueFilter(
            openOnly: true,
            assigned: false,
            sort: IssueSort.oldest,
          ),
          limit: any(named: 'limit'),
        ),
      ).called(1);

      await tester.tap(find.text('Assign').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Update issue'), findsOneWidget);
      expect(find.text('Sana Patel'), findsOneWidget);
      expect(find.text('Rohan Mehta (you)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('empty', (tester) async {
      await pumpQueue(tester, () => Stream.value(const []));
      expect(find.byType(EmptyView), findsOneWidget);
    });

    testWidgets('error', (tester) async {
      await pumpQueue(tester, () => Stream.error(const NetworkFailure()));
      expect(find.byType(ErrorView), findsOneWidget);
    });
  });

  group('Update issue sheet', () {
    Future<void> openSheet(WidgetTester tester, Issue issue) async {
      await pump(
        tester,
        Builder(
          builder: (context) => Center(
            child: FilledButton(
              onPressed: () => showUpdateIssueSheet(context, issue),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }

    testWidgets('saves only the changed priority', (tester) async {
      when(
        () => repo.updatePriority(
          any(),
          from: any(named: 'from'),
          to: any(named: 'to'),
        ),
      ).thenAnswer((_) async {});
      await openSheet(tester, _issue());
      expect(find.text('FMC-0479 · PLUMBING'), findsOneWidget);
      expect(find.text('Added to history as Rohan Mehta'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Urgent'));
      await tester.pump();
      await tester.ensureVisible(find.text('Save changes'));
      await tester.tap(find.text('Save changes'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      verify(
        () => repo.updatePriority(
          'i1',
          from: IssuePriority.high,
          to: IssuePriority.urgent,
        ),
      ).called(1);
      verifyNever(() => repo.assignTo(any(), any()));
      expect(find.text('Update issue'), findsNothing);
      expect(
        find.text('Changes saved · added to history as Rohan Mehta.'),
        findsOneWidget,
      );
    });

    testWidgets('partial failure says which change failed', (tester) async {
      when(
        () => repo.updatePriority(
          any(),
          from: any(named: 'from'),
          to: any(named: 'to'),
        ),
      ).thenThrow(const PermissionFailure());
      when(() => repo.assignTo(any(), any())).thenAnswer((_) async {});
      await openSheet(tester, _issue());

      await tester.tap(find.text('Low'));
      await tester.ensureVisible(find.text('Sana Patel'));
      await tester.tap(find.text('Sana Patel'));
      await tester.pump();
      await tester.ensureVisible(find.text('Save changes'));
      await tester.tap(find.text('Save changes'));
      await tester.pump();
      await tester.pump();

      expect(find.textContaining('Saved assignee.'), findsOneWidget);
      expect(find.textContaining('Priority: '), findsOneWidget);
      expect(find.text('Update issue'), findsOneWidget);
    });
  });

  group('Mark resolved', () {
    Future<void> pumpResolve(
      WidgetTester tester,
      Stream<Issue> Function() issue,
    ) async {
      when(() => repo.watchIssue(any())).thenAnswer((_) => issue());
      when(() => repo.watchUpdates(any()))
          .thenAnswer((_) => Stream.value(const <IssueUpdate>[]));
      await pump(
        tester,
        MultiBlocProvider(
          providers: [
            BlocProvider(
              create: (_) =>
                  IssueDetailsCubit(repository: repo, issueId: 'i1')..start(),
            ),
            BlocProvider(
              create: (_) =>
                  AdminIssueCubit(repository: repo, photoPicker: picker),
            ),
          ],
          child: const MarkResolvedView(),
        ),
      );
      await tester.pump();
    }

    testWidgets('loading', (tester) async {
      await pumpResolve(tester, () => StreamController<Issue>().stream);
      expect(find.byType(LoadingView), findsOneWidget);
    });

    testWidgets('error', (tester) async {
      await pumpResolve(tester, () => Stream.error(const NetworkFailure()));
      expect(find.byType(ErrorView), findsOneWidget);
    });

    testWidgets('form requires a note, then resolves', (tester) async {
      when(
        () => repo.updateStatus(
          any(),
          from: any(named: 'from'),
          to: any(named: 'to'),
          note: any(named: 'note'),
        ),
      ).thenAnswer((_) async {});
      await pumpResolve(
        tester,
        () => Stream.value(_issue(status: IssueStatus.inProgress)),
      );
      expect(find.text('Resolve issue'), findsOneWidget);
      expect(
        find.text('The reporter will be asked to confirm the fix'),
        findsOneWidget,
      );
      expect(find.byType(Checkbox), findsNothing);
      expect(find.text('Take photo'), findsOneWidget);
      expect(find.text('or choose from gallery'), findsOneWidget);
      expect(find.text('0 / 500'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Mark as resolved'));
      await tester.pump();
      expect(
        find.text('Describe what was done before resolving.'),
        findsOneWidget,
      );

      await tester.enterText(find.byType(TextField), 'Replaced the washer.');
      await tester.pump();
      expect(find.text('20 / 500'), findsOneWidget);
      await tester.tap(find.text('Mark as resolved'));
      await tester.pump();
      verify(
        () => repo.updateStatus(
          'i1',
          from: IssueStatus.inProgress,
          to: IssueStatus.resolved,
          note: 'Replaced the washer.',
        ),
      ).called(1);
    });

    testWidgets('reported issue cannot be resolved yet', (tester) async {
      await pumpResolve(tester, () => Stream.value(_issue()));
      expect(find.textContaining('Start work on this issue'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
