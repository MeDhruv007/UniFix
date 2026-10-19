import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:fixmycampus/core/errors/failures.dart';
import 'package:fixmycampus/core/utils/photo_picker.dart';
import 'package:fixmycampus/features/reports/domain/entities/issue.dart';
import 'package:fixmycampus/features/reports/domain/entities/issue_enums.dart';
import 'package:fixmycampus/features/reports/domain/repositories/issue_repository.dart';
import 'package:fixmycampus/features/reports/presentation/bloc/issue_form_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockIssueRepository extends Mock implements IssueRepository {}

class _MockPhotoPicker extends Mock implements PhotoPicker {}

const _created = Issue(
  id: 'i1',
  campusId: 'adit-main',
  title: 'Leaking tap',
  description: 'Tap in washroom leaks all day.',
  category: IssueCategory.plumbing,
  buildingId: 'library',
  locationDetail: 'Ground floor washroom',
  reporterId: 'u1',
  status: IssueStatus.reported,
  priority: IssuePriority.medium,
  photoPaths: ['campuses/adit-main/issues/i1/report/a.jpg'],
);

const _ready = IssueFormState(
  category: IssueCategory.plumbing,
  buildingId: 'library',
  photos: ['/tmp/a.jpg'],
);

Future<void> _submit(IssueFormCubit c) => c.submit(
  title: 'Leaking tap',
  description: 'Tap in washroom leaks all day.',
  locationDetail: 'Ground floor washroom',
);

