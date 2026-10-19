import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists the session JWT in the platform keystore.
///
/// Also keeps an in-memory copy so the request interceptor never awaits
/// storage on the hot path.
class TokenStore {
  TokenStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'fixmycampus.jwt';

  final FlutterSecureStorage _storage;
  String? _token;
  bool _loaded = false;

  String? get token => _token;

  Future<String?> load() async {
    if (!_loaded) {
      try {
        _token = await _storage.read(key: _key);
      } catch (_) {
        // Corrupt keystore entry (e.g. after a backup restore): start clean.
        _token = null;
      }
      _loaded = true;
    }
    return _token;
  }

  Future<void> save(String token) async {
    _token = token;
    _loaded = true;
    await _storage.write(key: _key, value: token);
  }

  Future<void> clear() async {
    _token = null;
    _loaded = true;
    await _storage.delete(key: _key);
  }
}
