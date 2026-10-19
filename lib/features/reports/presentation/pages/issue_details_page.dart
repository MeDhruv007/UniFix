import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/ds/ds.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../injection_container.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../feedback/presentation/widgets/feedback_section.dart';
import '../../domain/entities/issue.dart';
import '../bloc/issue_details_cubit.dart';
import '../widgets/detail_info_tile.dart';
import '../widgets/detail_photo_header.dart';
import '../widgets/detail_resolution_card.dart';
import '../widgets/issue_timeline.dart';
import '../widgets/me_too_button.dart';

/// Design screen 07. Shared by students and (via [adminPanel]) admins.
class IssueDetailsPage extends StatelessWidget {
  const IssueDetailsPage({super.key, required this.issueId, this.adminPanel});

  final String issueId;

  /// Extra section rendered for admins (status/priority controls).
  final Widget Function(Issue issue)? adminPanel;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<IssueDetailsCubit>(param1: issueId)..start(),
      child: Scaffold(body: _DetailsView(adminPanel: adminPanel)),
    );
  }
}

class _DetailsView extends StatefulWidget {
  const _DetailsView({this.adminPanel});

  final Widget Function(Issue issue)? adminPanel;

  @override
  State<_DetailsView> createState() => _DetailsViewState();
}

class _DetailsViewState extends State<_DetailsView> {
  /// While a pull-to-refresh reloads, keep showing the current content
  /// instead of flashing the loading state.
  bool _refreshing = false;

  Future<void> _refresh() async {
    final cubit = context.read<IssueDetailsCubit>();
    _refreshing = true;
    try {
      cubit.start();
      await cubit.stream
          .firstWhere((s) => s.status != IssueDetailsStatus.loading)
          .timeout(const Duration(seconds: 15));
    } on Object {
      // Timed out or closed; the live stream keeps the page current.
    } finally {
      _refreshing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<IssueDetailsCubit, IssueDetailsState>(
      buildWhen: (prev, next) =>
          !(_refreshing && next.status == IssueDetailsStatus.loading),
      builder: (context, state) => switch (state.status) {
        IssueDetailsStatus.loading => const _Bare(child: LoadingView()),
        IssueDetailsStatus.notFound => _Bare(
          child: EmptyView(
            icon: Icons.search_off,
            message: state.message ?? 'Report not found.',
          ),
        ),
        IssueDetailsStatus.failure => _Bare(
          child: ErrorView(
            message: state.message ?? 'Could not load this report.',
            onRetry: context.read<IssueDetailsCubit>().start,
          ),
        ),
        IssueDetailsStatus.loaded => RefreshIndicator(
          onRefresh: _refresh,
          color: AppColors.ink,
          child: _DetailsBody(state: state, adminPanel: widget.adminPanel),
        ),
      },
    );
  }
}

/// Back button over a state view (no photo header yet).
class _Bare extends StatelessWidget {
  const _Bare({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      DsTopBar(onBack: () => popOrGoHome(context)),
      Expanded(child: child),
    ],
  );
}

class _DetailsBody extends StatelessWidget {
  const _DetailsBody({required this.state, this.adminPanel});

  final IssueDetailsState state;
  final Widget Function(Issue issue)? adminPanel;

  @override
  Widget build(BuildContext context) {
    final issue = state.issue!;
    final viewerId = context.select((AuthBloc b) => b.state.user?.uid);
    final hasResolution =
        (issue.resolutionNote?.trim().isNotEmpty ?? false) ||
        issue.resolutionPhotoPaths.isNotEmpty;
    final reporter = issue.reporterId == viewerId
        ? 'you'
        : issue.reporterDisplayName;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.only(bottom: 32 + bottom),
      children: [
        DetailPhotoHeader(photoPaths: issue.photoPaths),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _TitleRow(issue: issue),
              const SizedBox(height: 14),
              DetailTileRow(
                left: DetailInfoTile(
                  label: 'Status',
                  value: issue.status.label,
                  background: AppColors.periwinkleLight,
                  labelColor: AppColors.textOnPeriwinkle,
                ),
                right: DetailInfoTile(
                  label: 'Priority',
                  value: issue.priority.label,
                ),
              ),
              const SizedBox(height: 8),
              DetailTileRow(
                left: DetailInfoTile(
                  label: 'Where',
                  value:
                      '${CampusBuildings.nameOf(issue.buildingId)} · '
                      '${issue.locationDetail}',
                ),
                right: DetailInfoTile(
                  label: 'Assigned',
                  value: (issue.assignedToName?.trim().isNotEmpty ?? false)
                      ? issue.assignedToName!.trim()
                      : 'Unassigned',
                ),
              ),
              const SizedBox(height: 18),
              Text(
                [
                  'Reported ${Formatters.relative(issue.createdAt)}',
                  if (reporter != null && reporter.isNotEmpty) 'by $reporter',
                ].join(' '),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                issue.description,
                style: const TextStyle(fontSize: 14, height: 1.5),
              ),
              // "Me too" for other students; a read-only count for the reporter
              // and for resolved issues.
              MeTooButton(issue: issue),
              if (hasResolution) ...[
                const SizedBox(height: 16),
                DetailResolutionCard(issue: issue, showPhoto: false),
              ],
              // Renders nothing unless the viewer reported this issue and
              // it is resolved (or they already answered).
              FeedbackSection(issue: issue),
              if (adminPanel != null) ...[
                const SizedBox(height: 16),
                adminPanel!(issue),
              ],
              const SizedBox(height: 18),
              const Text(
                'History',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              IssueTimeline(updates: state.updates, viewerId: viewerId),
            ],
          ),
        ),
      ],
    );
  }
}

class _TitleRow extends StatelessWidget {
  const _TitleRow({required this.issue});

  final Issue issue;

  @override
  Widget build(BuildContext context) {
    final step = issue.progressStep;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${issue.displayCode} · ${issue.category.label.toUpperCase()}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.44,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              Semantics(
                header: true,
                child: Text(
                  issue.title,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.42,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        ProgressRing(
          value: step / 3,
          label: '$step/3',
          trackColor: AppColors.border,
          semanticsLabel: 'Progress: step $step of 3, ${issue.status.label}',
        ),
      ],
    );
  }
}
