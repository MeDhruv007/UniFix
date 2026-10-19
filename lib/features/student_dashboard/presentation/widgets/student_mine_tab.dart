import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/routes.dart';
import '../../../../core/widgets/ds/ds.dart';
import '../../../../core/widgets/ds/ds_student.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../injection_container.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../reports/domain/entities/issue_enums.dart';
import '../../../reports/domain/repositories/issue_repository.dart';
import '../../../reports/presentation/bloc/issue_list_bloc.dart';
import '../../../reports/presentation/widgets/issue_feed_view.dart';
import '../../../reports/presentation/widgets/student_issue_cards.dart';
import '../../../reports/presentation/widgets/student_issue_text.dart';
import '../bloc/student_stats_cubit.dart';

/// "My reports" (design screen 08): stats card, Active/Resolved toggle and
/// the student's own reports.
class StudentMineTab extends StatelessWidget {
  const StudentMineTab({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = context.select((AuthBloc b) => b.state.user?.uid);
    if (uid == null) return const LoadingView();
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => getIt<IssueListBloc>()
            ..add(
              IssueListSubscribed(IssueFilter(reporterId: uid, openOnly: true)),
            ),
        ),
        BlocProvider(create: (_) => getIt<StudentStatsCubit>()..start()),
      ],
      child: const _MineView(),
    );
  }
}

class _MineView extends StatelessWidget {
  const _MineView();

  static IssueFilter _active(IssueFilter f) =>
      f.copyWith(openOnly: true, status: () => null);

  static IssueFilter _resolved(IssueFilter f) =>
      f.copyWith(openOnly: false, status: () => IssueStatus.resolved);

  @override
  Widget build(BuildContext context) {
    final showingResolved = context.select(
      (IssueListBloc b) => b.state.filter.status == IssueStatus.resolved,
    );
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const DsPageHeader(title: 'My reports'),
          const Padding(
            padding: EdgeInsets.fromLTRB(
              AppSizes.gutter,
              14,
              AppSizes.gutter,
              0,
            ),
            child: _StatsCard(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.gutter,
              14,
              AppSizes.gutter,
              0,
            ),
            child: DsSegmentedToggle(
              labels: const ['Active', 'Resolved'],
              selectedIndex: showingResolved ? 1 : 0,
              onChanged: (i) => context.read<IssueListBloc>().add(
                IssueListFilterChanged(i == 0 ? _active : _resolved),
              ),
            ),
          ),
          Expanded(
            child: IssueFeedList(
              itemBuilder: (context, issue, index) => StudentReportCard(
                issue: issue,
                highlighted: !showingResolved && index == 0,
                onTap: () => context.push(Routes.issueDetails(issue.id)),
              ),
              emptyBuilder: (context) => LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: SizedBox(
                    height: constraints.maxHeight,
                    child: showingResolved
                        ? const DsMessageState(
                            ringLabel: '0',
                            title: 'Nothing resolved yet',
                            message:
                                'Reports that staff have fixed will '
                                'appear here.',
                          )
                        : DsMessageState(
                            ringLabel: '0',
                            title: 'No active reports',
                            message:
                                'Spotted something broken? Report it and '
                                'track the fix here.',
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
}

class _StatsCard extends StatelessWidget {
  const _StatsCard();

  @override
  Widget build(BuildContext context) {
    final stats = context.select((StudentStatsCubit c) => c.state.stats);
    const unknown = '–';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: AppColors.periwinkle,
        borderRadius: BorderRadius.circular(AppRadii.hero),
      ),
      child: Row(
        children: [
          _Stat(
            value: stats == null ? unknown : '${stats.open}',
            label: 'Active',
          ),
          _Stat(
            value: stats == null ? unknown : '${stats.resolved}',
            label: 'Resolved',
          ),
          _Stat(
            value: stats == null
                ? unknown
                : StudentIssueText.avgToFix(stats.avgResolutionHours),
            label: 'Avg. to fix',
            semanticValue: stats?.avgResolutionHours == null
                ? 'not available'
                : null,
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, this.semanticValue});

  final String value;
  final String label;
  final String? semanticValue;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        label: '$label: ${semanticValue ?? value}',
        excludeSemantics: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.56,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textOnPeriwinkle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
