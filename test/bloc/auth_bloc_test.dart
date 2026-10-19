import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:fixmycampus/core/errors/failures.dart';
import 'package:fixmycampus/features/auth/domain/entities/app_user.dart';
import 'package:fixmycampus/features/auth/domain/repositories/auth_repository.dart';
import 'package:fixmycampus/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

const _student = AppUser(
  uid: 'u1',
  displayName: 'Asha',
  email: 'asha@adit.ac.in',
  role: UserRole.student,
  campusId: 'adit-main',
  isActive: true,
);

void main() {
  late _MockAuthRepository repo;

  setUp(() => repo = _MockAuthRepository());

  group('session', () {
    blocTest<AuthBloc, AuthState>(
      'maps profile stream to authenticated / unauthenticated',
      setUp: () =>
          when(repo.watchCurrentUser)
              .thenAnswer((_) => Stream.fromIterable([null, _student, null])),
      build: () => AuthBloc(repository: repo),
      act: (b) => b.add(const AuthSubscriptionRequested()),
      expect: () => [
        const AuthState(session: SessionStatus.unauthenticated),
        const AuthState(session: SessionStatus.authenticated, user: _student),
        const AuthState(session: SessionStatus.unauthenticated),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'stream failure signs out with a user-safe message',
      setUp: () => when(repo.watchCurrentUser)
          .thenAnswer((_) => Stream.error(const AuthFailure('deactivated'))),
      build: () => AuthBloc(repository: repo),
      act: (b) => b.add(const AuthSubscriptionRequested()),
      expect: () => [
        const AuthState(
          session: SessionStatus.unauthenticated,
          formStatus: AuthFormStatus.failure,
          message: 'deactivated',
        ),
      ],
    );
  });

  group('sign in', () {
    blocTest<AuthBloc, AuthState>(
      'emits submitting, then failure on bad credentials',
      setUp: () => when(
        () => repo.signIn(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenThrow(const AuthFailure('Incorrect email or password.')),
      build: () => AuthBloc(repository: repo),
      seed: () => const AuthState(session: SessionStatus.unauthenticated),
      act: (b) => b.add(
        const AuthSignInRequested(email: 'a@b.co', password: 'wrongpass'),
      ),
      expect: () => [
        const AuthState(
          session: SessionStatus.unauthenticated,
          formStatus: AuthFormStatus.submitting,
        ),
        const AuthState(
          session: SessionStatus.unauthenticated,
          formStatus: AuthFormStatus.failure,
          message: 'Incorrect email or password.',
        ),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'session stream completes the submitting form',
      setUp: () {
        final controller = StreamController<AppUser?>();
        when(repo.watchCurrentUser).thenAnswer((_) => controller.stream);
        when(
          () => repo.signIn(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenAnswer((_) async => controller.add(_student));
      },
      build: () => AuthBloc(repository: repo),
      act: (b) async {
        b.add(const AuthSubscriptionRequested());
        await Future<void>.delayed(Duration.zero);
        b.add(
          const AuthSignInRequested(email: 'a@b.co', password: 'password1'),
        );
      },
      expect: () => [
        const AuthState(formStatus: AuthFormStatus.submitting),
        const AuthState(session: SessionStatus.authenticated, user: _student),
      ],
    );
  });

  blocTest<AuthBloc, AuthState>(
    'password reset shows a neutral confirmation',
    setUp: () =>
        when(() => repo.sendPasswordReset(any())).thenAnswer((_) async {}),
    build: () => AuthBloc(repository: repo),
    act: (b) => b.add(const AuthPasswordResetRequested('a@b.co')),
    expect: () => [
      const AuthState(formStatus: AuthFormStatus.submitting),
      isA<AuthState>()
          .having((s) => s.formStatus, 'formStatus', AuthFormStatus.success)
          .having(
            (s) => s.message,
            'message',
            contains('If an account exists'),
          ),
    ],
  );

  group('password reset confirm', () {
    blocTest<AuthBloc, AuthState>(
      'success shows a confirmation',
      setUp: () => when(
        () => repo.confirmPasswordReset(
          token: any(named: 'token'),
          newPassword: any(named: 'newPassword'),
        ),
      ).thenAnswer((_) async {}),
      build: () => AuthBloc(repository: repo),
      act: (b) => b.add(
        const AuthPasswordResetConfirmed(
          token: 'abc',
          newPassword: 'newpass123',
        ),
      ),
      expect: () => [
        const AuthState(formStatus: AuthFormStatus.submitting),
        const AuthState(
          formStatus: AuthFormStatus.success,
          message: 'Password updated. Sign in with your new password.',
        ),
      ],
      verify: (_) => verify(
        () =>
            repo.confirmPasswordReset(token: 'abc', newPassword: 'newpass123'),
      ).called(1),
    );

    blocTest<AuthBloc, AuthState>(
      'invalid code shows the server message',
      setUp: () => when(
        () => repo.confirmPasswordReset(
          token: any(named: 'token'),
          newPassword: any(named: 'newPassword'),
        ),
      ).thenThrow(const ValidationFailure('Reset code is invalid or expired.')),
      build: () => AuthBloc(repository: repo),
      act: (b) => b.add(
        const AuthPasswordResetConfirmed(
          token: 'bad',
          newPassword: 'newpass123',
        ),
      ),
      expect: () => [
        const AuthState(formStatus: AuthFormStatus.submitting),
        const AuthState(
          formStatus: AuthFormStatus.failure,
          message: 'Reset code is invalid or expired.',
        ),
      ],
    );
  });
}
