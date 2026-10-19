import '../constants/app_constants.dart';

/// Form validators. Each returns an error message, or null when valid.
///
/// These mirror the limits enforced by the API (docs/API.md); the server
/// remains the source of truth.
abstract final class Validators {
  static final RegExp _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Email is required.';
    if (!_email.hasMatch(v)) return 'Enter a valid email address.';
    return null;
  }

  static final RegExp _digit = RegExp(r'[0-9]');

  /// New passwords: 8+ characters with at least one number. Sign-in does
  /// not use this, so older passwords keep working.
  static String? password(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Password is required.';
    if (v.length < AppConstants.passwordMinLength) {
      return 'Use at least ${AppConstants.passwordMinLength} characters.';
    }
    if (!_digit.hasMatch(v)) return 'Include at least one number.';
    return null;
  }

  static String? displayName(String? value) => _bounded(
    value,
    field: 'Name',
    min: 2,
    max: AppConstants.displayNameMaxLength,
  );

  static String? issueTitle(String? value) => _bounded(
    value,
    field: 'Title',
    min: AppConstants.titleMinLength,
    max: AppConstants.titleMaxLength,
  );

  static String? issueDescription(String? value) => _bounded(
    value,
    field: 'Description',
    min: AppConstants.descriptionMinLength,
    max: AppConstants.descriptionMaxLength,
  );

  static String? locationDetail(String? value) => _bounded(
    value,
    field: 'Location',
    min: 2,
    max: AppConstants.locationMaxLength,
  );

  static String? optionalNote(String? value) {
    final v = value?.trim() ?? '';
    if (v.length > AppConstants.noteMaxLength) {
      return 'Keep this under ${AppConstants.noteMaxLength} characters.';
    }
    return null;
  }

  static String? _bounded(
    String? value, {
    required String field,
    required int min,
    required int max,
  }) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return '$field is required.';
    if (v.length < min) return '$field must be at least $min characters.';
    if (v.length > max) return '$field must be at most $max characters.';
    return null;
  }
}
