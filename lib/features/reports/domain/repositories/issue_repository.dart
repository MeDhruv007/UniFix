import 'package:equatable/equatable.dart';

import '../entities/issue.dart';
import '../entities/issue_enums.dart';
import '../entities/issue_update.dart';

/// Input for creating a report. Photos are local file paths, already
/// compressed by the presentation layer.
class NewIssueInput extends Equatable {
  const NewIssueInput({
    required this.title,
    required this.description,
    required this.category,
    required this.buildingId,
    required this.locationDetail,
    this.localPhotoPaths = const [],
  });

  final String title;
  final String description;
  final IssueCategory category;
  final String buildingId;
  final String locationDetail;
  final List<String> localPhotoPaths;

  @override
  List<Object?> get props => [
    title,
    description,
    category,
    buildingId,
    locationDetail,
    localPhotoPaths,
  ];
}

enum IssueSort { newest, oldest, popular }

class IssueFilter extends Equatable {
  const IssueFilter({
    this.status,
    this.category,
    this.reporterId,
    this.query,
    this.openOnly = false,
    this.priority,
    this.assigned,
    this.assignedToMe = false,
    this.sort = IssueSort.newest,
  });

  final IssueStatus? status;
  final IssueCategory? category;

  /// When set, only this user's reports are returned ("My reports").
  final String? reporterId;

  /// Free-text search over title, location, building and code (FMC-0483).
  final String? query;

  /// Only reported / in progress / reopened.
  final bool openOnly;
  final IssuePriority? priority;

  /// `true` = has an assignee, `false` = unassigned, `null` = either.
  final bool? assigned;

  /// Only issues assigned to the signed-in admin ("My tasks").
  final bool assignedToMe;
  final IssueSort sort;

  /// Whether any user-facing narrowing is applied (search or filters).
  bool get isNarrowed =>
      status != null ||
      category != null ||
      (query?.trim().isNotEmpty ?? false) ||
      openOnly ||
      priority != null ||
      assigned != null ||
      assignedToMe;

  /// Fields wrapped in a function so they can be cleared to null.
  IssueFilter copyWith({
    IssueStatus? Function()? status,
    IssueCategory? Function()? category,
    String? Function()? reporterId,
    String? Function()? query,
    bool? openOnly,
    IssuePriority? Function()? priority,
    bool? Function()? assigned,
    bool? assignedToMe,
    IssueSort? sort,
  }) => IssueFilter(
    status: status != null ? status() : this.status,
    category: category != null ? category() : this.category,
    reporterId: reporterId != null ? reporterId() : this.reporterId,
    query: query != null ? query() : this.query,
    openOnly: openOnly ?? this.openOnly,
    priority: priority != null ? priority() : this.priority,
    assigned: assigned != null ? assigned() : this.assigned,
    assignedToMe: assignedToMe ?? this.assignedToMe,
    sort: sort ?? this.sort,
  );

  @override
  List<Object?> get props => [
    status,
    category,
    reporterId,
    query,
    openOnly,
    priority,
    assigned,
    assignedToMe,
    sort,
  ];
}

/// Aggregates from `GET /issues/stats` (campus-wide, or the caller's own
/// reports when requested with `mine`).
class IssueStats extends Equatable {
  const IssueStats({
    this.reported = 0,
    this.inProgress = 0,
    this.resolved = 0,
    this.reopened = 0,
    this.total = 0,
    this.open = 0,
    this.urgent = 0,
    this.unassigned = 0,
    this.assignedToMe = 0,
    this.createdLast24h = 0,
    this.resolvedThisWeek = 0,
    this.avgResolutionHours,
    this.openByCategory = const {},
  });

  final int reported;
  final int inProgress;
  final int resolved;
  final int reopened;
  final int total;
  final int open;
  final int urgent;
  final int unassigned;

  /// Open issues assigned to the caller.
  final int assignedToMe;
  final int createdLast24h;
  final int resolvedThisWeek;

  /// Null when nothing has been resolved yet.
  final double? avgResolutionHours;
  final Map<IssueCategory, int> openByCategory;

  int countFor(IssueStatus status) => switch (status) {
    IssueStatus.reported => reported,
    IssueStatus.inProgress => inProgress,
    IssueStatus.resolved => resolved,
    IssueStatus.reopened => reopened,
  };

  @override
  List<Object?> get props => [
    reported,
    inProgress,
    resolved,
    reopened,
    total,
    open,
    urgent,
    unassigned,
    assignedToMe,
    createdLast24h,
    resolvedThisWeek,
    avgResolutionHours,
    openByCategory,
  ];
}

/// An admin who can be assigned issues.
class StaffMember extends Equatable {
  const StaffMember({required this.id, required this.displayName});

  final String id;
  final String displayName;

  @override
  List<Object?> get props => [id, displayName];
}

typedef PhotoRef = ({String url, Map<String, String> headers});

/// Contract for issue persistence. Implementations throw [Failure]s.
abstract interface class IssueRepository {
  /// Uploads photos, then creates the issue document and its `created`
  /// history entry. Cleans up uploaded photos if the document write fails.
  Future<Issue> createIssue(NewIssueInput input);

  /// Live feed, newest first, limited to [limit] documents.
  Stream<List<Issue>> watchIssues({
    IssueFilter filter = const IssueFilter(),
    int limit,
  });

  Stream<Issue> watchIssue(String issueId);

  Stream<List<IssueUpdate>> watchUpdates(String issueId);

  /// Where to load a stored photo from, with the headers it needs.
  PhotoRef photo(String photoPath);

  // ---------- admin operations (rules: admins of the same campus) ----------

  /// Moves the issue from [from] to [to] and appends a history entry in
  /// one batch. Throws [ValidationFailure] for transitions not allowed by
  /// [IssueStatus.canTransitionTo]. When resolving, a non-empty [note] is
  /// also stored as the resolution note.
  Future<void> updateStatus(
    String issueId, {
    required IssueStatus from,
    required IssueStatus to,
    String? note,
  });

  Future<void> updatePriority(
    String issueId, {
    required IssuePriority from,
    required IssuePriority to,
  });

  /// Assigns the issue to the signed-in admin.
  Future<void> assignToMe(String issueId);

  /// Uploads resolution photos, then appends their paths to the issue.
  /// [existingCount] is how many resolution photos the issue already has
  /// (the total is capped). Uploads are removed if the write fails.
  Future<void> addResolutionPhotos(
    String issueId,
    List<String> localPaths, {
    int existingCount = 0,
  });

  /// Number of campus issues, optionally with [status].
  Future<int> countIssues({IssueStatus? status});

  /// Dashboard aggregates. With [mine], only the caller's own reports
  /// (allowed for students); otherwise campus-wide (admins only).
  Future<IssueStats> stats({bool mine = false});

  /// Live variant of [stats]: polls, and refreshes after local writes.
  Stream<IssueStats> watchStats({bool mine = false});

  /// Admins who can be assigned issues.
  Future<List<StaffMember>> listStaff();

  /// Says "me too" (or takes it back). Not allowed for the reporter or on
  /// resolved issues; returns the updated issue.
  Future<Issue> setUpvote(String issueId, {required bool upvoted});

  /// Assigns to [staffId], or unassigns when null. Admins only.
  Future<void> assignTo(String issueId, String? staffId);
}
