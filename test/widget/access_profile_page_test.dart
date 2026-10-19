import 'package:bloc_test/bloc_test.dart';
import 'package:fixmycampus/core/theme/app_theme.dart';
import 'package:fixmycampus/features/auth/domain/entities/app_user.dart';
import 'package:fixmycampus/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:fixmycampus/features/profile/domain/repositories/profile_repository.dart';
import 'package:fixmycampus/features/profile/presentation/bloc/profile_cubit.dart';
import 'package:fixmycampus/features/profile/presentation/pages/profile_page.dart';
import 'package:fixmycampus/injection_container.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _MockProfileRepository extends Mock implements ProfileRepository {}

const _user = AppUser(
  uid: 'u1',
  displayName: 'Aarav Shah',
  email: 'aarav.shah@adit.ac.in',
  role: UserRole.student,
  campusId: 'adit-main',
  isActive: true,
  department: 'Robotics Club',
);

void main() {
  late _MockAuthBloc auth;
  late _MockProfileRepository repo;

  setUpAll(() => registerFallbackValue(const AuthSignOutRequested()));

  setUp(() {
    auth = _MockAuthBloc();
    repo = _MockProfileRepository();
    when(() => auth.state).thenReturn(
      const AuthState(session: SessionStatus.authenticated, user: _user),
    );
    when(
      () => repo.updateProfile(
        displayName: any(named: 'displayName'),
        department: any(named: 'department'),
      ),
    ).thenAnswer((_) async {});
    getIt.registerFactory<ProfileCubit>(() => ProfileCubit(repository: repo));
  });

  tearDown(getIt.reset);

  Future<void> pump(WidgetTester tester, {bool embedded = false}) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      BlocProvider<AuthBloc>.value(
        value: auth,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: ProfilePage(embedded: embedded),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('shows the account and no back button when embedded', (
    tester,
  ) async {
    await pump(tester, embedded: true);
    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Aarav Shah'), findsWidgets);
    expect(find.text('aarav.shah@adit.ac.in'), findsOneWidget);
    expect(find.text('Student'), findsOneWidget);
    expect(find.byTooltip('Back'), findsNothing);
  });

  testWidgets('has a back button when pushed', (tester) async {
    await pump(tester);
    expect(find.byTooltip('Back'), findsOneWidget);
  });

  testWidgets('a free-text department is kept under "Other"', (tester) async {
    await pump(tester);
    expect(find.text('Other'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Robotics Club'), findsOneWidget);
  });

  testWidgets('saves edits and signs out', (tester) async {
    await pump(tester);
    // The name field is the first text field on the page.
    await tester.enterText(find.byType(TextFormField).first, 'Aarav S.');
    await tester.tap(find.text('Save changes'));
    await tester.pump();
    verify(
      () => repo.updateProfile(
        displayName: 'Aarav S.',
        department: 'Robotics Club',
      ),
    ).called(1);

    await tester.scrollUntilVisible(
      find.text('Sign out'),
      100,
      // The page list is the outermost scrollable; text fields have their own.
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Sign out'));
    verify(() => auth.add(const AuthSignOutRequested())).called(1);
  });
}
