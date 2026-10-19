import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/widgets/ds/ds.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../reports/domain/entities/issue_enums.dart';
import '../../../reports/domain/repositories/issue_repository.dart';
import '../bloc/admin_dashboard_cubit.dart';
import 'admin_format.dart';
import 'triage_queue_tab.dart';

/// Design screen 10: greeting, open-issues hero, stat tiles and the
/// "Open by category" bars. Expects an [AdminDashboardCubit] above it.
class AdminOverviewTab extends StatelessWidget {
  const AdminOverviewTab({super.key, required this.onOpenQueue});

  /// Opens the Queue tab with a preset filter (Urgent / Unassigned tiles).
  final ValueChanged<QueuePreset> onOpenQueue;

  @override
  Widget build(BuildContext context) {
    final user = context.select((AuthBloc b) => b.state.user);
    return SafeArea(
      bottom: false,
      child: BlocBuilder<AdminDashboardCubit, AdminDashboardState>(
        builder: (context, state) {
          final cubit = context.read<AdminDashboardCubit>();
          final stats = state.stats;
          final header = _Header(name: user?.displayName, avatar: user?.avatar);
          if (stats == null) {
            return Column(
              children: [
                header,
                Expanded(
                  child: state.status == AdminDashboardStatus.failure
                      ? ErrorView(
                          message:
                              state.message ?? 'Could not load statistics.',
                          onRetry: cubit.start,
                        )
                      : const LoadingView(),
                ),
              ],
            );
          }
          return RefreshIndicator(
            onRefresh: cubit.refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                header,
                if (state.status == AdminDashboardStatus.failure)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSizes.gutter,
                      12,
                      AppSizes.gutter,
                      0,
                    ),
                    child: InfoBanner(
                      background: AppColors.statusReported,
                      foreground: AppColors.ink,
                      icon: Icons.cloud_off_outlined,
                      message:
                          '${state.message ?? 'Could not refresh.'} '
                          'Showing the last numbers we loaded.',
                    ),
                  ),
                _Hero(stats: stats),
                _Tiles(stats: stats, onOpenQueue: onOpenQueue),
                _CategoryBars(counts: stats.openByCategory),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.name, this.avatar});

  final String? name;
  final String? avatar;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(AppSizes.gutter, 12, AppSizes.gutter, 0),
    child: Row(
      children: [
        avatar == null
            ? CodeAvatar(
                code: CodeAvatar.initialsOf(name),
                background: AppColors.ink,
                foreground: AppColors.white,
              )
            : UserAvatar(avatarId: avatar, name: name),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hello, ${AdminFormat.firstName(name)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Text(
                'Facilities admin · ADIT',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _Hero extends StatelessWidget {
  const _Hero({required this.stats});

  final IssueStats stats;

  @override
  Widget build(BuildContext context) {
    final fixed = stats.resolvedThisWeek;
    // Share of this week's workload (fixed + still open) that was fixed.
    final workload = fixed + stats.open;
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSizes.gutter,
        16,
        AppSizes.gutter,
        0,
      ),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.periwinkle,
        borderRadius: BorderRadius.circular(AppRadii.hero),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Semantics(
              label:
                  '${stats.open} open issues, '
                  '${stats.createdLast24h} new since yesterday',
              excludeSemantics: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Open issues',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textOnPeriwinkle,
                    ),
                  ),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${stats.open}',
                      style: const TextStyle(
                        fontSize: 56,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -2.24,
                        height: 1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '+${stats.createdLast24h} since yesterday',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textOnPeriwinkle,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ProgressRing(
                value: workload == 0 ? 0 : fixed / workload,
                label: '$fixed',
                size: 72,
                semanticsLabel: '$fixed fixed this week',
              ),
              const SizedBox(height: 6),
              const ExcludeSemantics(
                child: Text(
                  'fixed this week',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textOnPeriwinkle,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Tiles extends StatelessWidget {
  const _Tiles({required this.stats, required this.onOpenQueue});

  final IssueStats stats;
  final ValueChanged<QueuePreset> onOpenQueue;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(AppSizes.gutter, 8, AppSizes.gutter, 0),
    child: Column(
      children: [
        _StatTile(
          value: '${stats.assignedToMe}',
          label: 'My tasks · assigned to you',
          color: AppColors.periwinkle,
          hint: 'Show issues assigned to you',
          onTap: () => onOpenQueue(QueuePreset.mine),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _StatTile(
                value: '${stats.urgent}',
                label: 'Urgent',
                color: AppColors.orange,
                hint: 'Show urgent issues in the queue',
                onTap: () => onOpenQueue(QueuePreset.urgent),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatTile(
                value: '${stats.unassigned}',
                label: 'Unassigned',
                color: AppColors.pink,
                hint: 'Show unassigned issues in the queue',
                onTap: () => onOpenQueue(QueuePreset.unassigned),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _StatTile(
                value: AdminFormat.resolution(stats.avgResolutionHours),
                label: 'Avg. resolution',
                color: AppColors.surface,
                muted: true,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatTile(
                value: '${stats.reopened}',
                label: 'Reopened',
                color: AppColors.surface,
                muted: true,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.value,
    required this.label,
    required this.color,
    this.muted = false,
    this.hint,
    this.onTap,
  });

  final String value;
  final String label;
  final Color color;
  final bool muted;
  final String? hint;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      label: '$label: $value',
      hint: hint,
      excludeSemantics: true,
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(AppRadii.card),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        value,
                        maxLines: 1,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: muted ? AppColors.textStrong : AppColors.ink,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onTap != null)
                  const Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: AppColors.ink,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryBars extends StatelessWidget {
  const _CategoryBars({required this.counts});

  final Map<IssueCategory, int> counts;

  @override
  Widget build(BuildContext context) {
    final rows = counts.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final max = rows.isEmpty ? 0 : rows.first.value;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.gutter,
        18,
        AppSizes.gutter,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: const Text(
              'Open by category',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 10),
          if (rows.isEmpty)
            const Text(
              'No open issues right now.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            )
          else
            for (final e in rows) ...[
              _Bar(category: e.key, count: e.value, max: max),
              const SizedBox(height: 7),
            ],
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.category, required this.count, required this.max});

  final IssueCategory category;
  final int count;
  final int max;

  static const _labelStyle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
  );

  @override
  Widget build(BuildContext context) {
    final color = category.chartColor;
    final onColor = color == AppColors.ink ? AppColors.white : AppColors.ink;
    return Semantics(
      label: '${category.label}: $count open',
      excludeSemantics: true,
      child: Row(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final track = constraints.maxWidth;
                // Never narrower than its own label.
                final painter = TextPainter(
                  text: TextSpan(text: category.label, style: _labelStyle),
                  textDirection: TextDirection.ltr,
                  textScaler: MediaQuery.textScalerOf(context),
                  maxLines: 1,
                )..layout();
                final minWidth = painter.width + 24;
                painter.dispose();
                final width = (track * count / max).clamp(
                  minWidth.clamp(0.0, track),
                  track,
                );
                return Container(
                  height: 30,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: width,
                    height: 30,
                    padding: const EdgeInsets.only(left: 12),
                    alignment: Alignment.centerLeft,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Text(
                      category.label,
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      style: _labelStyle.copyWith(color: onColor),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 28,
            child: Text(
              '$count',
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