void main() {
  late _MockIssueRepository repo;
  late _MockPhotoPicker picker;

  setUpAll(() {
    registerFallbackValue(PhotoSource.camera);
    registerFallbackValue(
      const NewIssueInput(
        title: '',
        description: '',
        category: IssueCategory.other,
        buildingId: '',
        locationDetail: '',
      ),
    );
  });

  setUp(() {
    repo = _MockIssueRepository();
    picker = _MockPhotoPicker();
  });

  IssueFormCubit build() =>
      IssueFormCubit(repository: repo, photoPicker: picker);

  group('selections', () {
    blocTest<IssueFormCubit, IssueFormState>(
      'category and building changes are stored',
      build: build,
      act: (c) => c
        ..categoryChanged(IssueCategory.safety)
        ..buildingChanged('hostel'),
      expect: () => const [
        IssueFormState(category: IssueCategory.safety),
        IssueFormState(category: IssueCategory.safety, buildingId: 'hostel'),
      ],
    );
  });

  group('photos', () {
    blocTest<IssueFormCubit, IssueFormState>(
      'picked photo is appended and clears any message',
      setUp: () =>
          when(() => picker.pick(any())).thenAnswer((_) async => '/tmp/b.jpg'),
      build: build,
      seed: () => const IssueFormState(photos: ['/tmp/a.jpg'], message: 'old'),
      act: (c) => c.addPhoto(PhotoSource.gallery),
      expect: () => const [
        IssueFormState(photos: ['/tmp/a.jpg', '/tmp/b.jpg']),
      ],
      verify: (_) => verify(() => picker.pick(PhotoSource.gallery)).called(1),
    );

    blocTest<IssueFormCubit, IssueFormState>(
      'cancelled picker (null) changes nothing',
      setUp: () => when(() => picker.pick(any())).thenAnswer((_) async => null),
      build: build,
      act: (c) => c.addPhoto(PhotoSource.camera),
      expect: () => const <IssueFormState>[],
    );

    blocTest<IssueFormCubit, IssueFormState>(
      'picker ValidationFailure surfaces its message',
      setUp: () => when(() => picker.pick(any())).thenThrow(
        const ValidationFailure('That photo is too large (max 5 MB).'),
      ),
      build: build,
      seed: () => const IssueFormState(photos: ['/tmp/a.jpg']),
      act: (c) => c.addPhoto(PhotoSource.camera),
      expect: () => const [
        IssueFormState(
          photos: ['/tmp/a.jpg'],
          message: 'That photo is too large (max 5 MB).',
        ),
      ],
    );

    blocTest<IssueFormCubit, IssueFormState>(
      'unexpected picker error is mapped to a user-safe message',
      setUp: () =>
          when(() => picker.pick(any())).thenThrow(StateError('platform boom')),
      build: build,
      act: (c) => c.addPhoto(PhotoSource.camera),
      expect: () => const [
        IssueFormState(message: 'Something went wrong. Please try again.'),
      ],
    );

    blocTest<IssueFormCubit, IssueFormState>(
      'does not open the picker once 3 photos are attached',
      build: build,
      seed: () => const IssueFormState(photos: ['/a.jpg', '/b.jpg', '/c.jpg']),
      act: (c) => c.addPhoto(PhotoSource.camera),
      expect: () => const <IssueFormState>[],
      verify: (c) {
        expect(c.state.canAddPhoto, isFalse);
        verifyNever(() => picker.pick(any()));
      },
    );

    blocTest<IssueFormCubit, IssueFormState>(
      'does not open the picker while submitting',
      build: build,
      seed: () => const IssueFormState(status: IssueFormStatus.submitting),
      act: (c) => c.addPhoto(PhotoSource.camera),
      expect: () => const <IssueFormState>[],
      verify: (_) => verifyNever(() => picker.pick(any())),
    );

    test('concurrent picks cannot exceed the 3-photo limit', () async {
      final first = Completer<String?>();
      final second = Completer<String?>();
      final answers = [first, second];
      when(() => picker.pick(any()))
          .thenAnswer((_) => answers.removeAt(0).future);

      final cubit = build()
        ..emit(const IssueFormState(photos: ['/a.jpg', '/b.jpg']));
      final p1 = cubit.addPhoto(PhotoSource.camera);
      final p2 = cubit.addPhoto(PhotoSource.gallery);
      first.complete('/c.jpg');
      second.complete('/d.jpg');
      await Future.wait([p1, p2]);

      expect(cubit.state.photos, ['/a.jpg', '/b.jpg', '/c.jpg']);
      await cubit.close();
    });

    test('closing while the picker is open does not throw', () async {
      final pick = Completer<String?>();
      when(() => picker.pick(any())).thenAnswer((_) => pick.future);
      final cubit = build();
      final pending = cubit.addPhoto(PhotoSource.camera);
      await cubit.close();
      pick.complete('/a.jpg');
      await expectLater(pending, completes);
    });

    blocTest<IssueFormCubit, IssueFormState>(
      'removePhoto drops only that path',
      build: build,
      seed: () => const IssueFormState(photos: ['/a.jpg', '/b.jpg']),
      act: (c) => c.removePhoto('/a.jpg'),
      expect: () => const [
        IssueFormState(photos: ['/b.jpg']),
      ],
    );

    blocTest<IssueFormCubit, IssueFormState>(
      'messageShown clears the message',
      build: build,
      seed: () => const IssueFormState(message: 'hello'),
      act: (c) => c.messageShown(),
      expect: () => const [IssueFormState()],
    );
  });

  group('submit', () {
    blocTest<IssueFormCubit, IssueFormState>(
      'requires a category',
      build: build,
      seed: () => const IssueFormState(buildingId: 'library'),
      act: _submit,
      expect: () => const [
        IssueFormState(
          buildingId: 'library',
          status: IssueFormStatus.failure,
          message: 'Choose a category and a building.',
        ),
      ],
      verify: (_) => verifyNever(() => repo.createIssue(any())),
    );

    blocTest<IssueFormCubit, IssueFormState>(
      'requires a building',
      build: build,
      seed: () => const IssueFormState(category: IssueCategory.it),
      act: _submit,
      expect: () => const [
        IssueFormState(
          category: IssueCategory.it,
          status: IssueFormStatus.failure,
          message: 'Choose a category and a building.',
        ),
      ],
      verify: (_) => verifyNever(() => repo.createIssue(any())),
    );

    blocTest<IssueFormCubit, IssueFormState>(
      'success: submitting then success with the created issue',
      setUp: () =>
          when(() => repo.createIssue(any())).thenAnswer((_) async => _created),
      build: build,
      seed: () => _ready,
      act: _submit,
      expect: () => const [
        IssueFormState(
          category: IssueCategory.plumbing,
          buildingId: 'library',
          photos: ['/tmp/a.jpg'],
          status: IssueFormStatus.submitting,
        ),
        IssueFormState(
          category: IssueCategory.plumbing,
          buildingId: 'library',
          photos: ['/tmp/a.jpg'],
          status: IssueFormStatus.success,
          created: _created,
        ),
      ],
      verify: (_) => verify(
        () => repo.createIssue(
          const NewIssueInput(
            title: 'Leaking tap',
            description: 'Tap in washroom leaks all day.',
            category: IssueCategory.plumbing,
            buildingId: 'library',
            locationDetail: 'Ground floor washroom',
            localPhotoPaths: ['/tmp/a.jpg'],
          ),
        ),
      ).called(1),
    );

    blocTest<IssueFormCubit, IssueFormState>(
      'failure keeps selections and photos, with the failure message',
      setUp: () =>
          when(() => repo.createIssue(any())).thenThrow(const UploadFailure()),
      build: build,
      seed: () => _ready,
      act: _submit,
      expect: () => const [
        IssueFormState(
          category: IssueCategory.plumbing,
          buildingId: 'library',
          photos: ['/tmp/a.jpg'],
          status: IssueFormStatus.submitting,
        ),
        IssueFormState(
          category: IssueCategory.plumbing,
          buildingId: 'library',
          photos: ['/tmp/a.jpg'],
          status: IssueFormStatus.failure,
          message: 'Photo upload failed. Please try again.',
          submitProblem: IssueSubmitProblem.upload,
        ),
      ],
    );

    blocTest<IssueFormCubit, IssueFormState>(
      'offline failure flags the offline problem; retry clears it',
      setUp: () =>
          when(() => repo.createIssue(any())).thenThrow(const NetworkFailure()),
      build: build,
      seed: () => _ready.copyWith(
        status: IssueFormStatus.failure,
        submitProblem: () => IssueSubmitProblem.upload,
      ),
      act: _submit,
      expect: () => [
        _ready.copyWith(status: IssueFormStatus.submitting),
        _ready.copyWith(
          status: IssueFormStatus.failure,
          message: () => const NetworkFailure().message,
          submitProblem: () => IssueSubmitProblem.offline,
        ),
      ],
    );

    blocTest<IssueFormCubit, IssueFormState>(
      'raw error is mapped to a user-safe message',
      setUp: () =>
          when(() => repo.createIssue(any()))
              .thenThrow(Exception('firestore internals')),
      build: build,
      seed: () => _ready,
      act: _submit,
      skip: 1,
      expect: () => [
        _ready.copyWith(
          status: IssueFormStatus.failure,
          message: () => 'Something went wrong. Please try again.',
        ),
      ],
    );

    blocTest<IssueFormCubit, IssueFormState>(
      'ignored while already submitting',
      build: build,
      seed: () => _ready.copyWith(status: IssueFormStatus.submitting),
      act: _submit,
      expect: () => const <IssueFormState>[],
      verify: (_) => verifyNever(() => repo.createIssue(any())),
    );

    test('closing during submit does not throw', () async {
      final result = Completer<Issue>();
      when(() => repo.createIssue(any())).thenAnswer((_) => result.future);
      final cubit = build()..emit(_ready);
      final pending = _submit(cubit);
      await cubit.close();
      result.complete(_created);
      await expectLater(pending, completes);
    });
  });
}
