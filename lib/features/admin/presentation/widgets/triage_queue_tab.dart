import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/routes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/ds/ds.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../reports/domain/entities/issue.dart';
import '../../../reports/domain/entities/issue_enums.dart';
import '../../../reports/domain/repositories/issue_repository.dart';
import '../../../reports/presentation/bloc/issue_list_bloc.dart';
import '../bloc/admin_dashboard_cubit.dart';
import 'admin_format.dart';
import 'update_issue_sheet.dart';

/// Filters the Overview tiles can open the queue with.
enum QueuePreset {
  mine,
  unassigned,
  urgent;

  IssueFilter get filter => switch (this) {
    mine => const IssueFilter(openOnly: true, assignedToMe: true),
    unassigned => queueDefaultFilter,
    urgent => const IssueFilter(openOnly: true, priority: IssuePriority.urgent),
  };
}

/// The queue's starting filter: open, unassigned, newest first.
const queueDefaultFilter = IssueFilter(openOnly: true, assigned: false);

/// Design screen 11 ("Needs triage"). Expects an [IssueListBloc] subscribed
/// to an open-only filter and an [AdminDashboardCubit] (for the counts).
class TriageQueueTab extends StatefulWidget {
  const TriageQueueTab({super.key});

  @override
  State<TriageQueueTab> createState() => _TriageQueueTabState();
}

class _TriageQueueTabState extends State<TriageQueueTab> {
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

