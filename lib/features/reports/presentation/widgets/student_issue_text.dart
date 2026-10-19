import 'package:intl/intl.dart';

import '../../../../core/constants/app_constants.dart';
import '../../domain/entities/issue.dart';
import '../../domain/entities/issue_enums.dart';

/// Short display strings used by the student screens.
abstract final class StudentIssueText {
  static final DateFormat _day = DateFormat('d MMM');

  /// Compact age for pills: "now", "12m", "5h", "3d", then "4 Mar".
  static String age(DateTime? value, {DateTime? now}) {
    if (value == null) return 'now';
    final diff = (now ?? DateTime.now()).difference(value);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 30) return '${diff.inDays}d';
    return _day.format(value);
  }

  /// Average time to fix: "—" when unknown, "5h" under a day, "1.8d".
  static String avgToFix(double? hours) {
    if (hours == null || hours.isNaN || hours < 0) return '—';
    if (hours < 1) return '<1h';
    if (hours < 24) return '${hours.round()}h';
    final days = hours / 24;
    final rounded = (days * 10).round() / 10;
    return rounded == rounded.roundToDouble()
        ? '${rounded.toInt()}d'
        : '${rounded.toStringAsFixed(1)}d';
  }

  /// "Engineering Block · Room 204".
  static String where(Issue issue) {
    final building = CampusBuildings.nameOf(issue.buildingId);
    final detail = issue.locationDetail.trim();
    return detail.isEmpty ? building : '$building · $detail';
  }

  /// "In progress · R. Mehta assigned", or just the status.
  static String statusLine(Issue issue) {
    final assignee = issue.assignedToName?.trim();
    return assignee == null || assignee.isEmpty
        ? issue.status.label
        : '${issue.status.label} · $assignee assigned';
  }

  /// Secondary note on "My reports" cards.
  static String note(Issue issue) {
    final assignee = issue.assignedToName?.trim();
    if (issue.status == IssueStatus.resolved) {
      return issue.resolvedAt == null
          ? 'Fixed'
          : 'Fixed ${_day.format(issue.resolvedAt!)}';
    }
    if (assignee != null && assignee.isNotEmpty) return '$assignee assigned';
    return issue.status == IssueStatus.reported
        ? 'Awaiting triage'
        : 'Awaiting staff';
  }

  /// Category name as the design's chips write it ("IT", not "IT / Network").
  static String category(IssueCategory category) =>
      category == IssueCategory.it ? 'IT' : category.label;

  /// Category name inside a sentence ("plumbing", "IT").
  static String categoryInSentence(IssueCategory category) =>
      category == IssueCategory.it ? 'IT' : category.label.toLowerCase();
}
