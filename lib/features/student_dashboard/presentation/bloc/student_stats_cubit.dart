import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/error_mapper.dart';
import '../../../reports/domain/repositories/issue_repository.dart';

enum StudentStatsStatus { loading, loaded, failure }

final class StudentStatsState extends Equatable {
  const StudentStatsState({
    this.status = StudentStatsStatus.loading,
    this.stats,
    this.message,
  });

  final StudentStatsStatus status;

  /// Last known stats; kept while a later poll fails.
  final IssueStats? stats;
  final String? message;

  @override
  List<Object?> get props => [status, stats, message];
}

/// Live aggregates for the signed-in student's own reports ("My reports"
/// stats card). Only ever calls the repository with `mine: true`.
class StudentStatsCubit extends Cubit<StudentStatsState> {
  StudentStatsCubit({required this._repository})
    : super(const StudentStatsState());

  final IssueRepository _repository;
  StreamSubscription<IssueStats>? _sub;

  void start() {
    _sub?.cancel();
    emit(StudentStatsState(stats: state.stats));
    _sub = _repository
        .watchStats(mine: true)
        .listen(
          (stats) => emit(
            StudentStatsState(status: StudentStatsStatus.loaded, stats: stats),
          ),
          onError: (Object e, StackTrace st) => emit(
            StudentStatsState(
              status: StudentStatsStatus.failure,
              stats: state.stats,
              message: mapException(e, st).message,
            ),
          ),
        );
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}
