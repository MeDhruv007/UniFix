import 'package:flutter/material.dart';

import '../../features/reports/domain/entities/issue_enums.dart';
import 'app_colors.dart';

typedef SwatchPair = ({Color background, Color foreground});

/// Category avatar codes and colours from the design's feed data.
extension CategoryStyle on IssueCategory {
  /// Two-letter avatar code (EL, PL, ...).
  String get code => switch (this) {
    IssueCategory.electrical => 'EL',
    IssueCategory.plumbing => 'PL',
    IssueCategory.cleanliness => 'CL',
    IssueCategory.furniture => 'FU',
    IssueCategory.it => 'IT',
    IssueCategory.safety => 'SF',
    IssueCategory.other => 'OT',
  };

  SwatchPair get swatch => switch (this) {
    IssueCategory.electrical => (
      background: AppColors.periwinkle,
      foreground: AppColors.ink,
    ),
    IssueCategory.plumbing => (
      background: AppColors.pink,
      foreground: AppColors.ink,
    ),
    IssueCategory.safety => (
      background: AppColors.orange,
      foreground: AppColors.ink,
    ),
    IssueCategory.it => (
      background: AppColors.periwinkleLight,
      foreground: AppColors.ink,
    ),
    IssueCategory.furniture => (
      background: AppColors.ink,
      foreground: AppColors.white,
    ),
    IssueCategory.cleanliness => (
      background: AppColors.surface,
      foreground: AppColors.ink,
    ),
    IssueCategory.other => (
      background: AppColors.border,
      foreground: AppColors.ink,
    ),
  };

  /// Bar colour in the admin "Open by category" chart.
  Color get chartColor => switch (this) {
    IssueCategory.electrical => AppColors.ink,
    IssueCategory.plumbing || IssueCategory.cleanliness => AppColors.periwinkle,
    IssueCategory.it || IssueCategory.furniture => AppColors.periwinkleLight,
    IssueCategory.safety => AppColors.orange,
    IssueCategory.other => AppColors.border,
  };
}

extension StatusStyle on IssueStatus {
  Color get pillColor => switch (this) {
    IssueStatus.reported => AppColors.statusReported,
    IssueStatus.inProgress => AppColors.statusInProgress,
    IssueStatus.resolved => AppColors.statusResolved,
    IssueStatus.reopened => AppColors.statusReopened,
  };
}

extension PriorityStyle on IssuePriority {
  /// Card background in the triage queue (Urgent orange, High pink).
  Color get cardColor => switch (this) {
    IssuePriority.urgent => AppColors.orange,
    IssuePriority.high => AppColors.pink,
    IssuePriority.medium || IssuePriority.low => AppColors.surface,
  };

  /// Small priority pill: black for urgent, white otherwise.
  SwatchPair get pill => switch (this) {
    IssuePriority.urgent => (
      background: AppColors.ink,
      foreground: AppColors.white,
    ),
    _ => (background: AppColors.white, foreground: AppColors.ink),
  };
}
