import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/error_mapper.dart';
import '../../../reports/domain/repositories/issue_repository.dart';

enum AdminDashboardStatus { initial, loading, loaded, failure }

final class AdminDashboardState extends Equatable {
  const AdminDashboardState({
    this.status = AdminDashboardStatus.initial,
    this.stats,
    this.message,
  });

  final AdminDashboardStatus status;

  /// Last successfully loaded stats; kept while refreshing or on failure.
  final IssueStats? stats;
  final String? message;

  @override
  List<Object?> get props => [status, stats, message];
}

/// Campus-wide admin metrics (`IssueStats`). [start] keeps them live via
/// [IssueRepository.watchStats]; [refresh] fetches once (pull-to-refresh).
class AdminDashboardCubit extends Cubit<AdminDashboardState> {
  AdminDashboardCubit({required this._repository})
    : super(const AdminDashboardState());

  final IssueRepository _repository;
  StreamSubscription<IssueStats>? _sub;

  /// (Re)subscribes to live stats. Also used as "retry".
  void start() {
    _sub?.cancel();
    emit(
      AdminDashboardState(
        status: AdminDashboardStatus.loading,
        stats: state.stats,
      ),
    );
    _sub = _repository.watchStats().listen(
      (stats) => emit(
        AdminDashboardState(status: AdminDashboardStatus.loaded, stats: stats),
      ),
      onError: _onError,
    );
  }

  /// One-shot re-fetch. Completes when the request finishes.
  Future<void> refresh() async {
    try {
      final stats = await _repository.stats();
      if (isClosed) return;
      emit(
        AdminDashboardState(status: AdminDashboardStatus.loaded, stats: stats),
      );
    } catch (e, st) {
      _onError(e, st);
    }
  }

  void _onError(Object error, StackTrace stackTrace) {
    if (isClosed) return;
    emit(
      AdminDashboardState(
        status: AdminDashboardStatus.failure,
        stats: state.stats,
        message: mapException(error, stackTrace).message,
      ),
    );
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    return super.close();
  }
}
