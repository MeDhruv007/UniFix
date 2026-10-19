import 'package:fixmycampus/core/utils/formatters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 3, 20, 12);

  group('Formatters.dateTime', () {
    test('null (pending server timestamp) reads as "Just now"', () {
      expect(Formatters.dateTime(null), 'Just now');
    });

    test('formats day, month, year and 12-hour time', () {
      expect(
        Formatters.dateTime(DateTime(2026, 3, 5, 14, 7)),
        '5 Mar 2026, 2:07 PM',
      );
      expect(
        Formatters.dateTime(DateTime(2026, 12, 31, 0, 0)),
        '31 Dec 2026, 12:00 AM',
      );
    });
  });

  group('Formatters.relative', () {
    String rel(Duration ago) =>
        Formatters.relative(now.subtract(ago), now: now);

    test('null reads as "Just now"', () {
      expect(Formatters.relative(null, now: now), 'Just now');
      expect(Formatters.relative(null), 'Just now');
    });

    test('under a minute is "Just now"', () {
      expect(rel(Duration.zero), 'Just now');
      expect(rel(const Duration(seconds: 59)), 'Just now');
    });

    test('future timestamps (clock skew) read as "Just now"', () {
      expect(rel(const Duration(minutes: -5)), 'Just now');
    });

    test('minutes', () {
      expect(rel(const Duration(minutes: 1)), '1m ago');
      expect(rel(const Duration(minutes: 59)), '59m ago');
    });

    test('hours', () {
      expect(rel(const Duration(hours: 1)), '1h ago');
      expect(rel(const Duration(hours: 23, minutes: 59)), '23h ago');
    });

    test('days', () {
      expect(rel(const Duration(days: 1)), '1d ago');
      expect(rel(const Duration(days: 6, hours: 23)), '6d ago');
    });

    test('a week or more shows a short date', () {
      expect(rel(const Duration(days: 7)), '13 Mar');
      expect(Formatters.relative(DateTime(2025, 1, 2), now: now), '2 Jan');
    });
  });
}
