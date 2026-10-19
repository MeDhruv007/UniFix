import 'dart:async';

import 'package:dio/dio.dart';

import '../config/api_config.dart';
import 'token_store.dart';

/// The single configured Dio instance for the UniFix API.
///
/// Adds the bearer token to every request and announces when the server
/// rejects it (401), so the session can be ended.
class ApiClient {
  ApiClient({required this._tokens, Dio? dio})
    : dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: ApiConfig.baseUrl,
              connectTimeout: ApiConfig.connectTimeout,
              receiveTimeout: ApiConfig.receiveTimeout,
              sendTimeout: ApiConfig.sendTimeout,
              contentType: Headers.jsonContentType,
              responseType: ResponseType.json,
            ),
          ) {
    this.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = _tokens.token;
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) {
          final isAuthCall = error.requestOptions.path.startsWith('/auth/');
          if (error.response?.statusCode == 401 &&
              !isAuthCall &&
              _tokens.token != null) {
            _unauthorized.add(null);
          }
          handler.next(error);
        },
      ),
    );
  }

  final TokenStore _tokens;
  final Dio dio;
  final _unauthorized = StreamController<void>.broadcast();

  /// Fires when an authenticated request is rejected (expired/revoked token).
  Stream<void> get unauthorized => _unauthorized.stream;

  /// Headers for loading protected images outside Dio.
  Map<String, String> get authHeaders {
    final token = _tokens.token;
    return token == null ? const {} : {'Authorization': 'Bearer $token'};
  }
}
