import 'package:flutter/material.dart';

import '../../../../core/widgets/ds/ds.dart';
import '../../../../core/widgets/ds/ds_student.dart';
import '../../domain/entities/issue.dart';
import '../../domain/entities/issue_enums.dart';
import 'student_issue_text.dart';

/// Coloured campus-issue card on the student home (design screen 03):
/// category swatch background, black code avatar, outlined age pill,
/// title, location and a status (or "Urgent") pill.
class StudentCampusCard extends StatelessWidget {
  const StudentCampusCard({
    super.key,
    required this.issue,
    required this.onTap,
    this.width = 164,
  });

  final Issue issue;
  final VoidCallback onTap;
  final double width;

  @override
  Widget build(BuildContext context) {
    final background = issue.category.swatch.background;
    final dark = background == AppColors.ink;
    final fg = dark ? AppColors.white : AppColors.ink;
    final urgent = issue.priority == IssuePriority.urgent;
    return Semantics(
      button: true,
      label:
          '${issue.title}, ${StudentIssueText.where(issue)}, '
          '${urgent ? 'urgent, ' : ''}${issue.status.label}, '
          '${issue.category.label}',
      excludeSemantics: true,
      child: SizedBox(
        width: width,
        child: Material(
          color: background,
          borderRadius: BorderRadius.circular(AppRadii.card),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CodeAvatar(
                        code: issue.category.code,
                        background: dark ? AppColors.white : AppColors.ink,
                        foreground: dark ? AppColors.ink : AppColors.white,
                        size: 44,
                      ),
                      const Spacer(),
                      Container(
                        height: 28,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: fg, width: 1.5),
                        ),
                        child: Text(
                          StudentIssueText.age(issue.createdAt),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: fg,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    issue.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                      color: fg,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    StudentIssueText.where(issue),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: fg.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (urgent)
                    DsPill(
                      label: 'Urgent',
                      background: dark ? AppColors.white : AppColors.ink,
                      foreground: dark ? AppColors.ink : AppColors.white,
                    )
                  else
                    DsPill(
                      label: issue.status.label,
                      background: AppColors.white.withValues(alpha: 0.6),
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

/// Periwinkle hero for the student's most recent open report (screen 03).
class StudentHeroCard extends StatelessWidget {
  const StudentHeroCard({super.key, required this.issue, required this.onView});

  final Issue issue;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    final step = issue.progressStep;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.periwinkle,
        borderRadius: BorderRadius.circular(AppRadii.hero),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CodeAvatar(
                code: issue.category.code,
                background: AppColors.white,
                foreground: AppColors.ink,
              ),
              const Spacer(),
              ProgressRing(
                value: step / 3,
                label: '$step/3',
                semanticsLabel: 'Step $step of 3',
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            issue.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            StudentIssueText.statusLine(issue),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textOnPeriwinkle,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              FilledButton(
                onPressed: onView,
                style: _heroButtonStyle,
                child: const Text('View status'),
              ),
              const Spacer(),
              Text(
                issue.displayCode,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textOnPeriwinkle,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Hero shown when the student has nothing open (or while loading).
class StudentHeroPrompt extends StatelessWidget {
  const StudentHeroPrompt({
    super.key,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.busy = false,
  });

  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.periwinkle,
        borderRadius: BorderRadius.circular(AppRadii.hero),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: AppSizes.avatar,
                height: AppSizes.avatar,
                decoration: const BoxDecoration(
                  color: AppColors.white,
                  shape: BoxShape.circle,
                ),
                child: busy
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check, color: AppColors.ink),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            style: const TextStyle(
              fontSize: 13,
              height: 1.4,
              color: AppColors.textOnPeriwinkle,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 14),
            FilledButton(
              onPressed: onAction,
              style: _heroButtonStyle,
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

final ButtonStyle _heroButtonStyle = FilledButton.styleFrom(
  minimumSize: const Size(64, 48),
  padding: const EdgeInsets.symmetric(horizontal: 22),
  textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
);

/// "My reports" card (design screen 08). [highlighted] renders the dark
/// card used for the most recent active report.
class StudentReportCard extends StatelessWidget {
  const StudentReportCard({
    super.key,
    required this.issue,
    required this.onTap,
    this.highlighted = false,
  });

  final Issue issue;
  final VoidCallback onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final background = highlighted
        ? AppColors.ink
        : issue.status == IssueStatus.reopened
        ? AppColors.pink
        : AppColors.surface;
    final fg = highlighted ? AppColors.white : AppColors.ink;
    final step = issue.progressStep;
    final List<Color> segments;
    if (highlighted) {
      segments = [
        for (var i = 1; i <= 3; i++)
          i < step || step == 3
              ? AppColors.white
              : i == step
              ? AppColors.periwinkle
              : StudentShades.darkTrack,
      ];
    } else {
      final filled = issue.status == IssueStatus.reported
          ? AppColors.orange
          : AppColors.ink;
      final empty = background == AppColors.pink
          ? AppColors.ink.withValues(alpha: 0.15)
          : AppColors.border;
      segments = [for (var i = 1; i <= 3; i++) i <= step ? filled : empty];
    }

    return Semantics(
      button: true,
      label:
          '${issue.title}, ${StudentIssueText.where(issue)}, '
          '${issue.status.label}, step $step of 3, '
          '${StudentIssueText.note(issue)}',
      excludeSemantics: true,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(AppRadii.card),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    CodeAvatar(
                      code: issue.category.code,
                      background: AppColors.white,
                      foreground: AppColors.ink,
                      size: 44,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            issue.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: fg,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            StudentIssueText.where(issue),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: fg.withValues(alpha: 0.75),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: highlighted
                            ? StudentShades.darkButton
                            : AppColors.ink,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.chevron_right,
                        size: 20,
                        color: AppColors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                StepBar(colors: segments),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      issue.status.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: fg,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        StudentIssueText.note(issue),
                        textAlign: TextAlign.right,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: fg.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
