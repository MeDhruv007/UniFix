import 'package:equatable/equatable.dart';

import 'issue_enums.dart';

/// One append-only entry in an issue's history timeline.
class IssueUpdate extends Equatable {
  const IssueUpdate({
    required this.id,
    required this.actorId,
    required this.action,
    this.oldStatus,
    this.newStatus,
    this.oldPriority,
    this.newPriority,
    this.note,
    this.actorName,
    this.createdAt,
  });

  final String id;
  final String actorId;
  final IssueUpdateAction action;
  final IssueStatus? oldStatus;
  final IssueStatus? newStatus;
  final IssuePriority? oldPriority;
  final IssuePriority? newPriority;
  final String? note;

  /// Display name of the actor, when the server provides it.
  final String? actorName;
  final DateTime? createdAt;

  @override
  List<Object?> get props => [
    id,
    actorId,
    action,
    oldStatus,
    newStatus,
    oldPriority,
    newPriority,
    note,
    actorName,
    createdAt,
  ];
}
