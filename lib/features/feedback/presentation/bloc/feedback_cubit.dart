import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/error_mapper.dart';
import '../../domain/entities/issue_feedback.dart';
import '../../domain/repositories/feedback_repository.dart';

enum FeedbackStatus { loading, loaded, failure }

enum FeedbackSubmitStatus { idle, submitting, failure }

final class FeedbackState extends Equatable {
  const FeedbackState({
    this.status = FeedbackStatus.loading,
    this.feedback,
    this.submitStatus = FeedbackSubmitStatus.idle,
    this.message,
  });

  final FeedbackStatus status;

  /// The reporter's existing feedback; null when none has been given.
  final IssueFeedback? feedback;
  final FeedbackSubmitStatus submitStatus;

  /// User-safe error text for a load or submit failure.
  final String? message;

  bool get isSubmitting => submitStatus == FeedbackSubmitStatus.submitting;

  FeedbackState copyWith({
    FeedbackStatus? status,
    IssueFeedback? Function()? feedback,
    FeedbackSubmitStatus? submitStatus,
    String? Function()? message,
  }) => FeedbackState(
    status: status ?? this.status,
    feedback: feedback != null ? feedback() : this.feedback,
    submitStatus: submitStatus ?? this.submitStatus,
    message: message != null ? message() : this.message,
  );

  @override
  List<Object?> get props => [status, feedback, submitStatus, message];
}

/// The signed-in reporter's resolution feedback for one issue.
class FeedbackCubit extends Cubit<FeedbackState> {
  FeedbackCubit({required this._repository, required this.issueId})
    : super(const FeedbackState());

  final FeedbackRepository _repository;
  final String issueId;
  StreamSubscription<IssueFeedback?>? _sub;

  void start() {
    _sub?.cancel();
    emit(const FeedbackState());
    _sub = _repository
        .watchMyFeedback(issueId)
        .listen(
          (feedback) => emit(
            state.copyWith(
              status: FeedbackStatus.loaded,
              feedback: () => feedback,
            ),
          ),
          onError: (Object e, StackTrace st) => emit(
            state.copyWith(
              status: FeedbackStatus.failure,
              message: () => mapException(e, st).message,
            ),
          ),
        );
  }

  /// The live stream delivers the stored feedback once the write lands.
  Future<void> submit({required bool stillExists, String? comment}) async {
    if (state.isSubmitting || state.feedback != null) return;
    emit(
      state.copyWith(
        submitStatus: FeedbackSubmitStatus.submitting,
        message: () => null,
      ),
    );
    try {
      await _repository.submitFeedback(
        issueId,
        stillExists: stillExists,
        comment: comment,
      );
      emit(state.copyWith(submitStatus: FeedbackSubmitStatus.idle));
    } catch (e, st) {
      emit(
        state.copyWith(
          submitStatus: FeedbackSubmitStatus.failure,
          message: () => mapException(e, st).message,
        ),
      );
    }
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}
