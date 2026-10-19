import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/widgets/ds/ds.dart';
import '../../../../core/widgets/ds/ds_student.dart';
import '../../../../core/widgets/state_views.dart';
import '../../domain/entities/issue.dart';
import '../../domain/entities/issue_enums.dart';
import '../bloc/issue_list_bloc.dart';
import 'issue_card.dart';
import 'student_issue_text.dart';

/// Filterable, paginated live list with a compact status/category filter
/// bar. Expects an [IssueListBloc] above it.
class IssueFeedView extends StatelessWidget {
  const IssueFeedView({super.key, required this.emptyMessage});

  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _FilterBar(),
        Expanded(
          child: IssueFeedList(
            emptyBuilder: (context) => LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: SizedBox(
                  height: constraints.maxHeight,
                  child: DsMessageState(
                    ringLabel: '0',
                    title: 'Nothing here',
                    message: emptyMessage,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The scrolling part of a feed: loading / error / empty / list states,
/// pull-to-refresh and infinite scroll. Expects an [IssueListBloc] above.
class IssueFeedList extends StatefulWidget {
  const IssueFeedList({
    super.key,
    required this.emptyBuilder,
    this.padding = const EdgeInsets.fromLTRB(16, 14, 16, 24),
    this.itemBuilder,
  });

  /// Shown when the loaded list is empty. Should be scrollable (or fill
  /// the space) so pull-to-refresh still works.
  final WidgetBuilder emptyBuilder;
  final EdgeInsets padding;

  /// Builds each row; defaults to [IssueCard].
  final Widget Function(BuildContext context, Issue issue, int index)?
  itemBuilder;

  @override
  State<IssueFeedList> createState() => _IssueFeedListState();
}

class _IssueFeedListState extends State<IssueFeedList> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 400) {
        context.read<IssueListBloc>().add(const IssueListLoadMoreRequested());
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Completes when the re-fetch lands (or fails), capped so the spinner
  /// never hangs on a slow network.
  Future<void> _refresh(IssueListBloc bloc) async {
    final previous = bloc.state.issues;
    bloc.add(const IssueListRefreshRequested());
    try {
      await bloc.stream
          .firstWhere(
            (s) =>
                s.status == IssueListStatus.failure ||
                (s.status == IssueListStatus.loaded && s.issues != previous),
          )
          .timeout(const Duration(seconds: 3));
    } catch (_) {
      // Unchanged data or timeout: just stop the spinner.
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<IssueListBloc, IssueListState>(
      builder: (context, state) {
        switch (state.status) {
          case IssueListStatus.initial || IssueListStatus.loading:
            return const LoadingView();
          case IssueListStatus.failure:
            return DsMessageState(
              icon: Icons.cloud_off_outlined,
              title: 'Could not load issues',
              message: state.message ?? 'Check your connection and try again.',
              actionLabel: 'Try again',
              onAction: () => context.read<IssueListBloc>().add(
                IssueListSubscribed(state.filter),
              ),
            );
          case IssueListStatus.loaded:
            return RefreshIndicator(
              onRefresh: () => _refresh(context.read<IssueListBloc>()),
              child: state.isEmpty
                  ? widget.emptyBuilder(context)
                  : ListView.separated(
                      controller: _scroll,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: widget.padding,
                      itemCount: state.issues.length + (state.hasMore ? 1 : 0),
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, i) => i == state.issues.length
                          ? const Padding(
                              padding: EdgeInsets.all(16),
                              child: LoadingView(),
                            )
                          : widget.itemBuilder?.call(
                                  context,
                                  state.issues[i],
                                  i,
                                ) ??
                                IssueCard(issue: state.issues[i]),
                    ),
            );
        }
      },
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar();

  @override
  Widget build(BuildContext context) {
    final filter = context.select((IssueListBloc b) => b.state.filter);
    final bloc = context.read<IssueListBloc>();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          _Dropdown<IssueStatus>(
            label: 'Status',
            value: filter.status,
            items: IssueStatus.values,
            labelOf: (s) => s.label,
            onChanged: (s) => bloc.add(IssueListStatusFilterChanged(s)),
          ),
          const SizedBox(width: 8),
          _Dropdown<IssueCategory>(
            label: 'Category',
            value: filter.category,
            items: IssueCategory.values,
            labelOf: StudentIssueText.category,
            onChanged: (c) => bloc.add(IssueListCategoryFilterChanged(c)),
          ),
        ],
      ),
    );
  }
}

/// A chip that opens a menu; "All …" clears the value.
class _Dropdown<T> extends StatelessWidget {
  const _Dropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.labelOf,
    required this.onChanged,
  });

  final String label;
  final T? value;
  final List<T> items;
  final String Function(T) labelOf;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    final current = value;
    return MenuAnchor(
      menuChildren: [
        MenuItemButton(
          onPressed: () => onChanged(null),
          child: Text('All ${label.toLowerCase()}'),
        ),
        for (final item in items)
          MenuItemButton(
            onPressed: () => onChanged(item),
            leadingIcon: item == current
                ? const Icon(Icons.check, size: 18)
                : null,
            child: Text(labelOf(item)),
          ),
      ],
      builder: (context, controller, _) => DsChip(
        label: current == null ? '$label ▾' : labelOf(current),
        selected: current != null,
        onTap: () => controller.isOpen ? controller.close() : controller.open(),
      ),
    );
  }
}
