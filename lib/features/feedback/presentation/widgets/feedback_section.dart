import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/routes.dart';
import '../../../../core/widgets/ds/ds.dart';
import '../../../../injection_container.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../reports/domain/entities/issue.dart';
import '../../../reports/domain/entities/issue_enums.dart';
import '../../domain/entities/issue_feedback.dart';
import '../bloc/feedback_cubit.dart';

/// Compact "Is it fixed? Tell us" card on the issue details page. Opens
/// the resolution feedback screen (design 09); once answered it shows the
/// reporter's answer instead.
///
/// Only the issue's reporter sees it, on a resolved issue (or a reopened
/// one they already gave feedback on).
class FeedbackSection extends StatelessWidget {
  const FeedbackSection({super.key, required this.issue});

  final Issue issue;

  @override
  Widget build(BuildContext context) {
    final uid = context.select((AuthBloc b) => b.state.user?.uid);
    final relevant =
        issue.status == IssueStatus.resolved ||
        issue.status == IssueStatus.reopened;
    if (uid == null || uid != issue.reporterId || !relevant) {
      return const SizedBox.shrink();
    }
    return BlocProvider(
      key: ValueKey(issue.id),
      create: (_) => getIt<FeedbackCubit>(param1: issue.id)..start(),
      child: _FeedbackCard(issue: issue),
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  const _FeedbackCard({required this.issue});

  final Issue issue;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<FeedbackCubit>().state;
    final resolved = issue.status == IssueStatus.resolved;
    final Widget? child = switch (state.status) {
      FeedbackStatus.loading =>
        resolved
            ? const SizedBox(
                height: 72,
                child: Center(
                  child: SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            : null,
      FeedbackStatus.failure =>
        resolved
            ? _LoadError(
                message: state.message ?? 'Could not load your feedback.',
              )
            : null,
      FeedbackStatus.loaded => switch (state.feedback) {
        final feedback? => FeedbackAnswerCard(feedback: feedback),
        null when resolved => _Prompt(issueId: issue.id),
        null => null,
      },
    };
    if (child == null) return const SizedBox.shrink();
    return Padding(padding: const EdgeInsets.only(top: 16), child: child);
  }
}

class _Prompt extends StatelessWidget {
  const _Prompt({required this.issueId});

  final String issueId;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Is it fixed? Tell us if the repair worked.',
      excludeSemantics: true,
      child: Material(
        color: AppColors.periwinkle,
        borderRadius: BorderRadius.circular(AppRadii.card),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push(Routes.issueFeedback(issueId)),
          child: const Padding(
            padding: EdgeInsets.fromLTRB(18, 14, 8, 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Is it fixed?',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Tell us if the repair worked.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textOnPeriwinkle,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8),
                PillBadge(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The reporter's submitted answer ("You said: Yes, fixed").
class FeedbackAnswerCard extends StatelessWidget {
  const FeedbackAnswerCard({super.key, required this.feedback});

  final IssueFeedback feedback;

  @override
  Widget build(BuildContext context) {
    final fixed = !feedback.stillExists;
    final comment = feedback.comment?.trim() ?? '';
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 18, 14),
      decoration: BoxDecoration(
        color: fixed ? AppColors.statusResolved : AppColors.statusReopened,
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(
              color: AppColors.ink,
              shape: BoxShape.circle,
            ),
            child: Icon(
              fixed ? Icons.check : Icons.priority_high,
              size: 16,
              color: AppColors.white,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fixed ? 'You said: Yes, fixed' : 'You said: Still a problem',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  comment.isEmpty ? 'Thanks for your feedback.' : comment,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: AppColors.textStrong,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(18, 4, 4, 4),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadii.card),
    ),
    child: Row(
      children: [
        Expanded(child: Text(message, style: const TextStyle(fontSize: 13))),
        TextButton(
          onPressed: context.read<FeedbackCubit>().start,
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          child: const Text('Retry'),
        ),
      ],
    ),
  );
}
