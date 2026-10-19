import 'package:equatable/equatable.dart';

enum UserRole {
  student('student'),
  admin('admin');

  const UserRole(this.value);

  final String value;

  /// Unknown or missing roles fail closed to [student].
  static UserRole fromValue(String? value) =>
      value == admin.value ? admin : student;
}

class AppUser extends Equatable {
  const AppUser({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.role,
    required this.campusId,
    required this.isActive,
    this.department,
    this.photoUrl,
    this.avatar,
  });

  final String uid;
  final String displayName;
  final String email;
  final UserRole role;
  final String campusId;
  final bool isActive;
  final String? department;
  final String? photoUrl;

  /// Preset avatar id (see `AvatarPreset`), or null for the default.
  final String? avatar;

  bool get isAdmin => role == UserRole.admin;

  @override
  List<Object?> get props => [
    uid,
    displayName,
    email,
    role,
    campusId,
    isActive,
    department,
    photoUrl,
    avatar,
  ];
}