  Future<void> _refresh() async {
    final bloc = context.read<IssueListBloc>();
    final previous = bloc.state.issues;
    bloc.add(const IssueListRefreshRequested());
    await context.read<AdminDashboardCubit>().refresh();
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
    final stats = context.select((AdminDashboardCubit c) => c.state.stats);
    final filter = context.select((IssueListBloc b) => b.state.filter);
    final bloc = context.read<IssueListBloc>();
    void update(IssueFilter Function(IssueFilter) f) =>
        bloc.add(IssueListFilterChanged(f));

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          DsPageHeader(
            title: filter.assignedToMe ? 'My tasks' : 'Needs triage',
            subtitle: stats == null
                ? 'Open issues'
                : filter.assignedToMe
                ? '${stats.assignedToMe} open '
                      '${stats.assignedToMe == 1 ? 'issue' : 'issues'} '
                      'assigned to you'
                : '${stats.unassigned} unassigned '
                      '${stats.unassigned == 1 ? 'issue' : 'issues'}',
            trailing: _FilterButton(
              active: filter.category != null,
              onPressed: () => _showCategoryFilter(context, filter.category),
            ),
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.gutter),
            child: Row(
              children: [
                DsChip(
                  label: 'My tasks',
                  count: stats?.assignedToMe,
                  selected: filter.assignedToMe,
                  onTap: () => update(
                    (f) => f.copyWith(
                      assignedToMe: !f.assignedToMe,
                      assigned: () => null,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                DsChip(
                  label: 'Unassigned',
                  selected: filter.assigned == false,
                  onTap: () => update(
                    (f) => f.copyWith(
                      assigned: () => f.assigned == false ? null : false,
                      assignedToMe: false,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                DsChip(
                  label: 'Urgent',
                  count: stats?.urgent,
                  selected: filter.priority == IssuePriority.urgent,
                  onTap: () => update(
                    (f) => f.copyWith(
                      priority: () => f.priority == IssuePriority.urgent
                          ? null
                          : IssuePriority.urgent,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                DsChip(
                  label: 'Oldest',
                  selected: filter.sort == IssueSort.oldest,
                  onTap: () => update(
                    (f) => f.copyWith(
                      sort: f.sort == IssueSort.oldest
                          ? IssueSort.newest
                          : IssueSort.oldest,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                DsChip(
                  label: 'Most reported',
                  selected: filter.sort == IssueSort.popular,
                  onTap: () => update(
                    (f) => f.copyWith(
                      sort: f.sort == IssueSort.popular
                          ? IssueSort.newest
                          : IssueSort.popular,
                    ),
                  ),
                ),
                if (filter.category case final c?) ...[
                  const SizedBox(width: 8),
                  DsChip(
                    label: '${c.label}  ✕',
                    selected: true,
                    onTap: () =>
                        update((f) => f.copyWith(category: () => null)),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: BlocBuilder<IssueListBloc, IssueListState>(
              builder: (context, state) => switch (state.status) {
                IssueListStatus.initial ||
                IssueListStatus.loading => const LoadingView(),
                IssueListStatus.failure => ErrorView(
                  message: state.message ?? 'Could not load the queue.',
                  onRetry: () => bloc.add(IssueListSubscribed(state.filter)),
                ),
                IssueListStatus.loaded => RefreshIndicator(
                  onRefresh: _refresh,
                  child: state.isEmpty
                      ? LayoutBuilder(
                          builder: (context, constraints) =>
                              SingleChildScrollView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                child: SizedBox(
                                  height: constraints.maxHeight,
                                  child: EmptyView(
                                    icon: Icons.task_alt,
                                    message: state.filter.assignedToMe
                                        ? 'Nothing assigned to you right now. '
                                              'Assign an issue to yourself '
                                              'and it shows up here.'
                                        : 'Nothing to triage here. '
                                              'Try another filter.',
                                  ),
                                ),
                              ),
                        )
                      : ListView.separated(
                          controller: _scroll,
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                          itemCount:
                              state.issues.length + (state.hasMore ? 1 : 0),
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, i) => i == state.issues.length
                              ? const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: LoadingView(),
                                )
                              : QueueCard(issue: state.issues[i]),
                        ),
                ),
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showCategoryFilter(
    BuildContext context,
    IssueCategory? current,
  ) async {
    final bloc = context.read<IssueListBloc>();
    final picked = await showModalBottomSheet<_CategoryChoice>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.gutter,
            0,
            AppSizes.gutter,
            20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Filter by category',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  DsChip(
                    label: 'All categories',
                    selected: current == null,
                    onTap: () =>
                        Navigator.of(context).pop(const _CategoryChoice(null)),
                  ),
                  for (final c in IssueCategory.values)
                    DsChip(
                      label: c.label,
                      selected: current == c,
                      onTap: () =>
                          Navigator.of(context).pop(_CategoryChoice(c)),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (picked == null) return;
    bloc.add(
      IssueListFilterChanged((f) => f.copyWith(category: () => picked.value)),
    );
  }
}

class _CategoryChoice {
  const _CategoryChoice(this.value);

  final IssueCategory? value;
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.active, required this.onPressed});

  final bool active;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      CircleIconButton(
        icon: Icons.filter_list,
        tooltip: active ? 'Category filter (on)' : 'Filter by category',
        onPressed: onPressed,
      ),
      if (active)
        const Positioned(
          top: 10,
          right: 10,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.orange,
                shape: BoxShape.circle,
                border: Border.fromBorderSide(
                  BorderSide(color: AppColors.white, width: 2),
                ),
              ),
              child: SizedBox.square(dimension: 10),
            ),
          ),
        ),
    ],
  );
}

/// One triage card: priority colour, code · age, title, location and an
/// "Assign" button that opens the update sheet on the assignment section.
class QueueCard extends StatelessWidget {
  const QueueCard({super.key, required this.issue});

  final Issue issue;

  @override
  Widget build(BuildContext context) {
    final pill = issue.priority.pill;
    return Material(
      color: issue.priority.cardColor,
      borderRadius: BorderRadius.circular(AppRadii.card),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(Routes.adminIssueDetails(issue.id)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    height: 26,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: pill.background,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Text(
                      issue.priority.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: pill.foreground,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${issue.displayCode} · '
                    '${AdminFormat.age(issue.createdAt)}'
                    '${issue.upvoteCount > 0 ? ' · ${issue.upvoteCount} me too' : ''}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textStrong,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          issue.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          AdminFormat.location(issue),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textStrong,
                          ),
                        ),
                        if (issue.assignedTo != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Assigned to ${issue.assignedToName ?? 'staff'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: () => showUpdateIssueSheet(
                      context,
                      issue,
                      focus: UpdateSheetFocus.assignment,
                    ),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      textStyle: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: Text(
                      issue.assignedTo == null ? 'Assign' : 'Reassign',
                      semanticsLabel:
                          '${issue.assignedTo == null ? 'Assign' : 'Reassign'}'
                          ' ${issue.title}',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
