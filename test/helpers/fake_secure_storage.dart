import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mocktail/mocktail.dart';

/// [FlutterSecureStorage] backed by an in-memory map (no platform channels).
///
/// It is a mocktail mock, so tests can still `verify` calls or override a
/// stub (e.g. make `read` throw).
class FakeSecureStorage extends Mock implements FlutterSecureStorage {
  FakeSecureStorage([Map<String, String>? initial]) : data = {...?initial} {
    when(() => read(key: any(named: 'key')))
        .thenAnswer((i) async => data[i.namedArguments[#key] as String]);
    when(
      () => write(
        key: any(named: 'key'),
        value: any(named: 'value'),
      ),
    ).thenAnswer((i) async {
      final key = i.namedArguments[#key] as String;
      final value = i.namedArguments[#value] as String?;
      if (value == null) {
        data.remove(key);
      } else {
        data[key] = value;
      }
    });
    when(() => delete(key: any(named: 'key')))
        .thenAnswer((i) async => data.remove(i.namedArguments[#key] as String));
  }

  final Map<String, String> data;
}
