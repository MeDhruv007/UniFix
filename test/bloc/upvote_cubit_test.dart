import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:fixmycampus/core/errors/failures.dart';
import 'package:fixmycampus/features/reports/domain/entities/issue.dart';
import 'package:fixmycampus/features/reports/domain/entities/issue_enums.dart';
import 'package:fixmycampus/features/reports/domain/repositories/issue_repository.dart';
import 'package:fixmycampus/features/reports/presentation/bloc/upvote_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements IssueRepository {}

Issue _issue({int count = 0, bool mine = false}) => Issue(
  id: 'i1',
  campusId: 'adit-main',
  title: 'Broken fan',
  description: 'The fan does not start.',
  category: IssueCategory.electrical,
  buildingId: 'library',
  locationDetail: 'Room 1',
  reporterId: 'someone-else',
  status: IssueStatus.reported,
  priority: IssuePriority.medium,
  upvoteCount: count,
  upvotedByMe: mine,
);

void main() {
  late _MockRepo repo;

  setUp(() => repo = _MockRepo());

  UpvoteCubit build({int count = 2, bool mine = false}) => UpvoteCubit(
    repository: repo,
    issue: _issue(count: count, mine: mine),
  );

  blocTest<UpvoteCubit, UpvoteState>(
    'flips instantly, then adopts the server numbers',
    setUp: () =>
        when(() => repo.setUpvote('i1', upvoted: true))
            .thenAnswer((_) async => _issue(count: 3, mine: true)),
    build: build,
    act: (c) => c.toggle(),
    expect: () => const [
      UpvoteState(upvoted: true, count: 3, busy: true),
      UpvoteState(upvoted: true, count: 3),
    ],
  );

  blocTest<UpvoteCubit, UpvoteState>(
    'taking it back lowers the count',
    setUp: () =>
        when(() => repo.setUpvote('i1', upvoted: false))
            .thenAnswer((_) async => _issue(count: 1)),
    build: () => build(count: 2, mine: true),
    act: (c) => c.toggle(),
    expect: () => const [
      UpvoteState(upvoted: false, count: 1, busy: true),
      UpvoteState(upvoted: false, count: 1),
    ],
  );

  blocTest<UpvoteCubit, UpvoteState>(
    'rolls back with a message when the server refuses',
    setUp: () => when(() => repo.setUpvote('i1', upvoted: true))
        .thenThrow(const ConflictFailure('This issue is already resolved.')),
    build: build,
    act: (c) => c.toggle(),
    expect: () => const [
      UpvoteState(upvoted: true, count: 3, busy: true),
      UpvoteState(
        upvoted: false,
        count: 2,
        message: 'This issue is already resolved.',
      ),
    ],
  );

  test('ignores taps while a request is in flight', () async {
    final pending = Completer<Issue>();
    when(() => repo.setUpvote('i1', upvoted: true))
        .thenAnswer((_) => pending.future);
    final cubit = build();
    unawaited(cubit.toggle());
    await cubit.toggle(); // second tap, ignored
    pending.complete(_issue(count: 3, mine: true));
    await Future<void>.delayed(Duration.zero);
    verify(() => repo.setUpvote('i1', upvoted: true)).called(1);
    await cubit.close();
  });

  blocTest<UpvoteCubit, UpvoteState>(
    'sync adopts fresh numbers from the live issue',
    build: build,
    act: (c) => c.sync(_issue(count: 5, mine: true)),
    expect: () => const [UpvoteState(upvoted: true, count: 5)],
  );

  blocTest<UpvoteCubit, UpvoteState>(
    'sync is a no-op when nothing changed',
    build: () => build(count: 2),
    act: (c) => c.sync(_issue(count: 2)),
    expect: () => const <UpvoteState>[],
  );
}
