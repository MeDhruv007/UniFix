import 'package:fixmycampus/core/routing/app_router.dart';
import 'package:fixmycampus/core/routing/routes.dart';
import 'package:fixmycampus/features/auth/domain/entities/app_user.dart';
import 'package:fixmycampus/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

AppUser _user(UserRole role) => AppUser(
  uid: 'u1',
  displayName: 'Test',
  email: 't@adit.ac.in',
  role: role,
  campusId: 'adit-main',
  isActive: true,
);

void main() {
  const unknown = AuthState();
  const signedOut = AuthState(session: SessionStatus.unauthenticated);
  final student = AuthState(
    session: SessionStatus.authenticated,
    user: _user(UserRole.student),
  );
  final admin = AuthState(
    session: SessionStatus.authenticated,
    user: _user(UserRole.admin),
  );

  test('unknown session holds on splash', () {
    expect(
      redirectFor(authState: unknown, location: Routes.home),
      Routes.splash,
    );
    expect(redirectFor(authState: unknown, location: Routes.splash), isNull);
  });

  test('signed out users only reach public routes', () {
    expect(
      redirectFor(authState: signedOut, location: Routes.home),
      Routes.login,
    );
    expect(
      redirectFor(authState: signedOut, location: Routes.admin),
      Routes.login,
    );
    expect(
      redirectFor(authState: signedOut, location: Routes.register),
      isNull,
    );
  });

  test('signed in users land on their role home', () {
    expect(
      redirectFor(authState: student, location: Routes.login),
      Routes.home,
    );
    expect(
      redirectFor(authState: admin, location: Routes.splash),
      Routes.admin,
    );
  });

  test('students get the no-access screen for admin routes', () {
    expect(
      redirectFor(authState: student, location: Routes.admin),
      Routes.noAccess,
    );
    expect(redirectFor(authState: admin, location: Routes.admin), isNull);
  });
}
