import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

typedef FakeHandler = FutureOr<ResponseBody> Function(RequestOptions options);

const fakeBaseUrl = 'http://api.test/api/v1';

/// A tiny in-memory [HttpClientAdapter].
///
/// Routes `"METHOD /path"` to a handler and records every request, so tests
/// can assert on paths, query parameters, headers and bodies without a
/// server. Unrouted requests get a contract-shaped 404.
class FakeHttpAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];
  final Map<String, FakeHandler> _routes = {};

  RequestOptions get last => requests.last;

  void on(String method, String path, FakeHandler handler) =>
      _routes['${method.toUpperCase()} $path'] = handler;

  void reply(String method, String path, Object? body, {int status = 200}) =>
      on(method, path, (_) => jsonResponse(body, status: status));

  void fail(
    String method,
    String path,
    int status, {
    String? code,
    String? message,
  }) => on(
    method,
    path,
    (_) => errorResponse(status, code: code, message: message),
  );

  /// Simulates an unreachable server.
  void offline(String method, String path) => on(
    method,
    path,
    (o) => throw DioException.connectionError(
      requestOptions: o,
      reason: 'offline',
    ),
  );

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    // Consume the encoded body (finalizes multipart forms).
    await requestStream?.drain<void>();
    final handler = _routes['${options.method} ${options.path}'];
    if (handler == null) {
      return errorResponse(
        404,
        code: 'NOT_FOUND',
        message: 'No fake route for ${options.method} ${options.path}',
      );
    }
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody jsonResponse(Object? body, {int status = 200}) {
  if (body == null) return ResponseBody.fromString('', status);
  return ResponseBody.fromString(
    jsonEncode(body),
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

/// The docs/API.md error body; pass null [code] and [message] for a bare
/// response without it.
ResponseBody errorResponse(int status, {String? code, String? message}) =>
    jsonResponse(
      code == null && message == null
          ? <String, dynamic>{}
          : {
              'error': {'code': code, 'message': message},
            },
      status: status,
    );

Dio fakeDio(FakeHttpAdapter adapter) => Dio(
  BaseOptions(
    baseUrl: fakeBaseUrl,
    contentType: Headers.jsonContentType,
    responseType: ResponseType.json,
  ),
)..httpClientAdapter = adapter;
