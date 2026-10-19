import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:fixmycampus/core/errors/failures.dart';
import 'package:fixmycampus/features/feedback/domain/entities/issue_feedback.dart';
import 'package:fixmycampus/features/feedback/domain/repositories/feedback_repository.dart';
import 'package:fixmycampus/features/feedback/presentation/bloc/feedback_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockFeedbackRepository extends Mock implements FeedbackRepository {}

const _issueId = 'i1';
const _fixed = IssueFeedback(reporterId: 'u1', stillExists: false);
const _notFixed = IssueFeedback(
  reporterId: 'u1',
  stillExists: true,
  comment: 'Still leaking',
);

void main() {
  late _MockFeedbackRepository repo;

  setUp(() => repo = _MockFeedbackRepository());

  FeedbackCubit build() => FeedbackCubit(repository: repo, issueId: _issueId);

  void stubSubmit(Future<void> Function() answer) => when(
    () => repo.submitFeedback(
      any(),
      stillExists: any(named: 'stillExists'),
      comment: any(named: 'comment'),
    ),
  ).thenAnswer((_) => answer());

  test('starts loading', () {
    expect(build().state, const FeedbackState());
  });

  group('start', () {
    blocTest<FeedbackCubit, FeedbackState>(
      'loads empty then existing feedback from the stream',
      setUp: () =>
          when(() => repo.watchMyFeedback(_issueId))
              .thenAnswer((_) => Stream.fromIterable([null, _notFixed])),
      build: build,
      act: (c) => c.start(),
      expect: () => const [
        // start() always resets to loading first.
        FeedbackState(),
        FeedbackState(status: FeedbackStatus.loaded),
        FeedbackState(status: FeedbackStatus.loaded, feedback: _notFixed),
      ],
    );

    blocTest<FeedbackCubit, FeedbackState>(
      'stream error becomes a failure state',
      setUp: () =>
          when(() => repo.watchMyFeedback(_issueId))
              .thenAnswer((_) => Stream.error(const NetworkFailure())),
      build: build,
      act: (c) => c.start(),
      expect: () => const [
        // start() always resets to loading first.
        FeedbackState(),
        FeedbackState(
          status: FeedbackStatus.failure,
          message:
              'You appear to be offline. Check your connection and try again.',
        ),
      ],
    );
  });

  group('submit', () {
    blocTest<FeedbackCubit, FeedbackState>(
      'emits submitting then idle and forwards the answer',
      setUp: () => stubSubmit(() async {}),
      build: build,
      seed: () => const FeedbackState(status: FeedbackStatus.loaded),
      act: (c) => c.submit(stillExists: false, comment: 'Thanks!'),
      expect: () => const [
        FeedbackState(
          status: FeedbackStatus.loaded,
          submitStatus: FeedbackSubmitStatus.submitting,
        ),
        FeedbackState(status: FeedbackStatus.loaded),
      ],
      verify: (_) => verify(
        () => repo.submitFeedback(
          _issueId,
          stillExists: false,
          comment: 'Thanks!',
        ),
      ).called(1),
    );

    blocTest<FeedbackCubit, FeedbackState>(
      'live stream shows the stored feedback after submitting',
      setUp: () {
        final controller = StreamController<IssueFeedback?>();
        addTearDown(controller.close);
        when(() => repo.watchMyFeedback(_issueId))
            .thenAnswer((_) => controller.stream);
        stubSubmit(() async => controller.add(_fixed));
        controller.add(null);
      },
      build: build,
      act: (c) async {
        c.start();
        await Future<void>.delayed(Duration.zero);
        await c.submit(stillExists: false);
        await Future<void>.delayed(Duration.zero);
      },
      verify: (c) => expect(
        c.state,
        const FeedbackState(status: FeedbackStatus.loaded, feedback: _fixed),
      ),
    );

    blocTest<FeedbackCubit, FeedbackState>(
      'emits a submit failure with a user-safe message',
      setUp: () => stubSubmit(() async => throw const PermissionFailure()),
      build: build,
      seed: () => const FeedbackState(status: FeedbackStatus.loaded),
      act: (c) => c.submit(stillExists: true),
      expect: () => const [
        FeedbackState(
          status: FeedbackStatus.loaded,
          submitStatus: FeedbackSubmitStatus.submitting,
        ),
        FeedbackState(
          status: FeedbackStatus.loaded,
          submitStatus: FeedbackSubmitStatus.failure,
          message: 'You do not have permission to do that.',
        ),
      ],
    );

    blocTest<FeedbackCubit, FeedbackState>(
      'does nothing when feedback already exists',
      build: build,
      seed: () =>
          const FeedbackState(status: FeedbackStatus.loaded, feedback: _fixed),
      act: (c) => c.submit(stillExists: true),
      expect: () => const <FeedbackState>[],
      verify: (_) => verifyNever(
        () => repo.submitFeedback(
          any(),
          stillExists: any(named: 'stillExists'),
          comment: any(named: 'comment'),
        ),
      ),
    );
  });
}
