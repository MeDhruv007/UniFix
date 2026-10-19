import '../../../core/errors/error_mapper.dart';
import '../../../core/errors/failures.dart';
import '../../../core/utils/validators.dart';
import '../../auth/data/datasources/auth_api_data_source.dart';
import '../../auth/data/repositories/auth_api_repository.dart';
import '../domain/repositories/profile_repository.dart';

/// `PATCH /me`, then publishes the updated user to the session so every
/// screen (via AuthBloc) refreshes.
class ProfileRepositoryImpl implements ProfileRepository {
  ProfileRepositoryImpl({required this._api, required this._session});

  final AuthApiDataSource _api;
  final AuthApiRepository _session;

  @override
  Future<void> updateProfile({
    required String displayName,
    String? department,
  }) async {
    final name = displayName.trim();
    final dept = department?.trim() ?? '';
    final nameError = Validators.displayName(name);
    if (nameError != null) throw ValidationFailure(nameError);
    if (dept.length > 60) {
      throw const ValidationFailure(
        'Department must be at most 60 characters.',
      );
    }
    try {
      // Empty string clears the department (stored as null server-side).
      final user = await _api.updateMe(displayName: name, department: dept);
      await _session.updateCurrentUser(user);
    } catch (e, st) {
      throw mapException(e, st);
    }
  }

  @override
  Future<void> setAvatar(String? avatarId) async {
    try {
      final user = await _api.setAvatar(avatarId);
      await _session.updateCurrentUser(user);
    } catch (e, st) {
      throw mapException(e, st);
    }
  }
}
