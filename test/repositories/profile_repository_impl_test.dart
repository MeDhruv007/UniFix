import 'package:fixmycampus/core/errors/failures.dart';
import 'package:fixmycampus/core/network/api_client.dart';
import 'package:fixmycampus/core/network/token_store.dart';
import 'package:fixmycampus/features/auth/data/datasources/auth_api_data_source.dart';
import 'package:fixmycampus/features/auth/data/repositories/auth_api_repository.dart';
import 'package:fixmycampus/features/auth/domain/entities/app_user.dart';
import 'package:fixmycampus/features/profile/data/profile_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/api_fixtures.dart';
import '../helpers/fake_http_adapter.dart';
import '../helpers/fake_secure_storage.dart';

Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  late FakeHttpAdapter adapter;
  late AuthApiRepository session;
  late ProfileRepositoryImpl repo;

  setUp(() async {
    adapter = FakeHttpAdapter();
    final storage = FakeSecureStorage();
    final tokens = TokenStore(storage);
    final client = ApiClient(tokens: tokens, dio: fakeDio(adapter));
    final api = AuthApiDataSource(dio: client.dio);
    session = AuthApiRepository(
      api: api,
      tokens: tokens,
      client: client,
      storage: storage,
    );
    addTearDown(session.dispose);
    repo = ProfileRepositoryImpl(api: api, session: session);

    adapter.reply('POST', '/auth/login', {'token': 'jwt', 'user': userJson()});
    await session.signIn(email: 'asha@adit.ac.in', password: 'secret123');
    adapter.requests.clear();
  });

  int patchCount() => adapter.requests.where((r) => r.method == 'PATCH').length;

  group('validation', () {
    test('rejects a too-short name without calling the API', () async {
      await expectLater(
        repo.updateProfile(displayName: ' A '),
        throwsA(isA<ValidationFailure>()),
      );
      expect(patchCount(), 0);
    });

    test('rejects a name over 60 characters', () async {
      await expectLater(
        repo.updateProfile(displayName: 'x' * 61),
        throwsA(isA<ValidationFailure>()),
      );
      expect(patchCount(), 0);
    });

    test('rejects a department over 60 characters', () async {
      await expectLater(
        repo.updateProfile(displayName: 'Asha', department: 'd' * 61),
        throwsA(
          const ValidationFailure('Department must be at most 60 characters.'),
        ),
      );
      expect(patchCount(), 0);
    });
  });

  group('PATCH /me', () {
    setUp(
      () => adapter.reply(
        'PATCH',
        '/me',
        userJson(displayName: 'Asha P', department: 'Mechanical'),
      ),
    );

    test('sends trimmed fields with the bearer token', () async {
      await repo.updateProfile(
        displayName: '  Asha P ',
        department: ' Mechanical ',
      );

      expect(adapter.last.path, '/me');
      expect(adapter.last.data, {
        'displayName': 'Asha P',
        'department': 'Mechanical',
      });
      expect(adapter.last.headers['Authorization'], 'Bearer jwt');
    });

    test('60-character limits are allowed', () async {
      await repo.updateProfile(displayName: 'n' * 60, department: 'd' * 60);

      expect(patchCount(), 1);
    });

    for (final dept in [null, '', '   ']) {
      test('empty department ${dept == null ? 'null' : '"$dept"'} is sent '
          'as "" to clear it', () async {
        await repo.updateProfile(displayName: 'Asha', department: dept);

        expect(adapter.last.data, {'displayName': 'Asha', 'department': ''});
      });
    }

    test('publishes the updated user to the session', () async {
      final events = <AppUser?>[];
      final sub = session.watchCurrentUser().listen(events.add);
      addTearDown(sub.cancel);
      await _settle();

      await repo.updateProfile(displayName: 'Asha P', department: 'Mechanical');
      await _settle();

      expect(events.last?.displayName, 'Asha P');
      expect(events.last?.department, 'Mechanical');
      expect(session.currentUser?.displayName, 'Asha P');
    });
  });

  group('errors', () {
    test('server validation message is shown', () async {
      adapter.fail(
        'PATCH',
        '/me',
        400,
        code: 'VALIDATION',
        message: 'Display name is too long.',
      );

      await expectLater(
        repo.updateProfile(displayName: 'Asha'),
        throwsA(const ValidationFailure('Display name is too long.')),
      );
      expect(session.currentUser?.displayName, 'Asha Patel');
    });

    test('offline is a NetworkFailure', () async {
      adapter.offline('PATCH', '/me');

      await expectLater(
        repo.updateProfile(displayName: 'Asha'),
        throwsA(isA<NetworkFailure>()),
      );
    });
  });
}
