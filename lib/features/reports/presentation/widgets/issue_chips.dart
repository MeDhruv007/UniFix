import 'package:flutter/material.dart';

import '../../../../core/widgets/ds/ds.dart';
import '../../domain/entities/issue_enums.dart';

/// Status pill (design: 24px, status colour, 11px semibold).
class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key, this.large = false});

  final IssueStatus status;
  final bool large;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Status: ${status.label}',
    excludeSemantics: true,
    child: DsPill(
      label: status.label,
      background: status.pillColor,
      large: large,
    ),
  );
}

/// Priority pill: solid black for urgent, outlined otherwise.
class PriorityChip extends StatelessWidget {
  const PriorityChip(this.priority, {super.key, this.large = false});

  final IssuePriority priority;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final urgent = priority == IssuePriority.urgent;
    final pill = priority.pill;
    return Semantics(
      label: 'Priority: ${priority.label}',
      excludeSemantics: true,
      child: DsPill(
        label: priority.label,
        background: pill.background,
        foreground: pill.foreground,
        outlined: !urgent,
        large: large,
      ),
    );
  }
}
