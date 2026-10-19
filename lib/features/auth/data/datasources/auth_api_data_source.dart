import 'package:dio/dio.dart';

import '../../domain/entities/app_user.dart';
import '../models/app_user_dto.dart';

typedef AuthSession = ({String token, AppUser user});

/// `/auth/*` and `/me` endpoints. Throws [DioException]s; the repository
/// maps them to failures.
class AuthApiDataSource {
  AuthApiDataSource({required this._dio});

  final Dio _dio;

  Future<AuthSession> login(String email, String password) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/auth/login',
      data: {'email': email, 'password': password},
    );
    return _session(res.data!);
  }

  Future<AuthSession> register({
    required String displayName,
    required String email,
    required String password,
    String? department,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/auth/register',
      data: {
        'displayName': displayName,
        'email': email,
        'password': password,
        'department': department,
      },
    );
    return _session(res.data!);
  }

  Future<void> requestPasswordReset(String email) =>
      _dio.post<void>('/auth/password-reset', data: {'email': email});

  Future<void> confirmPasswordReset(String token, String newPassword) =>
      _dio.post<void>(
        '/auth/password-reset/confirm',
        data: {'token': token, 'newPassword': newPassword},
      );

  Future<AppUser> me() async {
    final res = await _dio.get<Map<String, dynamic>>('/me');
    return AppUserDto.fromJson(res.data!);
  }

  Future<AppUser> updateMe({String? displayName, String? department}) async {
    final res = await _dio.patch<Map<String, dynamic>>(
      '/me',
      data: {'displayName': ?displayName, 'department': ?department},
    );
    return AppUserDto.fromJson(res.data!);
  }

  /// Sets the preset avatar; [avatarId] null clears it.
  Future<AppUser> setAvatar(String? avatarId) async {
    final res = await _dio.patch<Map<String, dynamic>>(
      '/me',
      data: {'avatar': avatarId},
    );
    return AppUserDto.fromJson(res.data!);
  }

  AuthSession _session(Map<String, dynamic> body) => (
    token: body['token'] as String,
    user: AppUserDto.fromJson(body['user'] as Map<String, dynamic>),
  );
}
