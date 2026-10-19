import 'package:flutter/material.dart';

import '../../../../core/widgets/ds/ds.dart';

/// One of the 2×2 fact tiles on the issue detail screen (Status / Priority
/// / Where / Assigned).
class DetailInfoTile extends StatelessWidget {
  const DetailInfoTile({
    super.key,
    required this.label,
    required this.value,
    this.background = AppColors.surface,
    this.labelColor = AppColors.textSecondary,
  });

  final String label;
  final String value;
  final Color background;
  final Color labelColor;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: '$label: $value',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: TextStyle(fontSize: 11, color: labelColor)),
            const SizedBox(height: 2),
            Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Two tiles side by side with equal heights.
class DetailTileRow extends StatelessWidget {
  const DetailTileRow({super.key, required this.left, required this.right});

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: left),
        const SizedBox(width: 8),
        Expanded(child: right),
      ],
    ),
  );
}
