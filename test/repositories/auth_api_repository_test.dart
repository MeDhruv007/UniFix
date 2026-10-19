import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:fixmycampus/core/errors/failures.dart';
import 'package:fixmycampus/core/network/api_client.dart';
import 'package:fixmycampus/core/network/token_store.dart';
import 'package:fixmycampus/features/auth/data/datasources/auth_api_data_source.dart';
import 'package:fixmycampus/features/auth/data/models/app_user_dto.dart';
import 'package:fixmycampus/features/auth/data/repositories/auth_api_repository.dart';
import 'package:fixmycampus/features/auth/domain/entities/app_user.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/api_fixtures.dart';
import '../helpers/fake_http_adapter.dart';
import '../helpers/fake_secure_storage.dart';

const _tokenKey = 'fixmycampus.jwt';
const _userKey = 'fixmycampus.user';

final _cached = AppUserDto.fromJson(userJson(displayName: 'Cached Name'));
final _fresh = AppUserDto.fromJson(userJson(displayName: 'Fresh Name'));

/// Lets Dio round trips and stream deliveries finish.
Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  late FakeHttpAdapter adapter;
  late FakeSecureStorage storage;
  late TokenStore tokens;
  late ApiClient client;
  late AuthApiRepository repo;

  /// Builds the repository over [initial] secure storage contents.
  void build([Map<String, String>? initial]) {
    adapter = FakeHttpAdapter();
    storage = FakeSecureStorage(initial);
    tokens = TokenStore(storage);
    client = ApiClient(tokens: tokens, dio: fakeDio(adapter));
    repo = AuthApiRepository(
      api: AuthApiDataSource(dio: client.dio),
      tokens: tokens,
      client: client,
      storage: storage,
    );
    addTearDown(repo.dispose);
  }

  Map<String, String> signedInStorage() => {
    _tokenKey: 'jwt',
    _userKey: jsonEncode(AppUserDto.toJson(_cached)),
  };

  /// Subscribes and records users, nulls and errors in order.
  List<Object?> record() {
    final events = <Object?>[];
    final sub = repo.watchCurrentUser().listen(events.add, onError: events.add);
    addTearDown(sub.cancel);
    return events;
  }

  /// Holds `GET /me` until the test releases it.
  Completer<ResponseBody> holdMe() {
    final gate = Completer<ResponseBody>();
    adapter.on('GET', '/me', (_) => gate.future);
    return gate;
  }

  group('session restore', () {
    test('without a token emits null and never calls /me', () async {
      build();

      final events = record();
      await _settle();

      expect(events, [null]);
      expect(adapter.requests, isEmpty);
    });

    test('emits the cached user, then the /me refresh', () async {
      build(signedInStorage());
      final me = holdMe();

      final events = record();
      await _settle();
      expect(events, [_cached]);
      expect(adapter.last.headers['Authorization'], 'Bearer jwt');

      me.complete(jsonResponse(userJson(displayName: 'Fresh Name')));
      await _settle();

      expect(events, [_cached, _fresh]);
      expect(repo.currentUser, _fresh);
      expect(jsonDecode(storage.data[_userKey]!)['displayName'], 'Fresh Name');
    });

    test('a corrupt cached user is dropped but the token is kept', () async {
      build({_tokenKey: 'jwt', _userKey: '{not json'});
      final me = holdMe();

      final events = record();
      await _settle();
      me.complete(jsonResponse(userJson(displayName: 'Fresh Name')));
      await _settle();

      expect(events, [null, _fresh]);
    });

    test('an inactive user from /me ends the session with an error', () async {
      build(signedInStorage());
      final me = holdMe();

      final events = record();
      await _settle();
      me.complete(jsonResponse(userJson(isActive: false)));
      await _settle();

      expect(events, [
        _cached,
        null,
        isA<AuthFailure>().having(
          (f) => f.message,
          'message',
          contains('deactivated'),
        ),
      ]);
      expect(tokens.token, isNull);
      expect(storage.data, isEmpty);
    });

    test('401 from /me ends the session once', () async {
      build(signedInStorage());
      final me = holdMe();

      final events = record();
      await _settle();
      me.complete(errorResponse(401, code: 'UNAUTHENTICATED', message: 'x'));
      await _settle();

      expect(events, [_cached, null]);
      expect(tokens.token, isNull);
      expect(storage.data, isEmpty);
    });

    test('403 ACCOUNT_DISABLED from /me ends the session with the server '
        'message', () async {
      build(signedInStorage());
      final me = holdMe();

      final events = record();
      await _settle();
      me.complete(
        errorResponse(
          403,
          code: 'ACCOUNT_DISABLED',
          message: 'Account disabled.',
        ),
      );
      await _settle();

      expect(events, [_cached, null, const AuthFailure('Account disabled.')]);
      expect(tokens.token, isNull);
    });

    test('a network error keeps the cached session', () async {
      build(signedInStorage());
      adapter.offline('GET', '/me');

      final events = record();
      await _settle();

      expect(events, [_cached]);
      expect(tokens.token, 'jwt');
      expect(storage.data[_userKey], isNotNull);
      expect(repo.currentUser, _cached);
    });

    test('a 500 from /me keeps the cached session', () async {
      build(signedInStorage());
      adapter.fail('GET', '/me', 500, code: 'INTERNAL', message: 'oops');

      final events = record();
      await _settle();

      expect(events, [_cached]);
      expect(tokens.token, 'jwt');
    });

    test('restores only once across subscriptions', () async {
      build(signedInStorage());
      adapter.reply('GET', '/me', userJson(displayName: 'Fresh Name'));

      record();
      await _settle();
      final second = record();
      await _settle();

      expect(second, [_fresh]);
      expect(adapter.requests.where((r) => r.path == '/me'), hasLength(1));
    });
  });

  group('signIn', () {
    test('saves the token, caches and emits the user', () async {
      build();
      adapter.reply('POST', '/auth/login', {
        'token': 'new-jwt',
        'user': userJson(),
      });
      final events = record();
      await _settle();

      await repo.signIn(email: '  asha@adit.ac.in ', password: 'secret123');
      await _settle();

      expect(adapter.last.data, {
        'email': 'asha@adit.ac.in',
        'password': 'secret123',
      });
      expect(adapter.last.headers.containsKey('Authorization'), isFalse);
      expect(events, [null, AppUserDto.fromJson(userJson())]);
      expect(tokens.token, 'new-jwt');
      expect(storage.data[_tokenKey], 'new-jwt');
      expect(jsonDecode(storage.data[_userKey]!)['id'], 'u1');
      expect(client.authHeaders, {'Authorization': 'Bearer new-jwt'});
    });

    test('wrong credentials surface the server message', () async {
      build();
      adapter.fail(
        'POST',
        '/auth/login',
        401,
        code: 'UNAUTHENTICATED',
        message: 'Email or password is incorrect.',
      );

      await expectLater(
        repo.signIn(email: 'a@b.co', password: 'wrongpass'),
        throwsA(const AuthFailure('Email or password is incorrect.')),
      );
      expect(tokens.token, isNull);
    });

    test('deactivated account is an AuthFailure', () async {
      build();
      adapter.fail(
        'POST',
        '/auth/login',
        403,
        code: 'ACCOUNT_DISABLED',
        message: 'This account has been deactivated.',
      );

      await expectLater(
        repo.signIn(email: 'a@b.co', password: 'secret123'),
        throwsA(isA<AuthFailure>()),
      );
    });

    test('offline is a NetworkFailure', () async {
      build();
      adapter.offline('POST', '/auth/login');

      await expectLater(
        repo.signIn(email: 'a@b.co', password: 'secret123'),
        throwsA(isA<NetworkFailure>()),
      );
    });
  });

  group('register', () {
    setUp(build);

    test('posts trimmed fields, null blank department, emits user', () async {
      adapter.reply('POST', '/auth/register', {
        'token': 'jwt',
        'user': userJson(department: null),
      }, status: 201);
      final events = record();
      await _settle();

      await repo.register(
        displayName: ' Asha Patel ',
        email: ' asha@adit.ac.in ',
        password: ' pass word ',
        department: '   ',
      );
      await _settle();

      expect(adapter.last.data, {
        'displayName': 'Asha Patel',
        'email': 'asha@adit.ac.in',
        'password': ' pass word ',
        'department': null,
      });
      expect(events.last, isA<AppUser>());
      expect(tokens.token, 'jwt');
    });

    test('sends a trimmed department', () async {
      adapter.reply('POST', '/auth/register', {
        'token': 'jwt',
        'user': userJson(),
      }, status: 201);

      await repo.register(
        displayName: 'Asha',
        email: 'a@b.co',
        password: 'secret123',
        department: ' Computer ',
      );

      expect((adapter.last.data as Map)['department'], 'Computer');
    });

    test('409 email taken is a ConflictFailure', () async {
      adapter.fail(
        'POST',
        '/auth/register',
        409,
        code: 'CONFLICT',
        message: 'That email is already registered.',
      );

      await expectLater(
        repo.register(displayName: 'A B', email: 'a@b.co', password: 'x' * 8),
        throwsA(const ConflictFailure('That email is already registered.')),
      );
      expect(tokens.token, isNull);
    });
  });

  test('sendPasswordReset posts the trimmed email', () async {
    build();
    adapter.reply('POST', '/auth/password-reset', null, status: 204);

    await repo.sendPasswordReset(' asha@adit.ac.in ');

    expect(adapter.last.data, {'email': 'asha@adit.ac.in'});
  });

  group('signOut', () {
    test('clears the session and emits null', () async {
      build(signedInStorage());
      adapter.reply('GET', '/me', userJson(displayName: 'Cached Name'));
      final events = record();
      await _settle();

      await repo.signOut();
      await _settle();

      expect(events, [_cached, _cached, null]);
      expect(tokens.token, isNull);
      expect(storage.data, isEmpty);
      expect(repo.currentUser, isNull);
    });

    test('emits nothing when already signed out', () async {
      build();
      final events = record();
      await _settle();

      await repo.signOut();
      await _settle();

      expect(events, [null]);
    });
  });

  group('updateCurrentUser', () {
    test('publishes and caches the new profile while signed in', () async {
      build(signedInStorage());
      adapter.offline('GET', '/me');
      final events = record();
      await _settle();

      await repo.updateCurrentUser(_fresh);
      await _settle();

      expect(events, [_cached, _fresh]);
      expect(jsonDecode(storage.data[_userKey]!)['displayName'], 'Fresh Name');
    });

    test('is ignored when signed out', () async {
      build();
      final events = record();
      await _settle();

      await repo.updateCurrentUser(_fresh);
      await _settle();

      expect(events, [null]);
      expect(storage.data, isEmpty);
    });
  });

  test('a 401 on any authenticated request ends the session', () async {
    build(signedInStorage());
    adapter
      ..offline('GET', '/me')
      ..fail('GET', '/issues', 401, code: 'UNAUTHENTICATED', message: 'x');
    final events = record();
    await _settle();

    await expectLater(
      client.dio.get<void>('/issues'),
      throwsA(isA<DioException>()),
    );
    await _settle();

    expect(events, [_cached, null]);
    expect(tokens.token, isNull);
    expect(storage.data, isEmpty);
  });
}
