import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/error_mapper.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/issue.dart';
import '../../domain/entities/issue_update.dart';
import '../../domain/repositories/issue_repository.dart';

enum IssueDetailsStatus { loading, loaded, notFound, failure }

final class IssueDetailsState extends Equatable {
  const IssueDetailsState({
    this.status = IssueDetailsStatus.loading,
    this.issue,
    this.updates = const [],
    this.message,
  });

  final IssueDetailsStatus status;
  final Issue? issue;
  final List<IssueUpdate> updates;
  final String? message;

  IssueDetailsState copyWith({
    IssueDetailsStatus? status,
    Issue? issue,
    List<IssueUpdate>? updates,
    String? message,
  }) => IssueDetailsState(
    status: status ?? this.status,
    issue: issue ?? this.issue,
    updates: updates ?? this.updates,
    message: message ?? this.message,
  );

  @override
  List<Object?> get props => [status, issue, updates, message];
}

/// Live issue document plus its history timeline.
class IssueDetailsCubit extends Cubit<IssueDetailsState> {
  IssueDetailsCubit({required this._repository, required this.issueId})
    : super(const IssueDetailsState());

  final IssueRepository _repository;
  final String issueId;
  StreamSubscription<Issue>? _issueSub;
  StreamSubscription<List<IssueUpdate>>? _updatesSub;

  void start() {
    _cancel();
    emit(const IssueDetailsState());
    _issueSub = _repository
        .watchIssue(issueId)
        .listen(
          (issue) => emit(
            state.copyWith(status: IssueDetailsStatus.loaded, issue: issue),
          ),
          onError: _onError,
        );
    _updatesSub = _repository
        .watchUpdates(issueId)
        .listen(
          (updates) => emit(state.copyWith(updates: updates)),
          // The timeline is secondary; keep showing the issue if it fails.
          onError: (Object _) {},
        );
  }

  void _onError(Object error, StackTrace stackTrace) {
    final failure = mapException(error, stackTrace);
    emit(
      state.copyWith(
        status: failure is NotFoundFailure
            ? IssueDetailsStatus.notFound
            : IssueDetailsStatus.failure,
        message: failure.message,
      ),
    );
  }

  void _cancel() {
    _issueSub?.cancel();
    _updatesSub?.cancel();
  }

  @override
  Future<void> close() {
    _cancel();
    return super.close();
  }
}
