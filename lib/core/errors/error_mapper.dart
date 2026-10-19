import 'dart:developer' as developer;

import 'package:dio/dio.dart';

import '../network/api_error_mapper.dart';
import 'failures.dart';

/// Translates infrastructure exceptions into user-safe [Failure]s.
///
/// Only status codes and error types are logged, never bodies or headers,
/// so tokens and personal data stay out of logs.
Failure mapException(Object error, [StackTrace? stackTrace]) {
  if (error is Failure) return error;

  if (error is DioException) {
    _log('http/${error.type.name}/${error.response?.statusCode}', stackTrace);
    return mapDioException(error);
  }

  _log(error.runtimeType.toString(), stackTrace);
  return const UnexpectedFailure();
}

void _log(String code, StackTrace? stackTrace) {
  developer.log('Mapped error: $code', name: 'UniFix', stackTrace: stackTrace);
}
