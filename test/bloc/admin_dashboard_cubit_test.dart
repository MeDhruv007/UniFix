import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:fixmycampus/core/errors/failures.dart';
import 'package:fixmycampus/features/admin/presentation/bloc/admin_dashboard_cubit.dart';
import 'package:fixmycampus/features/reports/domain/entities/issue_enums.dart';
import 'package:fixmycampus/features/reports/domain/repositories/issue_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockIssueRepository extends Mock implements IssueRepository {}

const _stats = IssueStats(
  reported: 4,
  inProgress: 3,
  resolved: 7,
  reopened: 1,
  total: 15,
  open: 8,
  urgent: 2,
  unassigned: 5,
  createdLast24h: 3,
  resolvedThisWeek: 6,
  avgResolutionHours: 30,
  openByCategory: {IssueCategory.electrical: 5, IssueCategory.plumbing: 3},
);

const _newer = IssueStats(open: 9, total: 16);

void main() {
  late _MockIssueRepository repo;

  setUp(() => repo = _MockIssueRepository());

  blocTest<AdminDashboardCubit, AdminDashboardState>(
    'start subscribes to watchStats and emits every update',
    setUp: () =>
        when(() => repo.watchStats())
            .thenAnswer((_) => Stream.fromIterable([_stats, _newer])),
    build: () => AdminDashboardCubit(repository: repo),
    act: (c) => c.start(),
    expect: () => [
      const AdminDashboardState(status: AdminDashboardStatus.loading),
      const AdminDashboardState(
        status: AdminDashboardStatus.loaded,
        stats: _stats,
      ),
      const AdminDashboardState(
        status: AdminDashboardStatus.loaded,
        stats: _newer,
      ),
    ],
    verify: (_) => verifyNever(() => repo.countIssues()),
  );

  blocTest<AdminDashboardCubit, AdminDashboardState>(
    'stream errors keep the last stats and expose a user-safe message',
    setUp: () {
      final controller = StreamController<IssueStats>();
      when(() => repo.watchStats()).thenAnswer((_) => controller.stream);
      controller
        ..add(_stats)
        ..addError(const NetworkFailure());
    },
    build: () => AdminDashboardCubit(repository: repo),
    act: (c) => c.start(),
    expect: () => [
      const AdminDashboardState(status: AdminDashboardStatus.loading),
      const AdminDashboardState(
        status: AdminDashboardStatus.loaded,
        stats: _stats,
      ),
      const AdminDashboardState(
        status: AdminDashboardStatus.failure,
        stats: _stats,
        message:
            'You appear to be offline. Check your connection and try again.',
      ),
    ],
  );

  blocTest<AdminDashboardCubit, AdminDashboardState>(
    'refresh fetches stats once',
    setUp: () => when(() => repo.stats()).thenAnswer((_) async => _newer),
    build: () => AdminDashboardCubit(repository: repo),
    seed: () => const AdminDashboardState(
      status: AdminDashboardStatus.loaded,
      stats: _stats,
    ),
    act: (c) => c.refresh(),
    expect: () => [
      const AdminDashboardState(
        status: AdminDashboardStatus.loaded,
        stats: _newer,
      ),
    ],
  );

  blocTest<AdminDashboardCubit, AdminDashboardState>(
    'unknown errors become a generic message',
    setUp: () => when(() => repo.stats()).thenThrow(Exception('internal')),
    build: () => AdminDashboardCubit(repository: repo),
    act: (c) => c.refresh(),
    expect: () => [
      const AdminDashboardState(
        status: AdminDashboardStatus.failure,
        message: 'Something went wrong. Please try again.',
      ),
    ],
  );
}
