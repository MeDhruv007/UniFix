import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dio/dio.dart';
import 'package:fixmycampus/core/errors/failures.dart';
import 'package:fixmycampus/features/reports/domain/entities/issue.dart';
import 'package:fixmycampus/features/reports/domain/entities/issue_enums.dart';
import 'package:fixmycampus/features/reports/domain/entities/issue_update.dart';
import 'package:fixmycampus/features/reports/domain/repositories/issue_repository.dart';
import 'package:fixmycampus/features/reports/presentation/bloc/issue_details_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockIssueRepository extends Mock implements IssueRepository {}

/// An HTTP error without the API error body, so local fallback messages apply.
DioException _http(int status) {
  final options = RequestOptions(path: '/issues/i1');
  return DioException(
    requestOptions: options,
    type: DioExceptionType.badResponse,
    response: Response<void>(requestOptions: options, statusCode: status),
  );
}

const _issue = Issue(
  id: 'i1',
  campusId: 'adit-main',
  title: 'Broken bench',
  description: 'Bench near canteen is broken.',
  category: IssueCategory.furniture,
  buildingId: 'canteen',
  locationDetail: 'Outside entrance',
  reporterId: 'u1',
  status: IssueStatus.inProgress,
  priority: IssuePriority.high,
);

const _update = IssueUpdate(
  id: 'h1',
  actorId: 'u1',
  action: IssueUpdateAction.created,
  newStatus: IssueStatus.reported,
);

void main() {
  late _MockIssueRepository repo;

  setUp(() => repo = _MockIssueRepository());

  IssueDetailsCubit build() =>
      IssueDetailsCubit(repository: repo, issueId: 'i1');

  void stub({
    required Stream<Issue> issue,
    Stream<List<IssueUpdate>>? updates,
  }) {
    when(() => repo.watchIssue('i1')).thenAnswer((_) => issue);
    when(() => repo.watchUpdates('i1'))
        .thenAnswer((_) => updates ?? const Stream.empty());
  }

  blocTest<IssueDetailsCubit, IssueDetailsState>(
    'loads the issue and its timeline',
    setUp: () => stub(
      issue: Stream.value(_issue),
      updates: Stream.value(const [_update]),
    ),
    build: build,
    act: (c) => c.start(),
    expect: () => const [
      IssueDetailsState(),
      IssueDetailsState(status: IssueDetailsStatus.loaded, issue: _issue),
      IssueDetailsState(
        status: IssueDetailsStatus.loaded,
        issue: _issue,
        updates: [_update],
      ),
    ],
  );

  blocTest<IssueDetailsCubit, IssueDetailsState>(
    'NotFoundFailure maps to notFound',
    setUp: () => stub(
      issue: Stream.error(
        const NotFoundFailure('This report no longer exists.'),
      ),
    ),
    build: build,
    act: (c) => c.start(),
    expect: () => const [
      IssueDetailsState(),
      IssueDetailsState(
        status: IssueDetailsStatus.notFound,
        message: 'This report no longer exists.',
      ),
    ],
  );

  blocTest<IssueDetailsCubit, IssueDetailsState>(
    'API 404 also maps to notFound',
    setUp: () => stub(issue: Stream.error(_http(404))),
    build: build,
    act: (c) => c.start(),
    expect: () => const [
      IssueDetailsState(),
      IssueDetailsState(
        status: IssueDetailsStatus.notFound,
        message: 'That item could not be found.',
      ),
    ],
  );

  blocTest<IssueDetailsCubit, IssueDetailsState>(
    'other errors map to failure with a user-safe message',
    setUp: () => stub(issue: Stream.error(_http(403))),
    build: build,
    act: (c) => c.start(),
    expect: () => const [
      IssueDetailsState(),
      IssueDetailsState(
        status: IssueDetailsStatus.failure,
        message: 'You do not have permission to do that.',
      ),
    ],
  );

  blocTest<IssueDetailsCubit, IssueDetailsState>(
    'issue stays visible when it later fails',
    setUp: () {
      final c = StreamController<Issue>()
        ..add(_issue)
        ..addError(const NetworkFailure());
      stub(issue: c.stream);
    },
    build: build,
    act: (c) => c.start(),
    expect: () => const [
      IssueDetailsState(),
      IssueDetailsState(status: IssueDetailsStatus.loaded, issue: _issue),
      IssueDetailsState(
        status: IssueDetailsStatus.failure,
        issue: _issue,
        message:
            'You appear to be offline. Check your connection and try again.',
      ),
    ],
  );

  blocTest<IssueDetailsCubit, IssueDetailsState>(
    'timeline errors are ignored; the issue still loads',
    setUp: () => stub(
      issue: Stream.value(_issue),
      updates: Stream.error(const PermissionFailure()),
    ),
    build: build,
    act: (c) => c.start(),
    expect: () => const [
      IssueDetailsState(),
      IssueDetailsState(status: IssueDetailsStatus.loaded, issue: _issue),
    ],
  );

  test('restart and close cancel both subscriptions', () async {
    final issue1 = StreamController<Issue>();
    final updates1 = StreamController<List<IssueUpdate>>();
    final issue2 = StreamController<Issue>();
    final updates2 = StreamController<List<IssueUpdate>>();
    final issues = [issue1, issue2];
    final updates = [updates1, updates2];
    when(() => repo.watchIssue('i1'))
        .thenAnswer((_) => issues.removeAt(0).stream);
    when(() => repo.watchUpdates('i1'))
        .thenAnswer((_) => updates.removeAt(0).stream);

    final cubit = build()..start();
    expect(issue1.hasListener, isTrue);
    expect(updates1.hasListener, isTrue);

    cubit.start();
    expect(issue1.hasListener, isFalse);
    expect(updates1.hasListener, isFalse);
    expect(issue2.hasListener, isTrue);

    await cubit.close();
    expect(issue2.hasListener, isFalse);
    expect(updates2.hasListener, isFalse);
  });
}
