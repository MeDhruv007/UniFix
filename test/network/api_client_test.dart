import 'package:dio/dio.dart';
import 'package:fixmycampus/core/network/api_client.dart';
import 'package:fixmycampus/core/network/token_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/fake_http_adapter.dart';
import '../helpers/fake_secure_storage.dart';

void main() {
  late FakeHttpAdapter adapter;
  late FakeSecureStorage storage;
  late TokenStore tokens;
  late ApiClient client;
  late int unauthorizedCount;

  setUp(() {
    adapter = FakeHttpAdapter();
    storage = FakeSecureStorage();
    tokens = TokenStore(storage);
    client = ApiClient(tokens: tokens, dio: fakeDio(adapter));
    unauthorizedCount = 0;
    final sub = client.unauthorized.listen((_) => unauthorizedCount++);
    addTearDown(sub.cancel);
  });

  /// Lets the broadcast `unauthorized` stream deliver.
  Future<void> flush() => Future<void>.delayed(Duration.zero);

  group('bearer header', () {
    test('is added when a token is stored', () async {
      await tokens.save('jwt-1');
      adapter.reply('GET', '/me', {'id': 'u1'});

      await client.dio.get<void>('/me');

      expect(adapter.last.headers['Authorization'], 'Bearer jwt-1');
    });

    test('is omitted without a token', () async {
      adapter.reply('POST', '/auth/login', {'token': 't'});

      await client.dio.post<void>('/auth/login');

      expect(adapter.last.headers.containsKey('Authorization'), isFalse);
    });

    test('follows the latest token', () async {
      adapter.reply('GET', '/me', {});
      await tokens.save('old');
      await client.dio.get<void>('/me');
      await tokens.save('new');
      await client.dio.get<void>('/me');

      expect(adapter.requests.map((r) => r.headers['Authorization']), [
        'Bearer old',
        'Bearer new',
      ]);
    });

    test('authHeaders mirrors the stored token', () async {
      expect(client.authHeaders, isEmpty);
      await tokens.save('jwt-2');
      expect(client.authHeaders, {'Authorization': 'Bearer jwt-2'});
      await tokens.clear();
      expect(client.authHeaders, isEmpty);
    });
  });

  group('unauthorized stream', () {
    test('fires on 401 for an authenticated request', () async {
      await tokens.save('expired');
      adapter.fail('GET', '/issues', 401, code: 'UNAUTHENTICATED');

      await expectLater(
        client.dio.get<void>('/issues'),
        throwsA(isA<DioException>()),
      );
      await flush();

      expect(unauthorizedCount, 1);
    });

    test('does not fire for /auth/ calls (wrong password)', () async {
      await tokens.save('jwt');
      adapter.fail('POST', '/auth/login', 401, code: 'UNAUTHENTICATED');

      await expectLater(
        client.dio.post<void>('/auth/login'),
        throwsA(isA<DioException>()),
      );
      await flush();

      expect(unauthorizedCount, 0);
    });

    test('does not fire when there is no token', () async {
      adapter.fail('GET', '/me', 401, code: 'UNAUTHENTICATED');

      await expectLater(
        client.dio.get<void>('/me'),
        throwsA(isA<DioException>()),
      );
      await flush();

      expect(unauthorizedCount, 0);
    });

    test('does not fire for other errors', () async {
      await tokens.save('jwt');
      adapter
        ..fail('GET', '/issues', 403, code: 'FORBIDDEN')
        ..offline('GET', '/me');

      await expectLater(
        client.dio.get<void>('/issues'),
        throwsA(isA<DioException>()),
      );
      await expectLater(
        client.dio.get<void>('/me'),
        throwsA(isA<DioException>()),
      );
      await flush();

      expect(unauthorizedCount, 0);
    });
  });

  group('TokenStore', () {
    test('load reads storage once and caches the token', () async {
      final storage = FakeSecureStorage({'fixmycampus.jwt': 'saved'});
      final store = TokenStore(storage);

      expect(store.token, isNull);
      expect(await store.load(), 'saved');
      expect(await store.load(), 'saved');
      expect(store.token, 'saved');
      verify(() => storage.read(key: 'fixmycampus.jwt')).called(1);
    });

    test('save and clear update memory and storage', () async {
      final storage = FakeSecureStorage();
      final store = TokenStore(storage);

      await store.save('t1');
      expect(store.token, 't1');
      expect(storage.data['fixmycampus.jwt'], 't1');

      await store.clear();
      expect(store.token, isNull);
      expect(storage.data, isEmpty);
    });

    test('a corrupt keystore entry starts clean', () async {
      final storage = FakeSecureStorage();
      when(() => storage.read(key: any(named: 'key')))
          .thenThrow(Exception('BAD_DECRYPT'));

      expect(await TokenStore(storage).load(), isNull);
    });
  });
}
