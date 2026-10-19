import 'package:equatable/equatable.dart';

/// A reporter's verdict on a resolved issue. One per reporter per issue;
/// immutable once written.
class IssueFeedback extends Equatable {
  const IssueFeedback({
    required this.reporterId,
    required this.stillExists,
    this.comment,
    this.createdAt,
  });

  final String reporterId;

  /// True when the reporter says the problem was not actually fixed.
  final bool stillExists;
  final String? comment;

  /// Null only briefly, while the server timestamp is pending.
  final DateTime? createdAt;

  @override
  List<Object?> get props => [reporterId, stillExists, comment, createdAt];
}
