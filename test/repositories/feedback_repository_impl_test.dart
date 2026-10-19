import 'package:fixmycampus/core/errors/failures.dart';
import 'package:fixmycampus/features/feedback/data/feedback_repository_impl.dart';
import 'package:fixmycampus/features/feedback/domain/entities/issue_feedback.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/api_fixtures.dart';
import '../helpers/fake_http_adapter.dart';

const _mePath = '/issues/i1/feedback/me';
const _postPath = '/issues/i1/feedback';

Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  late FakeHttpAdapter adapter;
  late FeedbackRepositoryImpl repo;

  setUp(() {
    adapter = FakeHttpAdapter();
    repo = FeedbackRepositoryImpl(dio: fakeDio(adapter));
  });

  List<Object?> record(String issueId) {
    final events = <Object?>[];
    final sub = repo
        .watchMyFeedback(issueId)
        .listen(events.add, onError: events.add);
    addTearDown(sub.cancel);
    return events;
  }

  group('watchMyFeedback', () {
    test('404 means no feedback yet', () async {
      adapter.fail('GET', _mePath, 404, code: 'NOT_FOUND', message: 'None');

      expect(await repo.watchMyFeedback('i1').first, isNull);
      expect(adapter.last.path, _mePath);
    });

    test('maps existing feedback with a local timestamp', () async {
      adapter.reply(
        'GET',
        _mePath,
        feedbackJson(stillExists: true, comment: 'Still leaking'),
      );

      final feedback = await repo.watchMyFeedback('i1').first;

      expect(
        feedback,
        IssueFeedback(
          reporterId: 'u1',
          stillExists: true,
          comment: 'Still leaking',
          createdAt: DateTime.utc(2026, 10, 16, 8).toLocal(),
        ),
      );
      expect(feedback!.createdAt!.isUtc, isFalse);
    });

    test('other errors are mapped failures', () async {
      adapter.fail(
        'GET',
        _mePath,
        403,
        code: 'FORBIDDEN',
        message: 'Only the reporter can see this.',
      );

      await expectLater(
        repo.watchMyFeedback('i1'),
        emitsError(const PermissionFailure('Only the reporter can see this.')),
      );
    });

    test('offline is a NetworkFailure', () async {
      adapter.offline('GET', _mePath);

      await expectLater(
        repo.watchMyFeedback('i1'),
        emitsError(isA<NetworkFailure>()),
      );
    });
  });

  group('submitFeedback', () {
    test('pushes the stored feedback to the open stream', () async {
      adapter
        ..fail('GET', _mePath, 404, code: 'NOT_FOUND', message: 'None')
        ..reply(
          'POST',
          _postPath,
          feedbackJson(stillExists: false),
          status: 201,
        );
      final events = record('i1');
      await _settle();

      await repo.submitFeedback('i1', stillExists: false);
      await _settle();

      expect(events, [
        null,
        isA<IssueFeedback>()
            .having((f) => f.stillExists, 'stillExists', false)
            .having((f) => f.comment, 'comment', isNull),
      ]);
    });

    test('does not push to streams of other issues', () async {
      adapter
        ..fail('GET', '/issues/i2/feedback/me', 404, code: 'NOT_FOUND')
        ..reply('POST', _postPath, feedbackJson(), status: 201);
      final other = record('i2');
      await _settle();

      await repo.submitFeedback('i1', stillExists: false);
      await _settle();

      expect(other, [null]);
    });

    test('sends a trimmed comment', () async {
      adapter.reply('POST', _postPath, feedbackJson(), status: 201);

      await repo.submitFeedback(
        'i1',
        stillExists: true,
        comment: '  Still leaking  ',
      );

      expect(adapter.last.method, 'POST');
      expect(adapter.last.data, {
        'stillExists': true,
        'comment': 'Still leaking',
      });
    });

    for (final comment in [null, '', '   ']) {
      test('empty comment ${comment == null ? 'null' : '"$comment"'} is '
          'sent as null', () async {
        adapter.reply('POST', _postPath, feedbackJson(), status: 201);

        await repo.submitFeedback('i1', stillExists: false, comment: comment);

        expect(adapter.last.data, {'stillExists': false, 'comment': null});
      });
    }

    test('works without an open stream', () async {
      adapter.reply('POST', _postPath, feedbackJson(), status: 201);

      await expectLater(
        repo.submitFeedback('i1', stillExists: false),
        completes,
      );
    });

    test('repeat feedback (409) is a ConflictFailure', () async {
      adapter.fail(
        'POST',
        _postPath,
        409,
        code: 'CONFLICT',
        message: 'Feedback was already given.',
      );

      await expectLater(
        repo.submitFeedback('i1', stillExists: true),
        throwsA(const ConflictFailure('Feedback was already given.')),
      );
    });

    test('not resolved yet (422/400) is a ValidationFailure', () async {
      adapter.fail(
        'POST',
        _postPath,
        400,
        code: 'VALIDATION',
        message: 'Feedback is only possible on resolved issues.',
      );

      await expectLater(
        repo.submitFeedback('i1', stillExists: true),
        throwsA(isA<ValidationFailure>()),
      );
    });
  });
}
