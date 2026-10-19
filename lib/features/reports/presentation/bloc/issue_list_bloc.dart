import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/error_mapper.dart';
import '../../domain/entities/issue.dart';
import '../../domain/entities/issue_enums.dart';
import '../../domain/repositories/issue_repository.dart';

// ---------- events ----------
sealed class IssueListEvent extends Equatable {
  const IssueListEvent();

  @override
  List<Object?> get props => [];
}

/// (Re)subscribes with [filter]. Replaces any previous subscription.
final class IssueListSubscribed extends IssueListEvent {
  const IssueListSubscribed(this.filter);

  final IssueFilter filter;

  @override
  List<Object?> get props => [filter];
}

final class IssueListStatusFilterChanged extends IssueListEvent {
  const IssueListStatusFilterChanged(this.status);

  final IssueStatus? status;

  @override
  List<Object?> get props => [status];
}

final class IssueListCategoryFilterChanged extends IssueListEvent {
  const IssueListCategoryFilterChanged(this.category);

  final IssueCategory? category;

  @override
  List<Object?> get props => [category];
}

/// Applies an arbitrary filter change, e.g.
/// `IssueListFilterChanged((f) => f.copyWith(openOnly: true))`.
final class IssueListFilterChanged extends IssueListEvent {
  const IssueListFilterChanged(this.update);

  final IssueFilter Function(IssueFilter current) update;

  @override
  List<Object?> get props => [update];
}

/// Search text changed; applied after [debounce] of no further typing.
final class IssueListQueryChanged extends IssueListEvent {
  const IssueListQueryChanged(
    this.query, {
    this.debounce = const Duration(milliseconds: 350),
  });

  final String query;
  final Duration debounce;

  @override
  List<Object?> get props => [query, debounce];
}

final class IssueListLoadMoreRequested extends IssueListEvent {
  const IssueListLoadMoreRequested();
}

/// Pull-to-refresh: re-fetches now with the current filter and page size.
final class IssueListRefreshRequested extends IssueListEvent {
  const IssueListRefreshRequested();
}

// ---------- state ----------
enum IssueListStatus { initial, loading, loaded, failure }

final class IssueListState extends Equatable {
  const IssueListState({
    this.status = IssueListStatus.initial,
    this.issues = const [],
    this.filter = const IssueFilter(),
    this.limit = AppConstants.feedPageSize,
    this.message,
  });

  final IssueListStatus status;
  final List<Issue> issues;
  final IssueFilter filter;
  final int limit;
  final String? message;

  bool get isEmpty => status == IssueListStatus.loaded && issues.isEmpty;

  /// A full page came back, so there may be more.
  bool get hasMore => issues.length >= limit;

  IssueListState copyWith({
    IssueListStatus? status,
    List<Issue>? issues,
    IssueFilter? filter,
    int? limit,
    String? Function()? message,
  }) => IssueListState(
    status: status ?? this.status,
    issues: issues ?? this.issues,
    filter: filter ?? this.filter,
    limit: limit ?? this.limit,
    message: message != null ? message() : this.message,
  );

  @override
  List<Object?> get props => [status, issues, filter, limit, message];
}

// ---------- bloc ----------
class IssueListBloc extends Bloc<IssueListEvent, IssueListState> {
  IssueListBloc({required this._repository}) : super(const IssueListState()) {
    // restartable(): a new query cancels the previous polling stream.
    on<_Watch>(_onWatch, transformer: restartable());
    on<IssueListSubscribed>(
      (e, _) => add(_Watch(e.filter, AppConstants.feedPageSize)),
    );
    // Filter edits keep every other filter field (search, triage, owner).
    on<IssueListStatusFilterChanged>(
      (e, _) => _refilter(state.filter.copyWith(status: () => e.status)),
    );
    on<IssueListCategoryFilterChanged>(
      (e, _) => _refilter(state.filter.copyWith(category: () => e.category)),
    );
    on<IssueListFilterChanged>((e, _) => _refilter(e.update(state.filter)));
    // Debounced: typing restarts the timer; only the last query is sent.
    on<IssueListQueryChanged>((e, _) async {
      await Future<void>.delayed(e.debounce);
      final query = e.query.trim();
      _refilter(
        state.filter.copyWith(query: () => query.isEmpty ? null : query),
      );
    }, transformer: restartable());
    on<IssueListLoadMoreRequested>((_, _) {
      if (state.status != IssueListStatus.loaded || !state.hasMore) return;
      add(_Watch(state.filter, state.limit + AppConstants.feedPageSize));
    });
    // Restarting the watch fetches immediately; items stay visible meanwhile.
    on<IssueListRefreshRequested>(
      (_, _) => add(_Watch(state.filter, state.limit)),
    );
  }

  final IssueRepository _repository;

  void _refilter(IssueFilter filter) {
    if (filter == state.filter) return;
    add(_Watch(filter, AppConstants.feedPageSize));
  }

  Future<void> _onWatch(_Watch event, Emitter<IssueListState> emit) {
    final filterChanged = event.filter != state.filter;
    emit(
      state.copyWith(
        // Keep current items visible while paging; clear on new filter.
        status: filterChanged || state.status != IssueListStatus.loaded
            ? IssueListStatus.loading
            : state.status,
        issues: filterChanged ? const [] : state.issues,
        filter: event.filter,
        limit: event.limit,
        message: () => null,
      ),
    );
    return emit.forEach<List<Issue>>(
      _repository.watchIssues(filter: event.filter, limit: event.limit),
      onData: (issues) => state.copyWith(
        status: IssueListStatus.loaded,
        issues: issues,
        message: () => null,
      ),
      onError: (e, st) => state.copyWith(
        status: IssueListStatus.failure,
        message: () => mapException(e, st).message,
      ),
    );
  }
}

final class _Watch extends IssueListEvent {
  const _Watch(this.filter, this.limit);

  final IssueFilter filter;
  final int limit;

  @override
  List<Object?> get props => [filter, limit];
}
