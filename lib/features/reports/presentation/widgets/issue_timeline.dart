import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/widgets/ds/ds.dart';
import '../../domain/entities/issue_enums.dart';
import '../../domain/entities/issue_update.dart';

/// Issue history as pills (design screen 07): actor initials, what
/// happened and when, newest first.
class IssueTimeline extends StatelessWidget {
  const IssueTimeline({super.key, required this.updates, this.viewerId});

  /// Oldest first, as delivered by the API.
  final List<IssueUpdate> updates;

  /// The signed-in user, so their own entries read "by you".
  final String? viewerId;

  static String describe(IssueUpdate u, {String? viewerId}) {
    final mine = viewerId != null && u.actorId == viewerId;
    return switch (u.action) {
      IssueUpdateAction.created => mine ? 'Reported by you' : 'Reported',
      IssueUpdateAction.statusChanged => switch (u.newStatus) {
        final s? => 'Moved to ${s.label}',
        null => 'Status changed',
      },
      IssueUpdateAction.priorityChanged => switch (u.newPriority) {
        final p? => 'Priority set to ${p.label}',
        null => 'Priority changed',
      },
      IssueUpdateAction.assigned => 'Assigned to staff',
      IssueUpdateAction.commented => 'Comment added',
      IssueUpdateAction.reopened => mine ? 'Reopened by you' : 'Reopened',
    };
  }

  static final DateFormat _time = DateFormat('HH:mm');
  static final DateFormat _date = DateFormat('d MMM');

  static String timeOf(DateTime? at, {DateTime? now}) {
    if (at == null) return 'Now';
    final local = at.toLocal();
    final today = now ?? DateTime.now();
    final sameDay =
        local.year == today.year &&
        local.month == today.month &&
        local.day == today.day;
    return sameDay ? _time.format(local) : _date.format(local);
  }

  static Color _background(int index) => switch (index) {
    0 => AppColors.periwinkle,
    1 => AppColors.periwinkleLight,
    _ => AppColors.surface,
  };

  @override
  Widget build(BuildContext context) {
    if (updates.isEmpty) {
      return const Text(
        'No history yet.',
        style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
      );
    }
    final newestFirst = updates.reversed.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < newestFirst.length; i++) ...[
          if (i > 0) const SizedBox(height: 6),
          _HistoryPill(
            update: newestFirst[i],
            text: describe(newestFirst[i], viewerId: viewerId),
            time: timeOf(newestFirst[i].createdAt),
            background: _background(i),
          ),
        ],
      ],
    );
  }
}

class _HistoryPill extends StatelessWidget {
  const _HistoryPill({
    required this.update,
    required this.text,
    required this.time,
    required this.background,
  });

  final IssueUpdate update;
  final String text;
  final String time;
  final Color background;

  @override
  Widget build(BuildContext context) {
    final note = update.note?.trim() ?? '';
    final actor = update.actorName?.trim() ?? '';
    return Semantics(
      container: true,
      label: [
        text,
        if (actor.isNotEmpty) 'by $actor',
        if (note.isNotEmpty) note,
        time,
      ].join(', '),
      excludeSemantics: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: 46),
        padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(23),
        ),
        child: Row(
          children: [
            CodeAvatar(
              code: CodeAvatar.initialsOf(actor),
              background: AppColors.white,
              foreground: AppColors.ink,
              size: 34,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    text,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (note.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        note,
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: AppColors.textStrong,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              time,
              style: const TextStyle(fontSize: 11, color: AppColors.textStrong),
            ),
          ],
        ),
      ),
    );
  }
}
