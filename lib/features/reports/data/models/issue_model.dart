import '../../domain/entities/issue.dart';
import '../../domain/entities/issue_enums.dart';
import '../../domain/entities/issue_update.dart';
import '../../domain/repositories/issue_repository.dart';

DateTime? _date(Object? value) =>
    value == null ? null : DateTime.parse(value as String).toLocal();

List<String> _strings(Object? value) =>
    (value as List<dynamic>? ?? const []).cast<String>();

/// JSON mapping for the API `Issue` object (docs/API.md).
abstract final class IssueModel {
  static Issue fromJson(Map<String, dynamic> json) => Issue(
    id: json['id'] as String,
    campusId: json['campusId'] as String,
    title: json['title'] as String,
    description: json['description'] as String,
    category: IssueCategory.fromValue(json['category'] as String?),
    buildingId: json['buildingId'] as String,
    locationDetail: json['locationDetail'] as String,
    photoPaths: _strings(json['photoPaths']),
    reporterId: json['reporterId'] as String,
    reporterDisplayName: json['reporterDisplayName'] as String?,
    status: IssueStatus.fromValue(json['status'] as String?),
    priority: IssuePriority.fromValue(json['priority'] as String?),
    assignedTo: json['assignedTo'] as String?,
    resolutionNote: json['resolutionNote'] as String?,
    resolutionPhotoPaths: _strings(json['resolutionPhotoPaths']),
    createdAt: _date(json['createdAt']),
    updatedAt: _date(json['updatedAt']),
    resolvedAt: _date(json['resolvedAt']),
    reopenCount: (json['reopenCount'] as num?)?.toInt() ?? 0,
    number: (json['number'] as num?)?.toInt(),
    code: json['code'] as String?,
    assignedToName: json['assignedToName'] as String?,
    upvoteCount: (json['upvoteCount'] as num?)?.toInt() ?? 0,
    upvotedByMe: json['upvotedByMe'] as bool? ?? false,
  );
}

/// JSON mapping for `GET /issues/stats`. Tolerates the v1 shape (counts only).
abstract final class IssueStatsModel {
  static IssueStats fromJson(Map<String, dynamic> json) {
    int n(String key) => (json[key] as num?)?.toInt() ?? 0;
    final byCategory = (json['openByCategory'] as Map<String, dynamic>?) ?? {};
    return IssueStats(
      reported: n('reported'),
      inProgress: n('inProgress'),
      resolved: n('resolved'),
      reopened: n('reopened'),
      total: n('total'),
      open: json.containsKey('open')
          ? n('open')
          : n('reported') + n('inProgress') + n('reopened'),
      urgent: n('urgent'),
      unassigned: n('unassigned'),
      assignedToMe: n('assignedToMe'),
      createdLast24h: n('createdLast24h'),
      resolvedThisWeek: n('resolvedThisWeek'),
      avgResolutionHours: (json['avgResolutionHours'] as num?)?.toDouble(),
      openByCategory: {
        for (final c in IssueCategory.values)
          c: (byCategory[c.value] as num?)?.toInt() ?? 0,
      },
    );
  }
}

/// JSON mapping for the API `IssueUpdate` object.
abstract final class IssueUpdateModel {
  static IssueUpdate fromJson(Map<String, dynamic> json) {
    String? s(String key) => json[key] as String?;
    return IssueUpdate(
      id: json['id'] as String,
      actorId: s('actorId') ?? '',
      action: IssueUpdateAction.fromValue(s('action')),
      oldStatus: s('oldStatus') == null
          ? null
          : IssueStatus.fromValue(s('oldStatus')),
      newStatus: s('newStatus') == null
          ? null
          : IssueStatus.fromValue(s('newStatus')),
      oldPriority: s('oldPriority') == null
          ? null
          : IssuePriority.fromValue(s('oldPriority')),
      newPriority: s('newPriority') == null
          ? null
          : IssuePriority.fromValue(s('newPriority')),
      note: s('note'),
      actorName: s('actorName'),
      createdAt: _date(json['createdAt']),
    );
  }
}
