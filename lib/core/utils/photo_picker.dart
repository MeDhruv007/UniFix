import 'package:image_picker/image_picker.dart';

import '../constants/app_constants.dart';
import '../errors/failures.dart';

enum PhotoSource { camera, gallery }

/// Picks a photo and downsizes it on-device before upload.
class PhotoPicker {
  PhotoPicker([ImagePicker? picker]) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  /// Returns a local file path, or null if the user cancelled.
  Future<String?> pick(PhotoSource source) async {
    final file = await _picker.pickImage(
      source: source == PhotoSource.camera
          ? ImageSource.camera
          : ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 80,
      requestFullMetadata: false,
    );
    if (file == null) return null;
    if (await file.length() > AppConstants.maxPhotoBytes) {
      throw const ValidationFailure('That photo is too large (max 5 MB).');
    }
    return file.path;
  }
}
