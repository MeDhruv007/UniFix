/// App-wide configuration for the single-campus MVP.
abstract final class AppConstants {
  static const String appName = 'UniFix';

  /// The only campus supported in the first release.
  static const String campusId = 'adit-main';

  static const int titleMinLength = 5;
  static const int titleMaxLength = 100;
  static const int descriptionMinLength = 10;
  static const int descriptionMaxLength = 1000;
  static const int locationMaxLength = 120;
  static const int noteMaxLength = 500;
  static const int displayNameMaxLength = 60;
  static const int passwordMinLength = 8;

  static const int maxPhotosPerIssue = 3;
  static const int maxPhotoBytes = 5 * 1024 * 1024;
  static const int feedPageSize = 20;
}

class Building {
  const Building(this.id, this.name);

  final String id;
  final String name;
}

/// Seeded building list for [AppConstants.campusId].
abstract final class CampusBuildings {
  static const List<Building> all = [
    Building('engineering-block', 'Engineering Block'),
    Building('science-block', 'Science Block'),
    Building('admin-block', 'Administration Block'),
    Building('library', 'Library'),
    Building('workshop', 'Workshop'),
    Building('canteen', 'Canteen'),
    Building('hostel', 'Hostel'),
    Building('sports-complex', 'Sports Complex'),
    Building('auditorium', 'Auditorium'),
    Building('grounds', 'Grounds & Parking'),
  ];

  static String nameOf(String id) =>
      all.firstWhere((b) => b.id == id, orElse: () => Building(id, id)).name;
}
