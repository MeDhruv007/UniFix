part of 'auth_bloc.dart';

enum SessionStatus { unknown, authenticated, unauthenticated }

enum AuthFormStatus { idle, submitting, success, failure }

final class AuthState extends Equatable {
  const AuthState({
    this.session = SessionStatus.unknown,
    this.user,
    this.formStatus = AuthFormStatus.idle,
    this.message,
  });

  final SessionStatus session;
  final AppUser? user;
  final AuthFormStatus formStatus;

  /// User-safe error or confirmation text for the current form action.
  final String? message;

  bool get isAdmin => user?.isAdmin ?? false;
  bool get isSubmitting => formStatus == AuthFormStatus.submitting;

  AuthState copyWith({
    SessionStatus? session,
    AppUser? Function()? user,
    AuthFormStatus? formStatus,
    String? Function()? message,
  }) => AuthState(
    session: session ?? this.session,
    user: user != null ? user() : this.user,
    formStatus: formStatus ?? this.formStatus,
    message: message != null ? message() : this.message,
  );

  @override
  List<Object?> get props => [session, user, formStatus, message];
}
