/// Backend location. See docs/API.md.
///
/// `10.0.2.2` is the host machine as seen from the Android emulator. For a
/// physical phone, run with
/// `--dart-define=API_BASE_URL=http://<your PC's LAN IP>:3000/api/v1`.
abstract final class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000/api/v1',
  );

  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 20);

  /// Uploads can be slow on campus Wi-Fi.
  static const Duration sendTimeout = Duration(seconds: 60);

  /// How often list/detail "live" streams re-fetch from the API.
  static const Duration pollInterval = Duration(seconds: 15);

  static String photoUrl(String photoPath) => '$baseUrl/photos/$photoPath';
}
