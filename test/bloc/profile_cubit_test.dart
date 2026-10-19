import 'package:bloc_test/bloc_test.dart';
import 'package:fixmycampus/core/errors/failures.dart';
import 'package:fixmycampus/features/profile/domain/repositories/profile_repository.dart';
import 'package:fixmycampus/features/profile/presentation/bloc/profile_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockProfileRepository extends Mock implements ProfileRepository {}

void main() {
  late _MockProfileRepository repo;

  setUp(() => repo = _MockProfileRepository());

  void stubUpdate(Future<void> Function() answer) => when(
    () => repo.updateProfile(
      displayName: any(named: 'displayName'),
      department: any(named: 'department'),
    ),
  ).thenAnswer((_) => answer());

  test('starts idle', () {
    expect(ProfileCubit(repository: repo).state, const ProfileState());
  });

  blocTest<ProfileCubit, ProfileState>(
    'emits saving then success and forwards the fields',
    setUp: () => stubUpdate(() async {}),
    build: () => ProfileCubit(repository: repo),
    act: (c) => c.updateProfile(displayName: 'Asha P', department: 'CSE'),
    expect: () => const [
      ProfileState(status: ProfileStatus.saving),
      ProfileState(status: ProfileStatus.success),
    ],
    verify: (_) => verify(
      () => repo.updateProfile(displayName: 'Asha P', department: 'CSE'),
    ).called(1),
  );

  blocTest<ProfileCubit, ProfileState>(
    'emits failure with a user-safe message',
    setUp: () => stubUpdate(() async => throw const PermissionFailure()),
    build: () => ProfileCubit(repository: repo),
    act: (c) => c.updateProfile(displayName: 'Asha'),
    expect: () => const [
      ProfileState(status: ProfileStatus.saving),
      ProfileState(
        status: ProfileStatus.failure,
        message: 'You do not have permission to do that.',
      ),
    ],
  );

  blocTest<ProfileCubit, ProfileState>(
    'maps unknown errors to the generic failure message',
    setUp: () => stubUpdate(() async => throw StateError('boom')),
    build: () => ProfileCubit(repository: repo),
    act: (c) => c.updateProfile(displayName: 'Asha'),
    expect: () => const [
      ProfileState(status: ProfileStatus.saving),
      ProfileState(
        status: ProfileStatus.failure,
        message: 'Something went wrong. Please try again.',
      ),
    ],
  );

  blocTest<ProfileCubit, ProfileState>(
    'ignores a second save while one is in flight',
    setUp: () => stubUpdate(() async {}),
    build: () => ProfileCubit(repository: repo),
    seed: () => const ProfileState(status: ProfileStatus.saving),
    act: (c) => c.updateProfile(displayName: 'Asha'),
    expect: () => const <ProfileState>[],
    verify: (_) => verifyNever(
      () => repo.updateProfile(
        displayName: any(named: 'displayName'),
        department: any(named: 'department'),
      ),
    ),
  );

  blocTest<ProfileCubit, ProfileState>(
    'acknowledge returns to idle after an outcome',
    build: () => ProfileCubit(repository: repo),
    seed: () => const ProfileState(status: ProfileStatus.success),
    act: (c) => c.acknowledge(),
    expect: () => const [ProfileState()],
  );
}
