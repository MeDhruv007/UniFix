import 'dart:async';

import 'package:dio/dio.dart';
import 'package:fake_async/fake_async.dart';
import 'package:fixmycampus/core/config/api_config.dart';
import 'package:fixmycampus/core/errors/failures.dart';
import 'package:fixmycampus/core/network/api_client.dart';
import 'package:fixmycampus/core/network/token_store.dart';
import 'package:fixmycampus/features/reports/data/datasources/issue_api_data_source.dart';
import 'package:fixmycampus/features/reports/data/models/issue_model.dart';
import 'package:fixmycampus/features/reports/data/repositories/issue_repository_impl.dart';
import 'package:fixmycampus/features/reports/domain/entities/issue.dart';
import 'package:fixmycampus/features/reports/domain/entities/issue_enums.dart';
import 'package:fixmycampus/features/reports/domain/repositories/issue_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/api_fixtures.dart';
import '../helpers/fake_http_adapter.dart';
import '../helpers/fake_secure_storage.dart';

class _MockIssueApi extends Mock implements IssueApiDataSource {}

const _interval = Duration(seconds: 15);

Issue _issue([String id = 'i1', String status = 'reported']) =>
    IssueModel.fromJson(issueJson(id: id, status: status));

DioException _offline() => DioException.connectionError(
  requestOptions: RequestOptions(path: '/issues'),
  reason: 'offline',
);

DioException _http(int status, String code, String message) {
  final req = RequestOptions(path: '/issues');
  return DioException.badResponse(
    statusCode: status,
    requestOptions: req,
    response: Response(
      requestOptions: req,
      statusCode: status,
      data: {
        'error': {'code': code, 'message': message},
      },
    ),
  );
}

NewIssueInput _input({int photos = 0}) => NewIssueInput(
  title: 'Fan not working',
  description: 'The ceiling fan does not start.',
  category: IssueCategory.electrical,
  buildingId: 'engineering-block',
  locationDetail: 'Room 204',
  localPhotoPaths: [for (var i = 0; i < photos; i++) '/tmp/p$i.jpg'],
);

