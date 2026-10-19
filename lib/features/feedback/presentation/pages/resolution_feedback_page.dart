import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/routing/routes.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/ds/ds.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../injection_container.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../reports/domain/entities/issue.dart';
import '../../../reports/domain/entities/issue_enums.dart';
import '../../../reports/presentation/bloc/issue_details_cubit.dart';
import '../../../reports/presentation/widgets/detail_photo_header.dart';
import '../../../reports/presentation/widgets/detail_resolution_card.dart';
import '../../domain/entities/issue_feedback.dart';
import '../bloc/feedback_cubit.dart';
import '../widgets/feedback_section.dart';

/// Design screen 09: the reporter confirms whether a resolved issue is
/// really fixed. Shows the answer read-only once given.
class ResolutionFeedbackPage extends StatelessWidget {
  const ResolutionFeedbackPage({super.key, required this.issueId});

  final String issueId;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => getIt<IssueDetailsCubit>(param1: issueId)..start(),
        ),
        BlocProvider(
          create: (_) => getIt<FeedbackCubit>(param1: issueId)..start(),
        ),
      ],
      child: const Scaffold(body: _FeedbackView()),
    );
  }
}

class _FeedbackView extends StatelessWidget {
  const _FeedbackView();

  void _retry(BuildContext context) {
    context.read<IssueDetailsCubit>().start();
    context.read<FeedbackCubit>().start();
  }

  @override
  Widget build(BuildContext context) {
    final details = context.watch<IssueDetailsCubit>().state;
    final feedback = context.watch<FeedbackCubit>().state;
    final uid = context.select((AuthBloc b) => b.state.user?.uid);
    final issue = details.issue;

    final Widget body;
    if (details.status == IssueDetailsStatus.failure) {
      body = ErrorView(
        message: details.message ?? 'Could not load this report.',
        onRetry: () => _retry(context),
      );
    } else if (details.status == IssueDetailsStatus.notFound) {
      body = EmptyView(
        icon: Icons.search_off,
        message: details.message ?? 'Report not found.',
      );
    } else if (issue == null) {
      body = const LoadingView();
    } else if (uid != issue.reporterId) {
      body = const EmptyView(
        icon: Icons.lock_outline,
        message: 'Only the person who reported this issue can give feedback.',
      );
    } else if (feedback.status == FeedbackStatus.failure) {
      body = ErrorView(
        message: feedback.message ?? 'Could not load your feedback.',
        onRetry: () => _retry(context),
      );
    } else if (feedback.status == FeedbackStatus.loading) {
      body = const LoadingView();
    } else if (feedback.feedback case final given?) {
      body = _Answered(issue: issue, feedback: given);
    } else if (issue.status != IssueStatus.resolved) {
      body = const EmptyView(
        icon: Icons.schedule,
        message:
            "This issue isn't resolved yet. You can give feedback once "
            'Facilities marks it fixed.',
      );
    } else {
      body = _FeedbackForm(issue: issue);
    }

    return SafeArea(
      child: Column(
        children: [
          _Header(issue: issue),
          Expanded(child: body),
        ],
      ),
    );
  }
}

/// Back button and the "Resolved · yesterday" pill.
class _Header extends StatelessWidget {
  const _Header({required this.issue});

  final Issue? issue;

  @override
  Widget build(BuildContext context) {
    final issue = this.issue;
    final String? label;
    final Color color;
    if (issue == null) {
      label = null;
      color = AppColors.surface;
    } else if (issue.status == IssueStatus.resolved) {
      label = issue.resolvedAt == null
          ? 'Resolved'
          : 'Resolved · ${Formatters.relative(issue.resolvedAt)}';
      color = AppColors.statusResolved;
    } else {
      label = issue.status.label;
      color = issue.status.pillColor;
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Row(
        children: [
          CircleIconButton(
            icon: Icons.arrow_back,
            tooltip: 'Back',
            onPressed: () => popOrGoHome(context),
          ),
          Expanded(
            child: Center(
              child: label == null
                  ? const SizedBox.shrink()
                  : Container(
                      height: 32,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: AppSizes.iconButton),
        ],
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading({required this.title, this.answered = false});

  final String title;
  final bool answered;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Text.rich(
      TextSpan(
        children: answered
            ? const [
                TextSpan(text: 'Thanks for your\n'),
                TextSpan(
                  text: 'feedback',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ]
            : [
                TextSpan(text: 'Is “$title”\n'),
                const TextSpan(
                  text: 'fixed now?',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
      ),
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w500,
        height: 1.2,
        letterSpacing: -0.48,
      ),
    ),
  );
}

/// Scrollable column with [footer] pinned to the bottom when there is room.
class _FillColumn extends StatelessWidget {
  const _FillColumn({required this.children, required this.footer});

  final List<Widget> children;
  final Widget footer;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: (constraints.maxHeight - 40).clamp(0, double.infinity),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
            Padding(padding: const EdgeInsets.only(top: 20), child: footer),
          ],
        ),
      ),
    ),
  );
}

class _FeedbackForm extends StatefulWidget {
  const _FeedbackForm({required this.issue});

