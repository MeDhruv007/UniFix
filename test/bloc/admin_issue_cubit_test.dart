import 'package:bloc_test/bloc_test.dart';
import 'package:fixmycampus/core/errors/failures.dart';
import 'package:fixmycampus/core/utils/photo_picker.dart';
import 'package:fixmycampus/features/admin/presentation/bloc/admin_issue_cubit.dart';
import 'package:fixmycampus/features/reports/domain/entities/issue.dart';
import 'package:fixmycampus/features/reports/domain/entities/issue_enums.dart';
import 'package:fixmycampus/features/reports/domain/repositories/issue_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockIssueRepository extends Mock implements IssueRepository {}

class _MockPhotoPicker extends Mock implements PhotoPicker {}

const _issue = Issue(
  id: 'i1',
  campusId: 'adit-main',
  title: 'Broken fan',
  description: 'The fan in room 101 does not spin.',
  category: IssueCategory.electrical,
  buildingId: 'a-block',
  locationDetail: 'Room 101',
  reporterId: 'u1',
  status: IssueStatus.reported,
  priority: IssuePriority.medium,
);

const _inProgress = Issue(
  id: 'i1',
  campusId: 'adit-main',
  title: 'Broken fan',
  description: 'The fan in room 101 does not spin.',
  category: IssueCategory.electrical,
  buildingId: 'a-block',
  locationDetail: 'Room 101',
  reporterId: 'u1',
  status: IssueStatus.inProgress,
  priority: IssuePriority.medium,
  resolutionPhotoPaths: ['r/1.jpg'],
);

const _staff = [
  StaffMember(id: 's1', displayName: 'Sana Patel'),
  StaffMember(id: 's2', displayName: 'Kiran Joshi'),
];

