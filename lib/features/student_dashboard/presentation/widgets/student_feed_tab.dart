import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/routes.dart';
import '../../../../core/widgets/ds/ds.dart';
import '../../../../core/widgets/ds/ds_student.dart';
import '../../../../injection_container.dart';
import '../../../reports/domain/entities/issue_enums.dart';
import '../../../reports/domain/repositories/issue_repository.dart';
import '../../../reports/presentation/bloc/issue_list_bloc.dart';
import '../../../reports/presentation/widgets/issue_feed_view.dart';
import '../../../reports/presentation/widgets/student_issue_text.dart';

/// Campus feed (design screens 04 and 14). Owns its [IssueListBloc].
class StudentFeedTab extends StatelessWidget {
  const StudentFeedTab({super.key, this.searchFocus});

  /// Lets the shell focus the search field (Home search → Feed).
  final FocusNode? searchFocus;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) =>
        getIt<IssueListBloc>()..add(const IssueListSubscribed(IssueFilter())),
    child: _FeedView(searchFocus: searchFocus),
  );
}

/// The status chips: All · Open · In progress · Resolved.
enum _StatusOption {
  all('All'),
  open('Open'),
  inProgress('In progress'),
  resolved('Resolved');

  const _StatusOption(this.label);

  final String label;

  bool matches(IssueFilter f) => switch (this) {
    all => f.status == null && !f.openOnly,
    open => f.status == null && f.openOnly,
    inProgress => f.status == IssueStatus.inProgress,
    resolved => f.status == IssueStatus.resolved,
  };

  IssueFilter apply(IssueFilter f) => switch (this) {
    all => f.copyWith(status: () => null, openOnly: false),
    open => f.copyWith(status: () => null, openOnly: true),
    inProgress => f.copyWith(
      status: () => IssueStatus.inProgress,
      openOnly: false,
    ),
    resolved => f.copyWith(status: () => IssueStatus.resolved, openOnly: false),
  };
}

class _FeedView extends StatefulWidget {
  const _FeedView({this.searchFocus});

  final FocusNode? searchFocus;

  @override
  State<_FeedView> createState() => _FeedViewState();
}

class _FeedViewState extends State<_FeedView> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  IssueListBloc get _bloc => context.read<IssueListBloc>();

  void _clearQuery() {
    _search.clear();
    _bloc.add(IssueListFilterChanged((f) => f.copyWith(query: () => null)));
  }

  void _clearAll() {
    _search.clear();
    _bloc.add(
      IssueListFilterChanged(
        (f) => f.copyWith(
          status: () => null,
          category: () => null,
          query: () => null,
          openOnly: false,
        ),
      ),
    );
  }

  Future<void> _openCategorySheet() async {
    final bloc = _bloc;
    final current = bloc.state.filter.category;
    // Returns a record so "All" (null) is distinguishable from dismissal.
    final picked = await showModalBottomSheet<({IssueCategory? category})>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.gutter,
            0,
            AppSizes.gutter,
            24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Filter by category',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  DsChip(
                    label: 'All',
                    selected: current == null,
                    onTap: () => Navigator.pop(context, (category: null)),
                  ),
                  for (final c in IssueCategory.values)
                    DsChip(
                      label: StudentIssueText.category(c),
                      selected: current == c,
                      onTap: () => Navigator.pop(context, (category: c)),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (picked == null) return;
    bloc.add(IssueListCategoryFilterChanged(picked.category));
  }

  @override
  Widget build(BuildContext context) {
    final filter = context.select((IssueListBloc b) => b.state.filter);
    final emptyNarrowed = context.select(
      (IssueListBloc b) => b.state.isEmpty && b.state.filter.isNarrowed,
    );
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DsPageHeader(
            title: 'Campus feed',
            subtitle: 'Reported issues on ADIT Campus',
            trailing: CircleIconButton(
              icon: Icons.filter_list,
              tooltip: filter.category == null
                  ? 'Filter by category'
                  : 'Filter by category '
                        '(${StudentIssueText.category(filter.category!)})',
              onPressed: _openCategorySheet,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.gutter,
              14,
              AppSizes.gutter,
              0,
            ),
            child: DsFocusableSearchField(
              hint: 'Search title, building, ID',
              controller: _search,
              focusNode: widget.searchFocus,
              onChanged: (text) => _bloc.add(IssueListQueryChanged(text)),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: AppSizes.chip,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSizes.gutter),
              children: emptyNarrowed
                  ? _removableChips(filter)
                  : _statusChips(filter),
            ),
          ),
          Expanded(
            child: IssueFeedList(
              emptyBuilder: (context) => LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: SizedBox(
                    height: constraints.maxHeight,
                    child: filter.isNarrowed
                        ? DsMessageState(
                            ringLabel: '0',
                            title: _emptyTitle(filter),
                            message:
                                "That's good news. Try a wider filter to "
                                'see more.',
                            actionLabel: 'Clear filters',
                            onAction: _clearAll,
                          )
                        : DsMessageState(
                            ringLabel: '0',
                            title: 'No issues yet',
                            message:
                                'Nothing has been reported on campus. '
                                'Spot a problem? Report it.',
                            actionLabel: 'Report an issue',
                            onAction: () => context.push(Routes.report),
                          ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _statusChips(IssueFilter filter) => [
    if (filter.category != null) ...[
      DsRemovableChip(
        label: StudentIssueText.category(filter.category!),
        onRemove: () => _bloc.add(const IssueListCategoryFilterChanged(null)),
      ),
      const SizedBox(width: 8),
    ],
    for (final option in _StatusOption.values) ...[
      if (option != _StatusOption.all) const SizedBox(width: 8),
      DsChip(
        label: option.label,
        selected: option.matches(filter),
        onTap: () => _bloc.add(IssueListFilterChanged(option.apply)),
      ),
    ],
  ];

  List<Widget> _removableChips(IssueFilter filter) {
    final chips = <Widget>[
      if (filter.category != null)
        DsRemovableChip(
          label: StudentIssueText.category(filter.category!),
          onRemove: () => _bloc.add(const IssueListCategoryFilterChanged(null)),
        ),
      if (filter.status != null || filter.openOnly)
        DsRemovableChip(
          label: filter.status?.label ?? 'Open',
          onRemove: () =>
              _bloc.add(IssueListFilterChanged(_StatusOption.all.apply)),
        ),
      if (filter.query?.trim().isNotEmpty ?? false)
        DsRemovableChip(label: '“${filter.query}”', onRemove: _clearQuery),
    ];
    return [
      for (var i = 0; i < chips.length; i++) ...[
        if (i > 0) const SizedBox(width: 8),
        chips[i],
      ],
    ];
  }

  static String _emptyTitle(IssueFilter f) {
    final words = [
      if (f.status != null)
        f.status!.label.toLowerCase()
      else if (f.openOnly)
        'open',
      if (f.category != null) StudentIssueText.categoryInSentence(f.category!),
    ];
    final query = f.query?.trim();
    final suffix = query == null || query.isEmpty ? '' : ' matching “$query”';
    return words.isEmpty
        ? 'No issues$suffix'
        : 'No ${words.join(' ')} issues$suffix';
  }
}
