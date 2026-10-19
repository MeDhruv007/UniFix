import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/routes.dart';
import '../../../../core/widgets/ds/ds.dart';
import '../../domain/entities/issue.dart';
import '../../domain/entities/issue_enums.dart';
import 'issue_chips.dart';
import 'student_issue_text.dart';

/// Overrides where [IssueCard]s below it navigate to, e.g. the admin
/// details route. Lets shared lists (IssueFeedView) be reused unchanged.
class IssueCardRouteScope extends InheritedWidget {
  const IssueCardRouteScope({
    super.key,
    required this.routeFor,
    required super.child,
  });

  final String Function(String issueId) routeFor;

  static IssueCardRouteScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<IssueCardRouteScope>();

  @override
  bool updateShouldNotify(IssueCardRouteScope oldWidget) =>
      routeFor != oldWidget.routeFor;
}

/// Feed row (design screen 04): 48px category avatar, title + age, location
/// + status pill, on a #F7F8FB rounded-28 row.
class IssueCard extends StatelessWidget {
  const IssueCard({super.key, required this.issue, this.onTap});

  final Issue issue;

  /// Custom tap handler. When null, opens the details route (from an
  /// enclosing [IssueCardRouteScope], or the student details route).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final routeFor =
        IssueCardRouteScope.maybeOf(context)?.routeFor ?? Routes.issueDetails;
    final swatch = issue.category.swatch;
    final urgent = issue.priority == IssuePriority.urgent;
    return Semantics(
      button: true,
      label:
          '${issue.title}, ${StudentIssueText.where(issue)}, '
          '${issue.status.label}${urgent ? ', urgent' : ''}, '
          '${issue.category.label}',
      excludeSemantics: true,
      child: Material(
        color: AppColors.surfaceRow,
        borderRadius: BorderRadius.circular(AppRadii.card),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap ?? () => context.push(routeFor(issue.id)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
            child: Row(
              children: [
                CodeAvatar(
                  code: issue.category.code,
                  background: swatch.background,
                  foreground: swatch.foreground,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              issue.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            StudentIssueText.age(issue.createdAt),
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              StudentIssueText.where(issue),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (issue.upvoteCount > 0) ...[
                            _MeTooCount(issue.upvoteCount),
                            const SizedBox(width: 6),
                          ],
                          if (urgent) ...[
                            PriorityChip(issue.priority),
                            const SizedBox(width: 4),
                          ],
                          StatusChip(issue.status),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Small "hand + number" shown on a card when others said "me too".
class _MeTooCount extends StatelessWidget {
  const _MeTooCount(this.count);

  final int count;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$count said me too',
    child: ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.back_hand_outlined,
            size: 13,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 3),
          Text(
            '$count',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    ),
  );
}
