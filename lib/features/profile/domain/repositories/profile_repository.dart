/// Edits the signed-in user's own profile.
///
/// Only `displayName` and `department` are editable from the client
/// (docs/API.md). The updated profile reaches the UI through the session
/// stream already held by `AuthBloc`.
abstract interface class ProfileRepository {
  /// Implementations trim both fields, store an empty [department] as null,
  /// enforce displayName 2–60 / department ≤60 chars, and publish the
  /// updated user to the session. Throws a `Failure` on validation,
  /// permission or network errors.
  Future<void> updateProfile({required String displayName, String? department});

  /// Sets the preset avatar (an `AvatarPreset` id), or clears it with null,
  /// and publishes the updated user to the session.
  Future<void> setAvatar(String? avatarId);
}
