import 'package:dio/dio.dart';
import 'package:fixmycampus/core/errors/error_mapper.dart';
import 'package:fixmycampus/core/errors/failures.dart';
import 'package:fixmycampus/core/network/api_error_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

final _req = RequestOptions(path: '/issues');

DioException _status(int status, [Object? data]) => DioException.badResponse(
  statusCode: status,
  requestOptions: _req,
  response: Response(requestOptions: _req, statusCode: status, data: data),
);

Map<String, dynamic> _body(String code, String message) => {
  'error': {'code': code, 'message': message},
};

DioException _ofType(DioExceptionType type) =>
    DioException(requestOptions: _req, type: type);

void main() {
  group('mapDioException transport errors', () {
    for (final type in [
      DioExceptionType.connectionTimeout,
      DioExceptionType.sendTimeout,
      DioExceptionType.receiveTimeout,
      DioExceptionType.transformTimeout,
      DioExceptionType.connectionError,
    ]) {
      test('${type.name} is a NetworkFailure', () {
        final failure = mapDioException(_ofType(type));
        expect(failure, isA<NetworkFailure>());
        expect(failure.message, contains('Cannot reach the UniFix server'));
      });
    }

    test('badCertificate is a NetworkFailure', () {
      expect(
        mapDioException(_ofType(DioExceptionType.badCertificate)),
        const NetworkFailure('Secure connection to the server failed.'),
      );
    });

    test('cancel is unexpected, not a network problem', () {
      expect(
        mapDioException(_ofType(DioExceptionType.cancel)),
        const UnexpectedFailure('The request was cancelled.'),
      );
    });

    test('unknown without a response is a NetworkFailure', () {
      expect(
        mapDioException(_ofType(DioExceptionType.unknown)),
        const NetworkFailure(),
      );
    });
  });

  group('mapDioException status codes use the server message', () {
    final cases = <(int, String, Matcher)>[
      (400, 'VALIDATION', isA<ValidationFailure>()),
      (401, 'UNAUTHENTICATED', isA<AuthFailure>()),
      (403, 'ACCOUNT_DISABLED', isA<AuthFailure>()),
      (403, 'FORBIDDEN', isA<PermissionFailure>()),
      (404, 'NOT_FOUND', isA<NotFoundFailure>()),
      (409, 'CONFLICT', isA<ConflictFailure>()),
      (422, 'INVALID_TRANSITION', isA<ValidationFailure>()),
      (500, 'INTERNAL', isA<UnexpectedFailure>()),
    ];
    for (final (status, code, matcher) in cases) {
      test('$status $code', () {
        final failure = mapDioException(
          _status(status, _body(code, 'Server says $code')),
        );
        expect(failure, matcher);
        expect(failure.message, 'Server says $code');
      });
    }

    test('413 is an UploadFailure with the server message', () {
      final failure = mapDioException(
        _status(413, _body('PAYLOAD_TOO_LARGE', 'Photo over 5 MB')),
      );
      expect(failure, const UploadFailure('Photo over 5 MB'));
    });
  });

  group('mapDioException local fallbacks without an error body', () {
    final cases = <(int, Failure)>[
      (400, const ValidationFailure('Please check your input.')),
      (401, const AuthFailure('Please sign in again.')),
      (403, const PermissionFailure()),
      (404, const NotFoundFailure()),
      (409, const ConflictFailure()),
      (413, const UploadFailure('That photo is too large (max 5 MB).')),
      (422, const ValidationFailure('Please check your input.')),
      (500, const UnexpectedFailure()),
      (502, const UnexpectedFailure()),
    ];
    for (final (status, expected) in cases) {
      test('$status', () {
        expect(mapDioException(_status(status)), expected);
      });
    }

    test('403 ACCOUNT_DISABLED without a message explains deactivation', () {
      final failure = mapDioException(
        _status(403, {
          'error': {'code': 'ACCOUNT_DISABLED'},
        }),
      );
      expect(failure, isA<AuthFailure>());
      expect(failure.message, contains('deactivated'));
    });

    test('non-JSON bodies are ignored', () {
      expect(
        mapDioException(_status(404, '<html>Not found</html>')),
        const NotFoundFailure(),
      );
      expect(
        mapDioException(_status(400, {'error': 'flat string'})),
        const ValidationFailure('Please check your input.'),
      );
    });

    test('unknown type with a response is mapped by status', () {
      final e = DioException(
        requestOptions: _req,
        response: Response(requestOptions: _req, statusCode: 404),
      );
      expect(mapDioException(e), const NotFoundFailure());
    });
  });

  group('mapException', () {
    test('passes Failures through unchanged', () {
      const failure = ConflictFailure('stale');
      expect(mapException(failure), same(failure));
    });

    test('maps DioExceptions with the API mapper', () {
      expect(
        mapException(_status(409, _body('CONFLICT', 'Already given'))),
        const ConflictFailure('Already given'),
      );
    });

    test('hides anything else behind a generic message', () {
      expect(mapException(StateError('boom')), const UnexpectedFailure());
      expect(
        mapException(const FormatException('bad json'), StackTrace.current),
        const UnexpectedFailure(),
      );
    });
  });
}
