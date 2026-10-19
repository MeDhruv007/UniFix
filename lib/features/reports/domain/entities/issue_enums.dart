/// Stored values are stable machine strings; [label]s are for display only.
enum IssueStatus {
  reported('reported', 'Reported'),
  inProgress('inProgress', 'In progress'),
  resolved('resolved', 'Resolved'),
  reopened('reopened', 'Reopened');

  const IssueStatus(this.value, this.label);

  final String value;
  final String label;

  static IssueStatus fromValue(String? value) => values.firstWhere(
    (s) => s.value == value,
    orElse: () => IssueStatus.reported,
  );

  /// Status transitions an admin may perform (doc §7).
  ///
  /// Mirrored by the API server (docs/API.md); keep both in sync.
  static const Map<IssueStatus, Set<IssueStatus>> _transitions = {
    reported: {inProgress},
    inProgress: {resolved},
    resolved: {reopened},
    reopened: {inProgress, resolved},
  };

  Set<IssueStatus> get nextStatuses => _transitions[this] ?? const {};

  bool canTransitionTo(IssueStatus next) => nextStatuses.contains(next);

  bool get isOpen => this != IssueStatus.resolved;
}

enum IssuePriority {
  low('low', 'Low'),
  medium('medium', 'Medium'),
  high('high', 'High'),
  urgent('urgent', 'Urgent');

  const IssuePriority(this.value, this.label);

  final String value;
  final String label;

  static IssuePriority fromValue(String? value) => values.firstWhere(
    (p) => p.value == value,
    orElse: () => IssuePriority.medium,
  );
}

enum IssueCategory {
  electrical('electrical', 'Electrical'),
  plumbing('plumbing', 'Plumbing'),
  cleanliness('cleanliness', 'Cleanliness'),
  furniture('furniture', 'Furniture'),
  it('it', 'IT / Network'),
  safety('safety', 'Safety'),
  other('other', 'Other');

  const IssueCategory(this.value, this.label);

  final String value;
  final String label;

  static IssueCategory fromValue(String? value) => values.firstWhere(
    (c) => c.value == value,
    orElse: () => IssueCategory.other,
  );

  /// How much a photo helps staff with this kind of problem. Photos are
  /// never mandatory; this only drives hints and a confirmation prompt.
  PhotoGuidance get photoGuidance => switch (this) {
    safety || plumbing || furniture || cleanliness => PhotoGuidance.recommended,
    electrical => PhotoGuidance.helpful,
    it || other => PhotoGuidance.optional,
  };

  /// What to photograph, shown under the photo picker.
  String get photoTip => switch (this) {
    safety => 'A photo helps staff judge the risk quickly. Take it from a safe distance.',
    plumbing => 'Show the leak, blockage or damaged fitting.',
    furniture => 'Show the broken part of the furniture, door or window.',
    cleanliness => 'Show the area that needs cleaning.',
    electrical =>
      'Photograph the fitting, switch or panel. Do not touch exposed wires.',
    it => 'Optional: a photo of the error screen or equipment label helps.',
    other => 'Optional: add a photo if it helps explain the problem.',
  };
}

enum PhotoGuidance {
  /// Staff usually need to see it; submitting without asks for confirmation.
  recommended('Photo recommended'),

  /// Useful but often describable in words.
  helpful('Photo helpful'),

  /// Text is usually enough.
  optional('Photo optional');

  const PhotoGuidance(this.label);

  final String label;
}

enum IssueUpdateAction {
  created('created'),
  statusChanged('statusChanged'),
  priorityChanged('priorityChanged'),
  assigned('assigned'),
  commented('commented'),
  reopened('reopened');

  const IssueUpdateAction(this.value);

  final String value;

  static IssueUpdateAction fromValue(String? value) => values.firstWhere(
    (a) => a.value == value,
    orElse: () => IssueUpdateAction.commented,
  );
}
