import '../entities/issue_feedback.dart';

/// Resolution feedback from an issue's reporter.
///
/// Implementations throw / emit `Failure`s (lib/core/errors/failures.dart).
abstract interface class FeedbackRepository {
  /// The signed-in user's feedback on [issueId], or null if none yet.
  /// Feedback is keyed by the reporter's uid (one per reporter per issue).
  Stream<IssueFeedback?> watchMyFeedback(String issueId);

  /// Creates the signed-in reporter's feedback. Can only be done once;
  /// [comment] is optional (trimmed, empty treated as null, max 500 chars).
  Future<void> submitFeedback(
    String issueId, {
    required bool stillExists,
    String? comment,
  });
}
