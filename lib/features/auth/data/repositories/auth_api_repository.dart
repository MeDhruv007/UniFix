import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../../core/errors/error_mapper.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/token_store.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_api_data_source.dart';
import '../models/app_user_dto.dart';

/// Session backed by the REST API: a JWT plus the cached user profile.
///
/// The cached user lets the app open offline; the server copy is
/// re-fetched on start and every [_refreshEvery] so role changes and
/// deactivation take effect. Any 401 ends the session.
class AuthApiRepository implements AuthRepository {
  AuthApiRepository({
    required this._api,
    required this._tokens,
    required ApiClient client,
    FlutterSecureStorage? storage,
  }) : _storage = storage ?? const FlutterSecureStorage() {
    _unauthorizedSub = client.unauthorized.listen((_) => _endSession());
  }

  static const _userKey = 'fixmycampus.user';
  static const _refreshEvery = Duration(minutes: 1);

  final AuthApiDataSource _api;
  final TokenStore _tokens;
  final FlutterSecureStorage _storage;
  late final StreamSubscription<void> _unauthorizedSub;

  final _user = StreamController<AppUser?>.broadcast();
  AppUser? _current;
  bool _restored = false;
  Timer? _refreshTimer;

  AppUser? get currentUser => _current;

  @override
  Stream<AppUser?> watchCurrentUser() {
    late final StreamController<AppUser?> controller;
    StreamSubscription<AppUser?>? updates;
    controller = StreamController<AppUser?>(
      onListen: () async {
        // Subscribe before restoring so no session change can slip through
        // between reading the cached user and listening for updates.
        updates = _user.stream.listen(
          controller.add,
          onError: controller.addError,
        );
        if (!_restored) {
          _restored = true;
          await _restore();
        }
        // _current is always the latest value, even if an update already
        // arrived above.
        if (!controller.isClosed) controller.add(_current);
      },
      onCancel: () => updates?.cancel(),
    );
    return controller.stream;
  }

  @override
  Future<void> signIn({required String email, required String password}) =>
      _guard(() async {
        final session = await _api.login(email.trim(), password);
        await _startSession(session.token, session.user);
      });

  @override
  Future<void> register({
    required String displayName,
    required String email,
    required String password,
    String? department,
  }) => _guard(() async {
    final dept = department?.trim();
    final session = await _api.register(
      displayName: displayName.trim(),
      email: email.trim(),
      password: password,
      department: (dept == null || dept.isEmpty) ? null : dept,
    );
    await _startSession(session.token, session.user);
  });

  @override
  Future<void> sendPasswordReset(String email) =>
      _guard(() => _api.requestPasswordReset(email.trim()));

  @override
  Future<void> confirmPasswordReset({
    required String token,
    required String newPassword,
  }) => _guard(() => _api.confirmPasswordReset(token.trim(), newPassword));

  @override
  Future<void> signOut() => _endSession();

  /// Publishes a profile returned by another endpoint (e.g. `PATCH /me`).
  Future<void> updateCurrentUser(AppUser user) async {
    if (_current == null) return;
    await _setUser(user);
  }

  Future<void> _restore() async {
    final token = await _tokens.load();
    if (token == null) return;
    try {
      final cached = await _storage.read(key: _userKey);
      if (cached != null) {
        _current = AppUserDto.fromJson(
          jsonDecode(cached) as Map<String, dynamic>,
        );
      }
    } catch (_) {
      _current = null;
    }
    // Validate with the server; while offline, the cached user is kept.
    unawaited(_refresh());
    _scheduleRefresh();
  }

  Future<void> _refresh() async {
    if (_tokens.token == null) return;
    try {
      final user = await _api.me();
      if (!user.isActive) {
        await _endSession();
        _user.addError(
          const AuthFailure(
            'This account has been deactivated. Contact the facilities office.',
          ),
        );
        return;
      }
      await _setUser(user);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 401 || status == 403) {
        // 401 is handled by the client's unauthorized stream; 403 here
        // means the account is disabled.
        await _endSession();
        if (status == 403) _user.addError(mapException(e));
      }
      // Network errors: keep the cached session and try again later.
    } catch (e, st) {
      // Runs unawaited or from a timer, so never let it escape. A malformed
      // body or a keystore failure keeps the session; the next tick retries.
      mapException(e, st);
    }
  }

  Future<void> _startSession(String token, AppUser user) async {
    await _tokens.save(token);
    await _setUser(user);
    _scheduleRefresh();
  }

  Future<void> _setUser(AppUser user) async {
    _current = user;
    _user.add(user);
    await _storage.write(
      key: _userKey,
      value: jsonEncode(AppUserDto.toJson(user)),
    );
  }

  Future<void> _endSession() async {
    _refreshTimer?.cancel();
    final wasSignedIn = _current != null || _tokens.token != null;
    _current = null;
    await _tokens.clear();
    await _storage.delete(key: _userKey);
    if (wasSignedIn) _user.add(null);
  }

  void _scheduleRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(_refreshEvery, (_) => _refresh());
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } catch (e, st) {
      throw mapException(e, st);
    }
  }

  Future<void> dispose() async {
    _refreshTimer?.cancel();
    await _unauthorizedSub.cancel();
    await _user.close();
  }
}