  final Issue issue;

  @override
  State<_FeedbackForm> createState() => _FeedbackFormState();
}

class _FeedbackFormState extends State<_FeedbackForm> {
  final _formKey = GlobalKey<FormState>();
  final _comment = TextEditingController();

  /// null until the reporter picks one; true = "Yes, fixed".
  bool? _fixed;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  void _submit() {
    final fixed = _fixed;
    if (fixed == null) return;
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    context.read<FeedbackCubit>().submit(
      stillExists: !fixed,
      comment: _comment.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final submitting = context.select(
      (FeedbackCubit c) => c.state.isSubmitting,
    );
    return BlocListener<FeedbackCubit, FeedbackState>(
      listenWhen: (prev, next) =>
          prev.isSubmitting && next.submitStatus != prev.submitStatus,
      listener: (context, state) {
        if (state.submitStatus == FeedbackSubmitStatus.failure) {
          context.showSnack(
            state.message ?? 'Could not send your feedback.',
            isError: true,
          );
        } else {
          context.showSnack('Thanks, your feedback was sent.');
          // Fetch the stored answer now rather than on the next poll.
          context.read<FeedbackCubit>().start();
        }
      },
      child: Form(
        key: _formKey,
        child: _FillColumn(
          footer: PrimaryPillButton(
            label: 'Send feedback',
            busy: submitting,
            onPressed: _fixed == null ? null : _submit,
          ),
          children: [
            _Heading(title: widget.issue.title),
            const SizedBox(height: 16),
            DetailResolutionCard(issue: widget.issue),
            const SizedBox(height: 14),
            _Choices(
              fixed: _fixed,
              onChanged: submitting ? null : (v) => setState(() => _fixed = v),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _comment,
              enabled: !submitting,
              decoration: const InputDecoration(
                hintText: 'Add a comment (optional)',
              ),
              minLines: 1,
              maxLines: 4,
              maxLength: AppConstants.noteMaxLength,
              buildCounter: (
                _, {
                required currentLength,
                required isFocused,
                maxLength,
              }) => null,
              textCapitalization: TextCapitalization.sentences,
              validator: Validators.optionalNote,
            ),
          ],
        ),
      ),
    );
  }
}

class _Answered extends StatelessWidget {
  const _Answered({required this.issue, required this.feedback});

  final Issue issue;
  final IssueFeedback feedback;

  @override
  Widget build(BuildContext context) {
    return _FillColumn(
      footer: PrimaryPillButton(
        label: 'Back to report',
        onPressed: () => context.canPop()
            ? context.pop()
            : context.go(Routes.issueDetails(issue.id)),
      ),
      children: [
        _Heading(title: issue.title, answered: true),
        const SizedBox(height: 16),
        DetailResolutionCard(issue: issue),
        const SizedBox(height: 14),
        _Choices(fixed: !feedback.stillExists, onChanged: null),
        const SizedBox(height: 10),
        FeedbackAnswerCard(feedback: feedback),
        if (feedback.stillExists) ...[
          const SizedBox(height: 10),
          const InfoBanner(
            message:
                'Facilities can see that the problem is still there and '
                'will follow up.',
          ),
        ],
      ],
    );
  }
}

/// The two big choice cards. [onChanged] null = read-only.
class _Choices extends StatelessWidget {
  const _Choices({required this.fixed, required this.onChanged});

  final bool? fixed;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: _ChoiceCard(
          label: 'Yes, fixed',
          selected: fixed == true,
          onTap: onChanged == null ? null : () => onChanged!(true),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: _ChoiceCard(
          label: 'Still a problem',
          selected: fixed == false,
          onTap: onChanged == null ? null : () => onChanged!(false),
        ),
      ),
    ],
  );
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: selected ? AppColors.periwinkle : AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
          side: selected
              ? const BorderSide(color: AppColors.ink, width: 2)
              : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 96,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected ? AppColors.ink : Colors.transparent,
                      border: selected
                          ? null
                          : Border.all(
                              color: AppColors.textTertiary,
                              width: 1.5,
                            ),
                    ),
                    child: selected
                        ? const Icon(
                            Icons.check,
                            size: 16,
                            color: AppColors.white,
                          )
                        : null,
                  ),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
