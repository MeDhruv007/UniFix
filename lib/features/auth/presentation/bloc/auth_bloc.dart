import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/error_mapper.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc({required this._repository}) : super(const AuthState()) {
    on<AuthSubscriptionRequested>(_onSubscriptionRequested);
    on<AuthSignInRequested>(_onSignIn);
    on<AuthRegisterRequested>(_onRegister);
    on<AuthPasswordResetRequested>(_onPasswordReset);
    on<AuthPasswordResetConfirmed>(
      (event, emit) => _submit(
        emit,
        () => _repository.confirmPasswordReset(
          token: event.token,
          newPassword: event.newPassword,
        ),
        successMessage: 'Password updated. Sign in with your new password.',
      ),
    );
    on<AuthSignOutRequested>(_onSignOut);
    on<AuthMessageCleared>(
      (_, emit) => emit(
        state.copyWith(formStatus: AuthFormStatus.idle, message: () => null),
      ),
    );
  }

  final AuthRepository _repository;

  Future<void> _onSubscriptionRequested(
    AuthSubscriptionRequested event,
    Emitter<AuthState> emit,
  ) {
    // emit.forEach cancels the subscription when the bloc closes.
    return emit.forEach<AppUser?>(
      _repository.watchCurrentUser(),
      onData: (user) => user == null
          ? state.copyWith(
              session: SessionStatus.unauthenticated,
              user: () => null,
            )
          : state.copyWith(
              session: SessionStatus.authenticated,
              user: () => user,
              // A form waiting on sign-in/registration has now completed.
              formStatus: state.isSubmitting
                  ? AuthFormStatus.idle
                  : state.formStatus,
            ),
      onError: (error, stackTrace) => state.copyWith(
        session: SessionStatus.unauthenticated,
        user: () => null,
        formStatus: AuthFormStatus.failure,
        message: () => mapException(error, stackTrace).message,
      ),
    );
  }

  Future<void> _onSignIn(AuthSignInRequested event, Emitter<AuthState> emit) =>
      _submit(
        emit,
        () => _repository.signIn(email: event.email, password: event.password),
      );

  Future<void> _onRegister(
    AuthRegisterRequested event,
    Emitter<AuthState> emit,
  ) => _submit(
    emit,
    () => _repository.register(
      displayName: event.displayName,
      email: event.email,
      password: event.password,
      department: event.department,
    ),
  );

  Future<void> _onPasswordReset(
    AuthPasswordResetRequested event,
    Emitter<AuthState> emit,
  ) => _submit(
    emit,
    () => _repository.sendPasswordReset(event.email),
    // Same message whether or not the account exists (no enumeration).
    successMessage:
        'If an account exists for that email, a reset code has been issued.',
  );

  Future<void> _onSignOut(
    AuthSignOutRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      await _repository.signOut();
    } catch (e, st) {
      emit(
        state.copyWith(
          formStatus: AuthFormStatus.failure,
          message: () => mapException(e, st).message,
        ),
      );
    }
  }

  /// Runs a form action. On success the session stream drives navigation,
  /// except for actions that do not change the session ([successMessage]).
  Future<void> _submit(
    Emitter<AuthState> emit,
    Future<void> Function() action, {
    String? successMessage,
  }) async {
    if (state.isSubmitting) return;
    emit(
      state.copyWith(
        formStatus: AuthFormStatus.submitting,
        message: () => null,
      ),
    );
    try {
      await action();
      if (successMessage != null) {
        emit(
          state.copyWith(
            formStatus: AuthFormStatus.success,
            message: () => successMessage,
          ),
        );
      }
    } catch (e, st) {
      emit(
        state.copyWith(
          formStatus: AuthFormStatus.failure,
          message: () => mapException(e, st).message,
        ),
      );
    }
  }
}
