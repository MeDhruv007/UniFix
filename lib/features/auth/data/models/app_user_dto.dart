import '../../../../core/constants/app_constants.dart';
import '../../domain/entities/app_user.dart';

/// JSON mapping for the API `User` object (docs/API.md).
abstract final class AppUserDto {
  static AppUser fromJson(Map<String, dynamic> json) => AppUser(
    uid: json['id'] as String,
    displayName: json['displayName'] as String? ?? '',
    email: json['email'] as String? ?? '',
    role: UserRole.fromValue(json['role'] as String?),
    campusId: json['campusId'] as String? ?? AppConstants.campusId,
    // Missing flag fails closed.
    isActive: json['isActive'] as bool? ?? false,
    department: json['department'] as String?,
    photoUrl: json['photoUrl'] as String?,
    avatar: json['avatar'] as String?,
  );

  /// Used only to cache the session user locally.
  static Map<String, dynamic> toJson(AppUser user) => {
    'id': user.uid,
    'displayName': user.displayName,
    'email': user.email,
    'role': user.role.value,
    'campusId': user.campusId,
    'isActive': user.isActive,
    'department': user.department,
    'photoUrl': user.photoUrl,
    'avatar': user.avatar,
  };
}
