import 'package:bloc_test/bloc_test.dart';
import 'package:fixmycampus/core/theme/app_theme.dart';
import 'package:fixmycampus/features/auth/domain/entities/app_user.dart';
import 'package:fixmycampus/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:fixmycampus/features/auth/presentation/pages/forgot_password_page.dart';
import 'package:fixmycampus/features/auth/presentation/pages/login_page.dart';
import 'package:fixmycampus/features/auth/presentation/pages/no_access_page.dart';
import 'package:fixmycampus/features/auth/presentation/pages/register_page.dart';
import 'package:fixmycampus/features/auth/presentation/pages/reset_password_page.dart';
import 'package:fixmycampus/features/auth/presentation/pages/splash_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

const _student = AppUser(
  uid: 'u1',
  displayName: 'Aarav Shah',
  email: 'aarav.shah@adit.ac.in',
  role: UserRole.student,
  campusId: 'adit-main',
  isActive: true,
);

void main() {
  late _MockAuthBloc auth;

  setUpAll(() => registerFallbackValue(const AuthMessageCleared()));

  setUp(() {
    auth = _MockAuthBloc();
    when(() => auth.state)
        .thenReturn(const AuthState(session: SessionStatus.unauthenticated));
  });

  Future<void> pump(WidgetTester tester, Widget page) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      BlocProvider<AuthBloc>.value(
        value: auth,
        child: MaterialApp(theme: AppTheme.light(), home: page),
      ),
    );
    await tester.pump();
  }

  group('LoginPage', () {
    testWidgets('renders the design copy without overflow', (tester) async {
      await pump(tester, const LoginPage());
      expect(find.text('UniFix'), findsOneWidget);
      expect(find.text('ADIT'), findsOneWidget);
      expect(find.text('Sign in'), findsOneWidget);
      expect(find.text('Create an account'), findsOneWidget);
      expect(find.text('Forgot password?'), findsOneWidget);
    });

    testWidgets('validates before dispatching', (tester) async {
      await pump(tester, const LoginPage());
      await tester.tap(find.text('Sign in'));
      await tester.pump();
      expect(find.text('Email is required.'), findsOneWidget);
      expect(find.text('Password is required.'), findsOneWidget);
      verifyNever(() => auth.add(any()));
    });

    testWidgets('signs in with the entered credentials', (tester) async {
      await pump(tester, const LoginPage());
      await tester.enterText(find.byType(TextFormField).at(0), 'a@adit.ac.in');
      await tester.enterText(find.byType(TextFormField).at(1), 'secret12');
      await tester.tap(find.text('Sign in'));
      await tester.pump();
      verify(
        () => auth.add(
          const AuthSignInRequested(email: 'a@adit.ac.in', password: 'x'),
        ),
      ).called(1);
    });

    testWidgets('Show / Hide toggles the password', (tester) async {
      await pump(tester, const LoginPage());
      EditableText field() => tester.widget<EditableText>(
        find.descendant(
          of: find.byType(TextFormField).at(1),
          matching: find.byType(EditableText),
        ),
      );
      expect(field().obscureText, isTrue);
      await tester.tap(find.text('Show'));
      await tester.pump();
      expect(field().obscureText, isFalse);
      expect(find.text('Hide'), findsOneWidget);
    });

    testWidgets('shows auth messages as a snackbar', (tester) async {
      whenListen(
        auth,
        Stream.value(
          const AuthState(
            session: SessionStatus.unauthenticated,
            formStatus: AuthFormStatus.failure,
            message: 'Wrong email or password.',
          ),
        ),
        initialState: const AuthState(session: SessionStatus.unauthenticated),
      );
      await pump(tester, const LoginPage());
      await tester.pump();
      expect(find.text('Wrong email or password.'), findsOneWidget);
      verify(() => auth.add(const AuthMessageCleared())).called(1);
    });
  });

  group('RegisterPage', () {
    testWidgets('renders without overflow', (tester) async {
      await pump(tester, const RegisterPage());
      expect(find.text('Create account'), findsWidgets);
      expect(find.text('Use your ADIT email'), findsOneWidget);
      expect(find.text('8+ characters, one number'), findsOneWidget);
      expect(
        find.text(
          'New accounts are student accounts. Facilities access is set up '
          'by the college.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('"Other" department reveals a text field and registers '
        'with it', (tester) async {
      await pump(tester, const RegisterPage());
      await tester.tap(find.text('Department (optional)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Other').last);
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextFormField, 'Your department'), findsOne);

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Aarav Shah');
      await tester.enterText(fields.at(1), 'aarav@adit.ac.in');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Your department'),
        'Robotics',
      );
      await tester.enterText(fields.at(3), 'password1');
      await tester.enterText(fields.at(4), 'password1');
      await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
      await tester.pump();

      final event =
          verify(() => auth.add(captureAny())).captured.single
              as AuthRegisterRequested;
      expect(event.displayName, 'Aarav Shah');
      expect(event.department, 'Robotics');
    });

    testWidgets('requires a number in the password', (tester) async {
      await pump(tester, const RegisterPage());
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(2), 'password');
      await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
      await tester.pump();
      expect(find.text('Include at least one number.'), findsOneWidget);
    });
  });

  testWidgets('ForgotPasswordPage renders without overflow', (tester) async {
    await pump(tester, const ForgotPasswordPage());
    expect(find.text('Send reset code'), findsOneWidget);
    expect(find.text('I have a reset code'), findsOneWidget);
  });

  testWidgets('ResetPasswordPage renders without overflow', (tester) async {
    await pump(tester, const ResetPasswordPage());
    expect(find.text('Update password'), findsOneWidget);
  });

  testWidgets('SplashPage renders without overflow', (tester) async {
    await pump(tester, const SplashPage());
    expect(find.text('UniFix'), findsOneWidget);
    expect(find.text('ADIT CAMPUS'), findsOneWidget);
    // The mark builds in ~1 s; it must finish without errors.
    await tester.pump(const Duration(milliseconds: 1100));
    expect(tester.takeException(), isNull);
  });

  testWidgets('NoAccessPage shows the signed-in student', (tester) async {
    when(() => auth.state).thenReturn(
      const AuthState(session: SessionStatus.authenticated, user: _student),
    );
    await pump(tester, const NoAccessPage());
    expect(find.text('Facilities staff only'), findsOneWidget);
    expect(find.text('aarav.shah@adit.ac.in'), findsOneWidget);
    expect(find.text('Signed in as Student'), findsOneWidget);
    expect(find.text('Back to home'), findsOneWidget);
    expect(
      find.text('Work in Facilities? Ask your coordinator for access.'),
      findsOneWidget,
    );
  });
}