void main() {
  late _MockIssueApi api;
  late TokenStore tokens;
  late ApiClient client;

  setUpAll(() {
    registerFallbackValue(const IssueFilter());
    registerFallbackValue(_input());
    registerFallbackValue(IssueStatus.reported);
    registerFallbackValue(IssuePriority.medium);
  });

  setUp(() {
    api = _MockIssueApi();
    tokens = TokenStore(FakeSecureStorage());
    client = ApiClient(tokens: tokens, dio: fakeDio(FakeHttpAdapter()));
  });

  IssueRepositoryImpl build() =>
      IssueRepositoryImpl(api: api, client: client, pollInterval: _interval);

  group('createIssue', () {
    test('rejects more than 3 photos without calling the API', () async {
      await expectLater(
        build().createIssue(_input(photos: 4)),
        throwsA(const ValidationFailure('You can attach up to 3 photos.')),
      );
      verifyNever(() => api.create(any()));
    });

    test('creates with up to 3 photos and returns the issue', () async {
      when(() => api.create(any())).thenAnswer((_) async => _issue('new'));

      final issue = await build().createIssue(_input(photos: 3));

      expect(issue.id, 'new');
      verify(() => api.create(_input(photos: 3))).called(1);
    });

    test('maps API errors to failures', () async {
      when(() => api.create(any()))
          .thenThrow(_http(400, 'VALIDATION', 'Bad image type'));

      await expectLater(
        build().createIssue(_input()),
        throwsA(const ValidationFailure('Bad image type')),
      );
    });
  });

  group('updateStatus', () {
    void stubStatus() => when(
      () => api.updateStatus(
        any(),
        from: any(named: 'from'),
        to: any(named: 'to'),
        note: any(named: 'note'),
      ),
    ).thenAnswer((_) async => _issue());

    test('rejects transitions outside the state machine', () async {
      await expectLater(
        build().updateStatus(
          'i1',
          from: IssueStatus.reported,
          to: IssueStatus.resolved,
          note: 'done',
        ),
        throwsA(
          const ValidationFailure(
            'A report cannot move from Reported to Resolved.',
          ),
        ),
      );
      verifyNoMoreInteractions(api);
    });

    for (final note in [null, '', '   ']) {
      test(
        'resolving requires a note (${note == null ? 'null' : '"$note"'})',
        () async {
          await expectLater(
            build().updateStatus(
              'i1',
              from: IssueStatus.inProgress,
              to: IssueStatus.resolved,
              note: note,
            ),
            throwsA(
              const ValidationFailure(
                'Add a resolution note before resolving.',
              ),
            ),
          );
          verifyNoMoreInteractions(api);
        },
      );
    }

    test('rejects notes over 500 characters', () async {
      await expectLater(
        build().updateStatus(
          'i1',
          from: IssueStatus.reported,
          to: IssueStatus.inProgress,
          note: 'x' * 501,
        ),
        throwsA(
          const ValidationFailure('Notes can be at most 500 characters.'),
        ),
      );
      verifyNoMoreInteractions(api);
    });

    test('sends a trimmed note; 500 characters is allowed', () async {
      stubStatus();
      final note = 'y' * 500;

      await build().updateStatus(
        'i1',
        from: IssueStatus.inProgress,
        to: IssueStatus.resolved,
        note: '  $note  ',
      );

      verify(
        () => api.updateStatus(
          'i1',
          from: IssueStatus.inProgress,
          to: IssueStatus.resolved,
          note: note,
        ),
      ).called(1);
    });

    test('a blank note on a non-resolve transition is sent as null', () async {
      stubStatus();

      await build().updateStatus(
        'i1',
        from: IssueStatus.reported,
        to: IssueStatus.inProgress,
        note: '  ',
      );

      verify(
        () => api.updateStatus(
          'i1',
          from: IssueStatus.reported,
          to: IssueStatus.inProgress,
        ),
      ).called(1);
    });

    test('maps a stale status (409) to ConflictFailure', () async {
      when(
        () => api.updateStatus(
          any(),
          from: any(named: 'from'),
          to: any(named: 'to'),
          note: any(named: 'note'),
        ),
      ).thenThrow(_http(409, 'CONFLICT', 'Status changed.'));

      await expectLater(
        build().updateStatus(
          'i1',
          from: IssueStatus.reported,
          to: IssueStatus.inProgress,
        ),
        throwsA(const ConflictFailure('Status changed.')),
      );
    });
  });

  group('updatePriority', () {
    test('same priority is a no-op', () async {
      await build().updatePriority(
        'i1',
        from: IssuePriority.high,
        to: IssuePriority.high,
      );
      verifyNoMoreInteractions(api);
    });

    test('changes priority through the API', () async {
      when(
        () => api.updatePriority(
          any(),
          from: any(named: 'from'),
          to: any(named: 'to'),
        ),
      ).thenAnswer((_) async => _issue());

      await build().updatePriority(
        'i1',
        from: IssuePriority.medium,
        to: IssuePriority.urgent,
      );

      verify(
        () => api.updatePriority(
          'i1',
          from: IssuePriority.medium,
          to: IssuePriority.urgent,
        ),
      ).called(1);
    });
  });

  group('addResolutionPhotos', () {
    test('no photos is a no-op', () async {
      await build().addResolutionPhotos('i1', const []);
      verifyNoMoreInteractions(api);
    });

    test('caps the total including existing photos', () async {
      await expectLater(
        build().addResolutionPhotos('i1', ['a', 'b'], existingCount: 2),
        throwsA(
          const ValidationFailure('You can attach up to 3 resolution photos.'),
        ),
      );
      await expectLater(
        build().addResolutionPhotos('i1', ['a', 'b', 'c', 'd']),
        throwsA(isA<ValidationFailure>()),
      );
      verifyNoMoreInteractions(api);
    });

    test('uploads when within the cap', () async {
      when(() => api.addResolutionPhotos(any(), any()))
          .thenAnswer((_) async => _issue());

      await build().addResolutionPhotos('i1', ['a', 'b'], existingCount: 1);

      verify(() => api.addResolutionPhotos('i1', ['a', 'b'])).called(1);
    });

    test('maps 413 to UploadFailure', () async {
      when(() => api.addResolutionPhotos(any(), any()))
          .thenThrow(_http(413, 'PAYLOAD_TOO_LARGE', 'Too big'));

      await expectLater(
        build().addResolutionPhotos('i1', ['a']),
        throwsA(isA<UploadFailure>()),
      );
    });
  });

  group('assignToMe', () {
    test('maps 403 to PermissionFailure', () async {
      when(() => api.assignToMe(any()))
          .thenThrow(_http(403, 'FORBIDDEN', 'Admins only.'));

      await expectLater(
        build().assignToMe('i1'),
        throwsA(const PermissionFailure('Admins only.')),
      );
    });
  });

  group('countIssues', () {
    setUp(
      () => when(() => api.stats(mine: any(named: 'mine'))).thenAnswer(
        (_) async => IssueStatsModel.fromJson({
          'reported': 4,
          'inProgress': 2,
          'resolved': 9,
          'reopened': 1,
          'total': 16,
        }),
      ),
    );

    test('reads "total" without a status', () async {
      expect(await build().countIssues(), 16);
    });

    test('reads the status key', () async {
      final repo = build();
      expect(await repo.countIssues(status: IssueStatus.reported), 4);
      expect(await repo.countIssues(status: IssueStatus.inProgress), 2);
      expect(await repo.countIssues(status: IssueStatus.resolved), 9);
      expect(await repo.countIssues(status: IssueStatus.reopened), 1);
    });

    test('missing keys count as zero', () async {
      when(() => api.stats(mine: any(named: 'mine')))
          .thenAnswer((_) async => IssueStatsModel.fromJson({'total': 3}));
      expect(await build().countIssues(status: IssueStatus.resolved), 0);
    });

    test('maps errors', () async {
      when(() => api.stats(mine: any(named: 'mine'))).thenThrow(_offline());
      await expectLater(build().countIssues(), throwsA(isA<NetworkFailure>()));
    });
  });

  group('photo', () {
    test('builds the API photo URL with auth headers', () async {
      await tokens.save('jwt');

      final ref = build().photo('issues/i1/report/p1.jpg');

      expect(ref.url, ApiConfig.photoUrl('issues/i1/report/p1.jpg'));
      expect(ref.url, '${ApiConfig.baseUrl}/photos/issues/i1/report/p1.jpg');
      expect(ref.headers, {'Authorization': 'Bearer jwt'});
    });

    test('has no headers when signed out', () {
      expect(build().photo('p.jpg').headers, isEmpty);
    });
  });

  group('watch streams (polling)', () {
    test('watchIssues forwards filter and limit and emits items', () {
      fakeAsync((async) {
        const filter = IssueFilter(
          status: IssueStatus.reported,
          reporterId: 'u1',
        );
        when(() => api.list(any(), limit: any(named: 'limit')))
            .thenAnswer((_) async => (items: [_issue('a')], total: 1));
        final values = <List<Issue>>[];

        build().watchIssues(filter: filter, limit: 5).listen(values.add);
        async.flushMicrotasks();

        expect(values.single.single.id, 'a');
        verify(() => api.list(filter, limit: 5)).called(1);
      });
    });

    test('watchUpdates polls /updates', () {
      fakeAsync((async) {
        when(() => api.updates('i1')).thenAnswer((_) async => const []);
        final values = <Object>[];

        build().watchUpdates('i1').listen(values.add);
        async.flushMicrotasks();

        expect(values, [isEmpty]);
      });
    });

    test('does not fetch until listened to', () {
      fakeAsync((async) {
        build().watchIssue('i1');
        async.elapse(_interval * 3);
        verifyNever(() => api.get(any()));
      });
    });

    test('emits on listen, re-polls every interval, stops on cancel', () {
      fakeAsync((async) {
        when(() => api.get('i1')).thenAnswer((_) async => _issue());
        final values = <Issue>[];

        final sub = build().watchIssue('i1').listen(values.add);
        async.flushMicrotasks();
        expect(values, hasLength(1));

        async.elapse(_interval - const Duration(seconds: 1));
        expect(values, hasLength(1));
        async.elapse(const Duration(seconds: 1));
        expect(values, hasLength(2));
        async.elapse(_interval * 2);
        expect(values, hasLength(4));

        sub.cancel();
        async.elapse(_interval * 3);
        expect(values, hasLength(4));
        verify(() => api.get('i1')).called(4);
        expect(async.periodicTimerCount, 0);
      });
    });

    // Real time: cancel() resolves through root-zone futures that
    // fake_async cannot flush.
    test('cancel completes and a local write no longer re-fetches', () async {
      final repo = IssueRepositoryImpl(
        api: api,
        client: client,
        pollInterval: const Duration(milliseconds: 5),
      );
      when(() => api.get('i1')).thenAnswer((_) async => _issue());
      when(() => api.assignToMe('i1')).thenAnswer((_) async => _issue());

      final sub = repo.watchIssue('i1').listen((_) {});
      await Future<void>.delayed(const Duration(milliseconds: 30));
      await sub.cancel().timeout(const Duration(seconds: 2));
      clearInteractions(api);

      await repo.assignToMe('i1');
      await Future<void>.delayed(const Duration(milliseconds: 30));

      verifyNever(() => api.get(any()));
    });

    test('re-fetches right after a successful local write', () {
      fakeAsync((async) {
        final repo = build();
        var status = 'reported';
        when(() => api.get('i1')).thenAnswer((_) async => _issue('i1', status));
        when(() => api.assignToMe('i1')).thenAnswer((_) async {
          status = 'inProgress';
          return _issue('i1', status);
        });
        final values = <Issue>[];

        repo.watchIssue('i1').listen(values.add);
        async.flushMicrotasks();
        repo.assignToMe('i1');
        async.flushMicrotasks();

        expect(values.map((i) => i.status), [
          IssueStatus.reported,
          IssueStatus.inProgress,
        ]);
      });
    });

    test('a failed write does not trigger a re-fetch', () {
      fakeAsync((async) {
        final repo = build();
        when(() => api.get('i1')).thenAnswer((_) async => _issue());
        when(() => api.assignToMe('i1'))
            .thenThrow(_http(409, 'CONFLICT', 'Already assigned'));
        final values = <Issue>[];
        Object? writeError;

        repo.watchIssue('i1').listen(values.add);
        async.flushMicrotasks();
        repo.assignToMe('i1').catchError((Object e) => writeError = e);
        async.flushMicrotasks();

        expect(writeError, const ConflictFailure('Already assigned'));
        expect(values, hasLength(1));
        verify(() => api.get('i1')).called(1);
      });
    });

    test('surfaces a network error before the first value', () {
      fakeAsync((async) {
        var offline = true;
        when(() => api.get('i1')).thenAnswer((_) async {
          if (offline) throw _offline();
          return _issue();
        });
        final values = <Issue>[];
        final errors = <Object>[];

        build().watchIssue('i1').listen(values.add, onError: errors.add);
        async.flushMicrotasks();

        expect(values, isEmpty);
        expect(errors.single, isA<NetworkFailure>());

        // Keeps polling and recovers.
        offline = false;
        async.elapse(_interval);
        expect(values, hasLength(1));
      });
    });

    test('swallows network errors once a value was delivered', () {
      fakeAsync((async) {
        var offline = false;
        when(() => api.get('i1')).thenAnswer((_) async {
          if (offline) throw _offline();
          return _issue();
        });
        final values = <Issue>[];
        final errors = <Object>[];

        build().watchIssue('i1').listen(values.add, onError: errors.add);
        async.flushMicrotasks();
        offline = true;
        async.elapse(_interval * 2);

        expect(values, hasLength(1));
        expect(errors, isEmpty);

        offline = false;
        async.elapse(_interval);
        expect(values, hasLength(2));
      });
    });

    test('surfaces non-network failures even after a value', () {
      fakeAsync((async) {
        var gone = false;
        when(() => api.get('i1')).thenAnswer((_) async {
          if (gone) throw _http(404, 'NOT_FOUND', 'Issue not found.');
          return _issue();
        });
        final errors = <Object>[];

        build().watchIssue('i1').listen((_) {}, onError: errors.add);
        async.flushMicrotasks();
        gone = true;
        async.elapse(_interval);

        expect(errors, [const NotFoundFailure('Issue not found.')]);
      });
    });

    test('does not overlap fetches while one is in flight', () {
      fakeAsync((async) {
        final pending = Completer<Issue>();
        when(() => api.get('i1')).thenAnswer((_) => pending.future);
        final values = <Issue>[];

        build().watchIssue('i1').listen(values.add);
        async.elapse(_interval * 3);
        verify(() => api.get('i1')).called(1);

        pending.complete(_issue());
        async.flushMicrotasks();
        expect(values, hasLength(1));
      });
    });

    test('a value arriving after cancel is dropped', () {
      fakeAsync((async) {
        final pending = Completer<Issue>();
        when(() => api.get('i1')).thenAnswer((_) => pending.future);
        final values = <Issue>[];

        final sub = build().watchIssue('i1').listen(values.add);
        async.flushMicrotasks();
        sub.cancel();
        pending.complete(_issue());
        async.flushMicrotasks();

        expect(values, isEmpty);
      });
    });
  });
}
