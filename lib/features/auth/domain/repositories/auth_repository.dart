import '../entities/app_user.dart';

/// Contract for authentication and the signed-in user's profile.
/// Implementations throw [Failure]s.
abstract interface class AuthRepository {
  /// Emits the signed-in user's profile, or null when signed out.
  ///
  /// Role is read from the server-controlled `users/{uid}` document; it is
  /// never taken from client input.
  Stream<AppUser?> watchCurrentUser();

  Future<void> signIn({required String email, required String password});

  Future<void> register({
    required String displayName,
    required String email,
    required String password,
    String? department,
  });

  Future<void> sendPasswordReset(String email);

  /// Sets a new password using a reset code from [sendPasswordReset].
  Future<void> confirmPasswordReset({
    required String token,
    required String newPassword,
  });

  Future<void> signOut();
}