void main() {
  late _MockIssueRepository repo;
  late _MockPhotoPicker picker;

  setUpAll(() {
    registerFallbackValue(IssueStatus.reported);
    registerFallbackValue(IssuePriority.medium);
    registerFallbackValue(PhotoSource.gallery);
  });

  setUp(() {
    repo = _MockIssueRepository();
    picker = _MockPhotoPicker();
    when(() => repo.listStaff()).thenAnswer((_) async => _staff);
    when(
      () => repo.updateStatus(
        any(),
        from: any(named: 'from'),
        to: any(named: 'to'),
        note: any(named: 'note'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => repo.updatePriority(
        any(),
        from: any(named: 'from'),
        to: any(named: 'to'),
      ),
    ).thenAnswer((_) async {});
    when(() => repo.assignTo(any(), any())).thenAnswer((_) async {});
    when(
      () => repo.addResolutionPhotos(
        any(),
        any(),
        existingCount: any(named: 'existingCount'),
      ),
    ).thenAnswer((_) async {});
  });

  AdminIssueCubit build() =>
      AdminIssueCubit(repository: repo, photoPicker: picker);

  /// State after `init(_issue)` with staff loaded.
  const ready = AdminIssueState(
    issue: _issue,
    status: IssueStatus.reported,
    priority: IssuePriority.medium,
    staffStatus: StaffListStatus.loaded,
    staff: _staff,
  );

  group('update sheet', () {
    blocTest<AdminIssueCubit, AdminIssueState>(
      'init seeds drafts and loads staff',
      build: build,
      act: (c) => c.init(_issue),
      expect: () => [
        const AdminIssueState(
          issue: _issue,
          status: IssueStatus.reported,
          priority: IssuePriority.medium,
        ),
        const AdminIssueState(
          issue: _issue,
          status: IssueStatus.reported,
          priority: IssuePriority.medium,
          staffStatus: StaffListStatus.loading,
        ),
        ready,
      ],
    );

    blocTest<AdminIssueCubit, AdminIssueState>(
      'staff load failure is shown, not thrown',
      setUp: () =>
          when(() => repo.listStaff()).thenThrow(const NetworkFailure()),
      build: build,
      act: (c) => c.init(_issue),
      skip: 2,
      expect: () => [
        const AdminIssueState(
          issue: _issue,
          status: IssueStatus.reported,
          priority: IssuePriority.medium,
          staffStatus: StaffListStatus.failure,
        ),
      ],
    );

    blocTest<AdminIssueCubit, AdminIssueState>(
      'invalid status selections and Resolved are ignored',
      build: build,
      seed: () => ready,
      act: (c) => c
        ..selectStatus(IssueStatus.resolved)
        ..selectStatus(IssueStatus.reopened),
      expect: () => <AdminIssueState>[],
    );

    blocTest<AdminIssueCubit, AdminIssueState>(
      'save applies only what changed',
      build: build,
      seed: () => ready,
      act: (c) async {
        c
          ..selectStatus(IssueStatus.inProgress)
          ..selectAssignee('s1');
        await c.save(note: '  On it  ');
      },
      verify: (c) {
        expect(c.state.submit, AdminSubmitStatus.success);
        expect(c.state.hasChanges, isFalse);
        verify(
          () => repo.updateStatus(
            'i1',
            from: IssueStatus.reported,
            to: IssueStatus.inProgress,
            note: 'On it',
          ),
        ).called(1);
        verify(() => repo.assignTo('i1', 's1')).called(1);
        verifyNever(
          () => repo.updatePriority(
            any(),
            from: any(named: 'from'),
            to: any(named: 'to'),
          ),
        );
      },
    );

    blocTest<AdminIssueCubit, AdminIssueState>(
      'partial failure names the failed change and keeps it pending',
      setUp: () => when(
        () => repo.updatePriority(
          any(),
          from: any(named: 'from'),
          to: any(named: 'to'),
        ),
      ).thenThrow(const PermissionFailure()),
      build: build,
      seed: () => ready,
      act: (c) async {
        c
          ..selectPriority(IssuePriority.urgent)
          ..selectAssignee('s2');
        await c.save();
      },
      verify: (c) {
        final s = c.state;
        expect(s.submit, AdminSubmitStatus.failure);
        expect(s.message, contains('Saved assignee.'));
        expect(
          s.message,
          contains('Priority: You do not have permission to do that.'),
        );
        expect(s.assigneeChanged, isFalse);
        expect(s.priorityChanged, isTrue);
      },
    );

    blocTest<AdminIssueCubit, AdminIssueState>(
      'unassigning sends null',
      build: build,
      seed: () => const AdminIssueState(
        issue: _assigned,
        status: IssueStatus.inProgress,
        priority: IssuePriority.medium,
        assigneeId: 's1',
      ),
      act: (c) async {
        c.selectAssignee(null);
        await c.save();
      },
      verify: (_) => verify(() => repo.assignTo('i1', null)).called(1),
    );
  });

  group('mark resolved', () {
    blocTest<AdminIssueCubit, AdminIssueState>(
      'uploads picked photos then resolves with the note',
      setUp: () =>
          when(() => picker.pick(PhotoSource.camera))
              .thenAnswer((_) async => '/tmp/fix.jpg'),
      build: build,
      act: (c) async {
        await c.addPhoto(PhotoSource.camera, existingCount: 1);
        await c.resolve(_inProgress, ' Replaced capacitor ');
      },
      verify: (c) {
        expect(c.state.submit, AdminSubmitStatus.success);
        expect(c.state.photos, isEmpty);
        verifyInOrder([
          () => repo.addResolutionPhotos('i1', [
            '/tmp/fix.jpg',
          ], existingCount: 1),
          () => repo.updateStatus(
            'i1',
            from: IssueStatus.inProgress,
            to: IssueStatus.resolved,
            note: 'Replaced capacitor',
          ),
        ]);
      },
    );

    blocTest<AdminIssueCubit, AdminIssueState>(
      'requires a note',
      build: build,
      act: (c) => c.resolve(_inProgress, '   '),
      expect: () => [
        const AdminIssueState(
          submit: AdminSubmitStatus.failure,
          action: AdminAction.resolve,
          message: 'Describe what was done before resolving.',
        ),
      ],
    );

    blocTest<AdminIssueCubit, AdminIssueState>(
      'rejects issues that cannot move to resolved',
      build: build,
      act: (c) => c.resolve(_issue, 'Done'),
      expect: () => [
        const AdminIssueState(
          submit: AdminSubmitStatus.failure,
          action: AdminAction.resolve,
          message: 'A report cannot move from Reported to Resolved.',
        ),
      ],
    );

    blocTest<AdminIssueCubit, AdminIssueState>(
      'photo upload failure does not resolve',
      setUp: () => when(
        () => repo.addResolutionPhotos(
          any(),
          any(),
          existingCount: any(named: 'existingCount'),
        ),
      ).thenThrow(const NetworkFailure()),
      build: build,
      seed: () => const AdminIssueState(photos: ['/tmp/a.jpg']),
      act: (c) => c.resolve(_inProgress, 'Fixed'),
      verify: (c) {
        expect(c.state.submit, AdminSubmitStatus.failure);
        expect(c.state.photos, ['/tmp/a.jpg']);
        verifyNever(
          () => repo.updateStatus(
            any(),
            from: any(named: 'from'),
            to: any(named: 'to'),
            note: any(named: 'note'),
          ),
        );
      },
    );

    blocTest<AdminIssueCubit, AdminIssueState>(
      'cannot exceed the photo limit',
      build: build,
      seed: () => const AdminIssueState(photos: ['/a', '/b']),
      act: (c) => c.addPhoto(PhotoSource.gallery, existingCount: 1),
      expect: () => [
        const AdminIssueState(
          photos: ['/a', '/b'],
          submit: AdminSubmitStatus.failure,
          action: AdminAction.photo,
          message: 'You can attach up to 3 photos.',
        ),
      ],
      verify: (_) => verifyNever(() => picker.pick(any())),
    );

    blocTest<AdminIssueCubit, AdminIssueState>(
      'picker validation failure is shown',
      setUp: () => when(() => picker.pick(any())).thenThrow(
        const ValidationFailure('That photo is too large (max 5 MB).'),
      ),
      build: build,
      act: (c) => c.addPhoto(PhotoSource.gallery),
      expect: () => [
        const AdminIssueState(
          submit: AdminSubmitStatus.failure,
          action: AdminAction.photo,
          message: 'That photo is too large (max 5 MB).',
        ),
      ],
    );

    blocTest<AdminIssueCubit, AdminIssueState>(
      'removePhoto drops a pending photo',
      build: build,
      seed: () => const AdminIssueState(photos: ['/a', '/b']),
      act: (c) => c.removePhoto(0),
      expect: () => [
        const AdminIssueState(photos: ['/b']),
      ],
    );
  });

  blocTest<AdminIssueCubit, AdminIssueState>(
    'messageShown clears the message',
    build: build,
    seed: () => const AdminIssueState(
      submit: AdminSubmitStatus.failure,
      action: AdminAction.save,
      message: 'x',
    ),
    act: (c) => c.messageShown(),
    expect: () => [
      const AdminIssueState(
        submit: AdminSubmitStatus.failure,
        action: AdminAction.save,
      ),
    ],
  );
}

const _assigned = Issue(
  id: 'i1',
  campusId: 'adit-main',
  title: 'Broken fan',
  description: 'The fan in room 101 does not spin.',
  category: IssueCategory.electrical,
  buildingId: 'a-block',
  locationDetail: 'Room 101',
  reporterId: 'u1',
  status: IssueStatus.inProgress,
  priority: IssuePriority.medium,
  assignedTo: 's1',
);
