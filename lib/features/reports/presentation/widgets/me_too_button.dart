import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/widgets/ds/ds.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../domain/entities/issue.dart';
import '../../domain/repositories/issue_repository.dart';
import '../bloc/upvote_cubit.dart';

/// "Me too": lets a student back an existing report instead of filing a
/// duplicate. The reporter and resolved issues get a read-only count.
class MeTooButton extends StatefulWidget {
  const MeTooButton({super.key, required this.issue});

  final Issue issue;

  @override
  State<MeTooButton> createState() => _MeTooButtonState();
}

class _MeTooButtonState extends State<MeTooButton> {
  late final UpvoteCubit _cubit = UpvoteCubit(
    repository: context.read<IssueRepository>(),
    issue: widget.issue,
  );

  @override
  void didUpdateWidget(MeTooButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The details page keeps refreshing the issue; mirror it.
    _cubit.sync(widget.issue);
  }

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = context.select((AuthBloc b) => b.state.user?.uid);
    final isAdmin = context.select((AuthBloc b) => b.state.isAdmin);
    final isReporter = uid != null && uid == widget.issue.reporterId;
    final closed = !widget.issue.status.isOpen;

    return BlocConsumer<UpvoteCubit, UpvoteState>(
      bloc: _cubit,
      listenWhen: (prev, next) =>
          next.message != null && prev.message != next.message,
      listener: (context, state) {
        context.showSnack(state.message!, isError: true);
        _cubit.messageShown();
      },
      builder: (context, state) {
        if (isReporter || isAdmin || closed) {
          // Read-only: say how many others hit the same problem.
          if (state.count == 0) return const SizedBox.shrink();
          return _place(
            _CountPill(
              text: state.count == 1
                  ? '1 person said me too'
                  : '${state.count} people said me too',
            ),
          );
        }
        final label = state.count > 0 ? 'Me too · ${state.count}' : 'Me too';
        return _place(
          Semantics(
            button: true,
            toggled: state.upvoted,
            label: state.upvoted
                ? 'You said me too. ${state.count} total. Tap to undo.'
                : 'Say me too, you have this problem as well. ${state.count} so far.',
            child: Material(
              color: state.upvoted ? AppColors.ink : AppColors.white,
              shape: StadiumBorder(
                side: state.upvoted
                    ? BorderSide.none
                    : const BorderSide(color: AppColors.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: state.busy ? null : _cubit.toggle,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 44),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ExcludeSemantics(
                          child: Icon(
                            state.upvoted
                                ? Icons.back_hand
                                : Icons.back_hand_outlined,
                            size: 18,
                            color: state.upvoted
                                ? AppColors.white
                                : AppColors.ink,
                          ),
                        ),
                        const SizedBox(width: 8),
                        ExcludeSemantics(
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: state.upvoted
                                  ? AppColors.white
                                  : AppColors.ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Left-aligned (the details column stretches children) with top spacing,
  /// only when something is shown.
  static Widget _place(Widget child) => Align(
    alignment: Alignment.centerLeft,
    child: Padding(padding: const EdgeInsets.only(top: 14), child: child),
  );
}

class _CountPill extends StatelessWidget {
  const _CountPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 36),
    padding: const EdgeInsets.symmetric(horizontal: 14),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.back_hand_outlined,
          size: 16,
          color: AppColors.textSecondary,
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    ),
  );
}
