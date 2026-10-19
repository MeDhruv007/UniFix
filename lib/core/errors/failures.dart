import 'package:equatable/equatable.dart';

/// Domain-level error with a message that is safe to show to users.
///
/// Repositories throw [Failure]s; BLoCs catch them and expose [message].
sealed class Failure extends Equatable implements Exception {
  const Failure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];

  @override
  String toString() => '$runtimeType($message)';
}

class AuthFailure extends Failure {
  const AuthFailure(super.message);
}

class PermissionFailure extends Failure {
  const PermissionFailure([
    super.message = 'You do not have permission to do that.',
  ]);
}

class NetworkFailure extends Failure {
  const NetworkFailure([
    super.message =
        'You appear to be offline. Check your connection and try again.',
  ]);
}

class NotFoundFailure extends Failure {
  const NotFoundFailure([super.message = 'That item could not be found.']);
}

/// The server state changed since it was read (e.g. a stale status).
class ConflictFailure extends Failure {
  const ConflictFailure([
    super.message = 'This was changed by someone else. Refresh and try again.',
  ]);
}

class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}

class UploadFailure extends Failure {
  const UploadFailure([
    super.message = 'Photo upload failed. Please try again.',
  ]);
}

class UnexpectedFailure extends Failure {
  const UnexpectedFailure([
    super.message = 'Something went wrong. Please try again.',
  ]);
}
