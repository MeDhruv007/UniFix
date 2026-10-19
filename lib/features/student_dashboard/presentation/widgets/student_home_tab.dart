import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/routes.dart';
import '../../../../core/widgets/ds/ds.dart';
import '../../../../injection_container.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../reports/domain/entities/issue_enums.dart';
import '../../../reports/domain/repositories/issue_repository.dart';
import '../../../reports/presentation/bloc/issue_list_bloc.dart';
import '../../../reports/presentation/widgets/student_issue_cards.dart';
import '../../../reports/presentation/widgets/student_issue_text.dart';

/// Student home (design screen 03): greeting, search shortcut, the
/// student's most recent open report, and recent open campus issues.
class StudentHomeTab extends StatelessWidget {
  const StudentHomeTab({super.key, required this.onSearchTap});

  /// Opens the Feed tab with its search focused.
  final VoidCallback onSearchTap;

  @override
  Widget build(BuildContext context) {
    final user = context.select((AuthBloc b) => b.state.user);
    final first = (user?.displayName ?? '').trim().split(RegExp(r'\s+')).first;
    return SafeArea(
      bottom: false,
      // Not a lazy ListView: the sections own their blocs and must stay
      // alive while scrolled off-screen.
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.gutter,
                12,
                AppSizes.gutter,
                0,
              ),
              child: Row(
                children: [
                  ExcludeSemantics(child: UserAvatar(avatarId: user?.avatar)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(
                          header: true,
                          child: Text(
                            first.isEmpty ? 'Hello' : 'Hello, $first',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(height: 1),
                        const Text(
                          'ADIT Campus · Student',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.gutter,
                16,
                AppSizes.gutter,
                0,
              ),
              child: DsSearchField(
                hint: 'Search issues or buildings',
                readOnly: true,
                onTap: onSearchTap,
              ),
            ),
            if (user != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSizes.gutter,
                  16,
                  AppSizes.gutter,
                  0,
                ),
                child: BlocProvider(
                  create: (_) => getIt<IssueListBloc>()
                    ..add(
                      IssueListSubscribed(
                        IssueFilter(reporterId: user.uid, openOnly: true),
                      ),
                    ),
                  child: const _HeroSection(),
                ),
              ),
            BlocProvider(
              create: (_) => getIt<IssueListBloc>()
                ..add(const IssueListSubscribed(IssueFilter(openOnly: true))),
              child: const _CampusSection(),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  const _HeroSection();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<IssueListBloc, IssueListState>(
      builder: (context, state) {
        switch (state.status) {
          case IssueListStatus.initial || IssueListStatus.loading:
            return const StudentHeroPrompt(
              busy: true,
              title: 'Checking your reports…',
              message: 'Your latest open report will show here.',
            );
          case IssueListStatus.failure:
            return StudentHeroPrompt(
              title: 'Could not load your reports',
              message: state.message ?? 'Check your connection and try again.',
              actionLabel: 'Try again',
              onAction: () => context.read<IssueListBloc>().add(
                IssueListSubscribed(state.filter),
              ),
            );
          case IssueListStatus.loaded:
            if (state.issues.isEmpty) {
              return StudentHeroPrompt(
                title: 'Nothing open right now',
                message:
                    'Spotted something broken on campus? Report it and '
                    'follow every step of the fix here.',
                actionLabel: 'Report an issue',
                onAction: () => context.push(Routes.report),
              );
            }
            final issue = state.issues.first;
            return StudentHeroCard(
              issue: issue,
              onView: () => context.push(Routes.issueDetails(issue.id)),
            );
        }
      },
    );
  }
}

class _CampusSection extends StatefulWidget {
  const _CampusSection();

  @override
  State<_CampusSection> createState() => _CampusSectionState();
}

class _CampusSectionState extends State<_CampusSection> {
  static const _cardsHeight = 232.0;

  // Edge-fade a row only while it's actually scrollable, so a cut-off chip
  // or card always reads as "swipe for more" rather than a hard clip.
  final _chipsController = ScrollController();
  final _cardsController = ScrollController();

  @override
  void dispose() {
    _chipsController.dispose();
    _cardsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selected = context.select(
      (IssueListBloc b) => b.state.filter.category,
    );
    final bloc = context.read<IssueListBloc>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 18),
        FadeEdgeScroll(
          controller: _chipsController,
          child: SingleChildScrollView(
            controller: _chipsController,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.gutter),
            child: Row(
              children: [
                DsChip(
                  label: 'All',
                  selected: selected == null,
                  onTap: () =>
                      bloc.add(const IssueListCategoryFilterChanged(null)),
                ),
                for (final c in IssueCategory.values) ...[
                  const SizedBox(width: 8),
                  DsChip(
                    label: StudentIssueText.category(c),
                    selected: selected == c,
                    onTap: () => bloc.add(IssueListCategoryFilterChanged(c)),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: _cardsHeight,
          child: BlocBuilder<IssueListBloc, IssueListState>(
            builder: (context, state) {
              switch (state.status) {
                case IssueListStatus.initial || IssueListStatus.loading:
                  return const Center(child: CircularProgressIndicator());
                case IssueListStatus.failure:
                  return _CardsMessage(
                    message: state.message ?? 'Could not load campus issues.',
                    actionLabel: 'Try again',
                    onAction: () => context.read<IssueListBloc>().add(
                      IssueListSubscribed(state.filter),
                    ),
                  );
                case IssueListStatus.loaded:
                  if (state.issues.isEmpty) {
                    final cat = state.filter.category;
                    return _CardsMessage(
                      message: cat == null
                          ? 'No open issues on campus right now.'
                          : 'No open '
                                '${StudentIssueText.categoryInSentence(cat)} '
                                'issues right now.',
                    );
                  }
                  return FadeEdgeScroll(
                    controller: _cardsController,
                    child: ListView.separated(
                      controller: _cardsController,
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSizes.gutter,
                      ),
                      itemCount: state.issues.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 10),
                      itemBuilder: (context, i) {
                        final issue = state.issues[i];
                        return StudentCampusCard(
                          issue: issue,
                          onTap: () =>
                              context.push(Routes.issueDetails(issue.id)),
                        );
                      },
                    ),
                  );
              }
            },
          ),
        ),
      ],
    );
  }
}

class _CardsMessage extends StatelessWidget {
  const _CardsMessage({required this.message, this.actionLabel, this.onAction});

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSizes.gutter),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceRow,
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: onAction,
              style: OutlinedButton.styleFrom(minimumSize: const Size(64, 48)),
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}
