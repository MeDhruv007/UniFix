import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:fixmycampus/core/constants/app_constants.dart';
import 'package:fixmycampus/core/errors/failures.dart';
import 'package:fixmycampus/features/reports/domain/entities/issue.dart';
import 'package:fixmycampus/features/reports/domain/entities/issue_enums.dart';
import 'package:fixmycampus/features/reports/domain/repositories/issue_repository.dart';
import 'package:fixmycampus/features/reports/presentation/bloc/issue_list_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockIssueRepository extends Mock implements IssueRepository {}

Issue _issue(String id) => Issue(
  id: id,
  campusId: 'adit-main',
  title: 'Broken fan $id',
  description: 'The ceiling fan does not turn on.',
  category: IssueCategory.electrical,
  buildingId: 'library',
  locationDetail: 'Room 101',
  reporterId: 'u1',
  status: IssueStatus.reported,
  priority: IssuePriority.medium,
);

List<Issue> _issues(int n, [String prefix = 'i']) =>
    List.generate(n, (i) => _issue('$prefix$i'));

const _pageSize = AppConstants.feedPageSize;

void main() {
  late _MockIssueRepository repo;

  setUpAll(() => registerFallbackValue(const IssueFilter()));

  setUp(() => repo = _MockIssueRepository());

  void stubWatch(Stream<List<Issue>> Function(IssueFilter, int) answer) {
    when(
      () => repo.watchIssues(
        filter: any(named: 'filter'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer(
      (inv) => answer(
        inv.namedArguments[#filter] as IssueFilter,
        inv.namedArguments[#limit] as int,
      ),
    );
  }

  group('subscribe', () {
    final page = _issues(3);

    blocTest<IssueListBloc, IssueListState>(
      'emits loading then loaded',
      setUp: () => stubWatch((_, _) => Stream.value(page)),
      build: () => IssueListBloc(repository: repo),
      act: (b) => b.add(const IssueListSubscribed(IssueFilter())),
      expect: () => [
        const IssueListState(status: IssueListStatus.loading),
        IssueListState(status: IssueListStatus.loaded, issues: page),
      ],
      verify: (b) {
        expect(b.state.hasMore, isFalse);
        verify(
          () => repo.watchIssues(filter: const IssueFilter(), limit: _pageSize),
        ).called(1);
      },
    );

    blocTest<IssueListBloc, IssueListState>(
      'emits loading then empty loaded state',
      setUp: () => stubWatch((_, _) => Stream.value(const [])),
      build: () => IssueListBloc(repository: repo),
      act: (b) => b.add(const IssueListSubscribed(IssueFilter())),
      expect: () => [
        const IssueListState(status: IssueListStatus.loading),
        const IssueListState(status: IssueListStatus.loaded),
      ],
      verify: (b) => expect(b.state.isEmpty, isTrue),
    );

    blocTest<IssueListBloc, IssueListState>(
      'subscribes with a reporter filter ("My reports")',
      setUp: () => stubWatch((_, _) => Stream.value(page)),
      build: () => IssueListBloc(repository: repo),
      act: (b) =>
          b.add(const IssueListSubscribed(IssueFilter(reporterId: 'u1'))),
      expect: () => [
        const IssueListState(
          status: IssueListStatus.loading,
          filter: IssueFilter(reporterId: 'u1'),
        ),
        IssueListState(
          status: IssueListStatus.loaded,
          issues: page,
          filter: const IssueFilter(reporterId: 'u1'),
        ),
      ],
    );

    blocTest<IssueListBloc, IssueListState>(
      'stream Failure becomes failure state with its message',
      setUp: () => stubWatch((_, _) => Stream.error(const PermissionFailure())),
      build: () => IssueListBloc(repository: repo),
      act: (b) => b.add(const IssueListSubscribed(IssueFilter())),
      expect: () => [
        const IssueListState(status: IssueListStatus.loading),
        const IssueListState(
          status: IssueListStatus.failure,
          message: 'You do not have permission to do that.',
        ),
      ],
    );

    blocTest<IssueListBloc, IssueListState>(
      'raw exception is mapped to a user-safe message',
      setUp: () => stubWatch(
        (_, _) => Stream.error(StateError('secret rule internals')),
      ),
      build: () => IssueListBloc(repository: repo),
      act: (b) => b.add(const IssueListSubscribed(IssueFilter())),
      expect: () => [
        const IssueListState(status: IssueListStatus.loading),
        const IssueListState(
          status: IssueListStatus.failure,
          message: 'Something went wrong. Please try again.',
        ),
      ],
    );

    blocTest<IssueListBloc, IssueListState>(
      'recovers from failure when the stream emits again',
      setUp: () => stubWatch((_, _) {
        final c = StreamController<List<Issue>>();
        c
          ..addError(const NetworkFailure())
          ..add(page);
        return c.stream;
      }),
      build: () => IssueListBloc(repository: repo),
      act: (b) => b.add(const IssueListSubscribed(IssueFilter())),
      expect: () => [
        const IssueListState(status: IssueListStatus.loading),
        const IssueListState(
          status: IssueListStatus.failure,
          message:
              'You appear to be offline. Check your connection and try again.',
        ),
        IssueListState(status: IssueListStatus.loaded, issues: page),
      ],
    );
  });

  group('filters', () {
    final oldPage = _issues(2, 'old');
    final newPage = _issues(1, 'new');

    blocTest<IssueListBloc, IssueListState>(
      'status filter change clears items, resubscribes, keeps other filters',
      setUp: () => stubWatch((_, _) => Stream.value(newPage)),
      build: () => IssueListBloc(repository: repo),
      seed: () => IssueListState(
        status: IssueListStatus.loaded,
        issues: oldPage,
        filter: const IssueFilter(
          category: IssueCategory.plumbing,
          reporterId: 'u1',
        ),
        limit: _pageSize * 2,
      ),
      act: (b) =>
          b.add(const IssueListStatusFilterChanged(IssueStatus.resolved)),
      expect: () => [
        const IssueListState(
          status: IssueListStatus.loading,
          filter: IssueFilter(
            status: IssueStatus.resolved,
            category: IssueCategory.plumbing,
            reporterId: 'u1',
          ),
        ),
        IssueListState(
          status: IssueListStatus.loaded,
          issues: newPage,
          filter: const IssueFilter(
            status: IssueStatus.resolved,
            category: IssueCategory.plumbing,
            reporterId: 'u1',
          ),
        ),
      ],
      verify: (_) => verify(
        () => repo.watchIssues(
          filter: const IssueFilter(
            status: IssueStatus.resolved,
            category: IssueCategory.plumbing,
            reporterId: 'u1',
          ),
          // Limit resets to one page on a new filter.
          limit: _pageSize,
        ),
      ).called(1),
    );

    blocTest<IssueListBloc, IssueListState>(
      'category filter change clears items and keeps status filter',
      setUp: () => stubWatch((_, _) => Stream.value(newPage)),
      build: () => IssueListBloc(repository: repo),
      seed: () => IssueListState(
        status: IssueListStatus.loaded,
        issues: oldPage,
        filter: const IssueFilter(status: IssueStatus.inProgress),
      ),
      act: (b) => b.add(const IssueListCategoryFilterChanged(IssueCategory.it)),
      expect: () => [
        const IssueListState(
          status: IssueListStatus.loading,
          filter: IssueFilter(
            status: IssueStatus.inProgress,
            category: IssueCategory.it,
          ),
        ),
        IssueListState(
          status: IssueListStatus.loaded,
          issues: newPage,
          filter: const IssueFilter(
            status: IssueStatus.inProgress,
            category: IssueCategory.it,
          ),
        ),
      ],
    );

    test('a new filter cancels the previous Firestore listener', () async {
      final first = StreamController<List<Issue>>();
      final second = StreamController<List<Issue>>();
      stubWatch((f, _) => f.status == null ? first.stream : second.stream);

      final bloc = IssueListBloc(repository: repo)
        ..add(const IssueListSubscribed(IssueFilter()));
      await pumpEventQueue();
      expect(first.hasListener, isTrue);

      bloc.add(const IssueListStatusFilterChanged(IssueStatus.resolved));
      await pumpEventQueue();
      expect(first.hasListener, isFalse);
      expect(second.hasListener, isTrue);

      // Late data from the old query must not leak into the new filter.
      first.add(oldPage);
      second.add(newPage);
      await pumpEventQueue();
      expect(bloc.state.issues, newPage);
      expect(bloc.state.filter.status, IssueStatus.resolved);

      await bloc.close();
      expect(second.hasListener, isFalse);
    });
  });

  group('load more', () {
    final fullPage = _issues(_pageSize);
    final bigger = _issues(_pageSize + 5);

    blocTest<IssueListBloc, IssueListState>(
      'grows the limit and keeps current items visible',
      setUp: () => stubWatch((_, _) => Stream.value(bigger)),
      build: () => IssueListBloc(repository: repo),
      seed: () =>
          IssueListState(status: IssueListStatus.loaded, issues: fullPage),
      act: (b) => b.add(const IssueListLoadMoreRequested()),
      expect: () => [
        IssueListState(
          status: IssueListStatus.loaded,
          issues: fullPage,
          limit: _pageSize * 2,
        ),
        IssueListState(
          status: IssueListStatus.loaded,
          issues: bigger,
          limit: _pageSize * 2,
        ),
      ],
      verify: (b) {
        expect(b.state.hasMore, isFalse);
        verify(
          () => repo.watchIssues(
            filter: const IssueFilter(),
            limit: _pageSize * 2,
          ),
        ).called(1);
      },
    );

    blocTest<IssueListBloc, IssueListState>(
      'does nothing when the last page was not full',
      build: () => IssueListBloc(repository: repo),
      seed: () =>
          IssueListState(status: IssueListStatus.loaded, issues: _issues(5)),
      act: (b) => b.add(const IssueListLoadMoreRequested()),
      expect: () => const <IssueListState>[],
      verify: (_) => verifyNever(
        () => repo.watchIssues(
          filter: any(named: 'filter'),
          limit: any(named: 'limit'),
        ),
      ),
    );

    blocTest<IssueListBloc, IssueListState>(
      'does nothing while loading',
      build: () => IssueListBloc(repository: repo),
      seed: () =>
          IssueListState(status: IssueListStatus.loading, issues: fullPage),
      act: (b) => b.add(const IssueListLoadMoreRequested()),
      expect: () => const <IssueListState>[],
    );

    blocTest<IssueListBloc, IssueListState>(
      'does nothing after a failure',
      build: () => IssueListBloc(repository: repo),
      seed: () => IssueListState(
        status: IssueListStatus.failure,
        issues: fullPage,
        message: 'x',
      ),
      act: (b) => b.add(const IssueListLoadMoreRequested()),
      expect: () => const <IssueListState>[],
    );
  });

  group('refresh', () {
    blocTest<IssueListBloc, IssueListState>(
      're-subscribes with the same filter and limit, keeping items visible',
      setUp: () {
        var calls = 0;
        stubWatch((_, _) {
          calls++;
          return Stream.value(calls == 1 ? _issues(2) : _issues(3));
        });
      },
      build: () => IssueListBloc(repository: repo),
      act: (b) async {
        b.add(
          const IssueListSubscribed(IssueFilter(status: IssueStatus.reported)),
        );
        await Future<void>.delayed(Duration.zero);
        b.add(const IssueListRefreshRequested());
      },
      skip: 2,
      expect: () => [
        IssueListState(
          status: IssueListStatus.loaded,
          issues: _issues(3),
          filter: const IssueFilter(status: IssueStatus.reported),
        ),
      ],
      verify: (_) => verify(
        () => repo.watchIssues(
          filter: const IssueFilter(status: IssueStatus.reported),
          limit: _pageSize,
        ),
      ).called(2),
    );
  });
}
