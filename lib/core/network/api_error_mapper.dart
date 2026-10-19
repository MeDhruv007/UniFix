import 'package:dio/dio.dart';

import '../errors/failures.dart';

/// Maps a [DioException] to a [Failure] using the error contract in
/// docs/API.md: `{ "error": { "code": "...", "message": "..." } }`.
///
/// The server's `message` is designed to be user-safe, so it is shown as is;
/// the local fallbacks cover responses without that body.
Failure mapDioException(DioException e) {
  switch (e.type) {
    case DioExceptionType.connectionTimeout ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.receiveTimeout ||
        DioExceptionType.transformTimeout ||
        DioExceptionType.connectionError:
      return const NetworkFailure(
        'Cannot reach the UniFix server. Check your connection and try again.',
      );
    case DioExceptionType.cancel:
      return const UnexpectedFailure('The request was cancelled.');
    case DioExceptionType.badCertificate:
      return const NetworkFailure('Secure connection to the server failed.');
    case DioExceptionType.badResponse || DioExceptionType.unknown:
      break;
  }

  final response = e.response;
  if (response == null) return const NetworkFailure();

  final (code, message) = _errorBody(response.data);
  return switch ((response.statusCode, code)) {
    (401, _) => AuthFailure(message ?? 'Please sign in again.'),
    (403, 'ACCOUNT_DISABLED') => AuthFailure(
      message ??
          'This account has been deactivated. Contact the facilities office.',
    ),
    (403, _) => PermissionFailure(
      message ?? 'You do not have permission to do that.',
    ),
    (404, _) => NotFoundFailure(message ?? 'That item could not be found.'),
    (409, _) => ConflictFailure(
      message ?? 'This was changed by someone else. Refresh and try again.',
    ),
    (413, _) => UploadFailure(message ?? 'That photo is too large (max 5 MB).'),
    (400 || 422, _) => ValidationFailure(message ?? 'Please check your input.'),
    _ => UnexpectedFailure(
      message ?? 'Something went wrong. Please try again.',
    ),
  };
}

(String?, String?) _errorBody(Object? data) {
  if (data is Map && data['error'] is Map) {
    final error = data['error'] as Map;
    return (error['code'] as String?, error['message'] as String?);
  }
  return (null, null);
}
