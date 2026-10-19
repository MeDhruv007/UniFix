import 'package:equatable/equatable.dart';

import 'issue_enums.dart';

class Issue extends Equatable {
  const Issue({
    required this.id,
    required this.campusId,
    required this.title,
    required this.description,
    required this.category,
    required this.buildingId,
    required this.locationDetail,
    required this.reporterId,
    required this.status,
    required this.priority,
    this.photoPaths = const [],
    this.reporterDisplayName,
    this.assignedTo,
    this.resolutionNote,
    this.resolutionPhotoPaths = const [],
    this.createdAt,
    this.updatedAt,
    this.resolvedAt,
    this.reopenCount = 0,
    this.number,
    this.code,
    this.assignedToName,
    this.upvoteCount = 0,
    this.upvotedByMe = false,
  });

  final String id;
  final String campusId;
  final String title;
  final String description;
  final IssueCategory category;
  final String buildingId;
  final String locationDetail;
  final List<String> photoPaths;
  final String reporterId;
  final String? reporterDisplayName;
  final IssueStatus status;
  final IssuePriority priority;
  final String? assignedTo;
  final String? resolutionNote;
  final List<String> resolutionPhotoPaths;

  /// Null only briefly, while a server timestamp is pending locally.
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? resolvedAt;
  final int reopenCount;

  /// Sequential human-friendly id; null only for data from older servers.
  final int? number;

  /// Display id such as `FMC-0483`.
  final String? code;
  final String? assignedToName;

  /// How many people said "me too" (the reporter is not counted).
  final int upvoteCount;

  /// Whether the signed-in user said "me too".
  final bool upvotedByMe;

  Issue withUpvote({required bool upvoted, required int count}) => Issue(
    id: id,
    campusId: campusId,
    title: title,
    description: description,
    category: category,
    buildingId: buildingId,
    locationDetail: locationDetail,
    reporterId: reporterId,
    status: status,
    priority: priority,
    photoPaths: photoPaths,
    reporterDisplayName: reporterDisplayName,
    assignedTo: assignedTo,
    resolutionNote: resolutionNote,
    resolutionPhotoPaths: resolutionPhotoPaths,
    createdAt: createdAt,
    updatedAt: updatedAt,
    resolvedAt: resolvedAt,
    reopenCount: reopenCount,
    number: number,
    code: code,
    assignedToName: assignedToName,
    upvoteCount: count,
    upvotedByMe: upvoted,
  );

  /// Short label for the issue: its code, or the start of its id.
  String get displayCode {
    if (code != null) return code!;
    if (number != null) return 'FMC-${number.toString().padLeft(4, '0')}';
    return '#${id.length < 6 ? id : id.substring(0, 6)}';
  }

  /// Lifecycle progress shown as a ring: reported 1/3, in progress 2/3,
  /// resolved 3/3; reopened counts as back in progress.
  int get progressStep => switch (status) {
    IssueStatus.reported => 1,
    IssueStatus.inProgress || IssueStatus.reopened => 2,
    IssueStatus.resolved => 3,
  };

  @override
  List<Object?> get props => [
    id,
    campusId,
    title,
    description,
    category,
    buildingId,
    locationDetail,
    photoPaths,
    reporterId,
    reporterDisplayName,
    status,
    priority,
    assignedTo,
    resolutionNote,
    resolutionPhotoPaths,
    createdAt,
    updatedAt,
    resolvedAt,
    reopenCount,
    number,
    code,
    assignedToName,
    upvoteCount,
    upvotedByMe,
  ];
}
