import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/error_mapper.dart';
import '../../domain/entities/issue.dart';
import '../../domain/repositories/issue_repository.dart';

final class UpvoteState extends Equatable {
  const UpvoteState({
    required this.upvoted,
    required this.count,
    this.busy = false,
    this.message,
  });

  final bool upvoted;
  final int count;

  /// A request is in flight; further taps are ignored.
  final bool busy;

  /// User-safe error text for the last failed attempt.
  final String? message;

  UpvoteState copyWith({
    bool? upvoted,
    int? count,
    bool? busy,
    String? Function()? message,
  }) => UpvoteState(
    upvoted: upvoted ?? this.upvoted,
    count: count ?? this.count,
    busy: busy ?? this.busy,
    message: message != null ? message() : this.message,
  );

  @override
  List<Object?> get props => [upvoted, count, busy, message];
}

/// "Me too" for one issue. Flips instantly and rolls back with a message if
/// the server refuses, so the button feels immediate even on slow Wi-Fi.
class UpvoteCubit extends Cubit<UpvoteState> {
  UpvoteCubit({required this._repository, required Issue issue})
    : issueId = issue.id,
      super(UpvoteState(upvoted: issue.upvotedByMe, count: issue.upvoteCount));

  final IssueRepository _repository;
  final String issueId;

  /// Adopts the latest values from the live issue, unless a tap is pending
  /// (the pending result will carry the authoritative numbers).
  void sync(Issue issue) {
    if (state.busy) return;
    if (issue.upvotedByMe == state.upvoted &&
        issue.upvoteCount == state.count) {
      return;
    }
    emit(state.copyWith(upvoted: issue.upvotedByMe, count: issue.upvoteCount));
  }

  Future<void> toggle() async {
    if (state.busy) return;
    final before = state;
    final next = !before.upvoted;
    emit(
      before.copyWith(
        upvoted: next,
        count: (before.count + (next ? 1 : -1)).clamp(0, 1 << 30),
        busy: true,
        message: () => null,
      ),
    );
    try {
      final issue = await _repository.setUpvote(issueId, upvoted: next);
      if (isClosed) return;
      emit(UpvoteState(upvoted: issue.upvotedByMe, count: issue.upvoteCount));
    } catch (e, st) {
      if (isClosed) return;
      emit(
        before.copyWith(
          busy: false,
          message: () => mapException(e, st).message,
        ),
      );
    }
  }

  void messageShown() => emit(state.copyWith(message: () => null));
}
