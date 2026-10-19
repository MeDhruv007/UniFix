import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/routes.dart';
import '../../../../core/widgets/ds/ds.dart';
import '../../../reports/domain/entities/issue.dart';
import '../../../reports/domain/entities/issue_enums.dart';
import 'update_issue_sheet.dart';

/// Compact admin actions on the issue details page: "Update issue" (sheet,
/// screen 12) and, when allowed, "Mark resolved" (screen 13).
class AdminActionBar extends StatelessWidget {
  const AdminActionBar({super.key, required this.issue});

  final Issue issue;

  @override
  Widget build(BuildContext context) {
    final canResolve = issue.status.canTransitionTo(IssueStatus.resolved);
    final assignee = issue.assignedTo == null
        ? 'Unassigned'
        : 'Assigned to ${issue.assignedToName ?? 'staff'}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 6, bottom: 8),
          child: Text(
            '${issue.priority.label} priority · $assignee',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: canResolve
                  ? OutlinedButton(
                      onPressed: () => showUpdateIssueSheet(context, issue),
                      child: const Text('Update issue'),
                    )
                  : FilledButton(
                      onPressed: () => showUpdateIssueSheet(context, issue),
                      child: const Text('Update issue'),
                    ),
            ),
            if (canResolve) ...[
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: () => context.push(Routes.adminResolve(issue.id)),
                  child: const Text('Mark resolved'),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
