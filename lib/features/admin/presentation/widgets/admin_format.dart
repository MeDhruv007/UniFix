import '../../../../core/constants/app_constants.dart';
import '../../../reports/domain/entities/issue.dart';

/// Small display helpers for the admin screens.
abstract final class AdminFormat {
  /// Compact age: "now", "12m", "5h", "3d", "2w".
  static String age(DateTime? from, {DateTime? now}) {
    if (from == null) return 'now';
    final d = (now ?? DateTime.now()).difference(from);
    if (d.inMinutes < 1) return 'now';
    if (d.inMinutes < 60) return '${d.inMinutes}m';
    if (d.inHours < 24) return '${d.inHours}h';
    if (d.inDays < 14) return '${d.inDays}d';
    return '${d.inDays ~/ 7}w';
  }

  /// Average resolution time: "5h" under a day, "2.4d" otherwise, "—"
  /// when nothing has been resolved yet.
  static String resolution(double? hours) {
    if (hours == null || hours.isNaN || hours < 0) return '—';
    if (hours < 1) return '<1h';
    if (hours < 24) return '${hours.round()}h';
    final days = hours / 24;
    final text = days.toStringAsFixed(1);
    return '${text.endsWith('.0') ? text.substring(0, text.length - 2) : text}d';
  }

  /// "Science Block · Lab 3".
  static String location(Issue issue) {
    final building = CampusBuildings.nameOf(issue.buildingId);
    final detail = issue.locationDetail.trim();
    return detail.isEmpty ? building : '$building · $detail';
  }

  /// First word of a display name ("Rohan Mehta" → "Rohan").
  static String firstName(String? name) {
    final parts = (name ?? '').trim().split(RegExp(r'\s+'));
    return parts.first.isEmpty ? 'there' : parts.first;
  }
}
