part of 'auth_bloc.dart';

sealed class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

/// Starts listening to the session. Dispatch once at app start.
final class AuthSubscriptionRequested extends AuthEvent {
  const AuthSubscriptionRequested();
}

final class AuthSignInRequested extends AuthEvent {
  const AuthSignInRequested({required this.email, required this.password});

  final String email;
  final String password;

  @override
  List<Object?> get props => [email];
}

final class AuthRegisterRequested extends AuthEvent {
  const AuthRegisterRequested({
    required this.displayName,
    required this.email,
    required this.password,
    this.department,
  });

  final String displayName;
  final String email;
  final String password;
  final String? department;

  @override
  List<Object?> get props => [displayName, email, department];
}

final class AuthPasswordResetRequested extends AuthEvent {
  const AuthPasswordResetRequested(this.email);

  final String email;

  @override
  List<Object?> get props => [email];
}

final class AuthPasswordResetConfirmed extends AuthEvent {
  const AuthPasswordResetConfirmed({
    required this.token,
    required this.newPassword,
  });

  final String token;
  final String newPassword;

  // Secrets are deliberately left out of props (and so of logs).
  @override
  List<Object?> get props => [];
}

final class AuthSignOutRequested extends AuthEvent {
  const AuthSignOutRequested();
}

/// Clears a one-off message after the UI has shown it.
final class AuthMessageCleared extends AuthEvent {
  const AuthMessageCleared();
}
