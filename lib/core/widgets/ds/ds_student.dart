import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Student-area design widgets ("FixMyCampus Screens v2" 03–08, 14, 15).

/// Dark-card shades from the design's "My reports" data (no token exists).
abstract final class StudentShades {
  /// Round arrow button on the highlighted dark card.
  static const darkButton = Color(0xFF2A2A2E);

  /// Empty progress segment on the dark card.
  static const darkTrack = Color(0xFF3A3A40);

  /// The × circle inside a removable black chip.
  static const chipClose = Color(0xFF2E2E33);

  /// Body text on the orange offline banner.
  static const onOrange = Color(0xFF2E1A08);

  /// Dashed outline of the "Add photo" tile.
  static const dashed = Color(0xFFC9CCD8);
}

/// Black pill with a round × (screen 14's active filters).
class DsRemovableChip extends StatelessWidget {
  const DsRemovableChip({
    super.key,
    required this.label,
    required this.onRemove,
  });

  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Remove filter $label',
      excludeSemantics: true,
      child: Material(
        color: AppColors.ink,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onRemove,
          child: Container(
            height: AppSizes.chip,
            padding: const EdgeInsets.only(left: 18, right: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 160),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    color: StudentShades.chipClose,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    size: 14,
                    color: AppColors.white,
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

/// Two-option segmented toggle (design: 52px #F3F4F8 track, black thumb).
class DsSegmentedToggle extends StatelessWidget {
  const DsSegmentedToggle({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onChanged,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: Semantics(
                button: true,
                selected: i == selectedIndex,
                child: Material(
                  color: i == selectedIndex
                      ? AppColors.ink
                      : Colors.transparent,
                  shape: const StadiumBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => onChanged(i),
                    child: Center(
                      child: Text(
                        labels[i],
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: i == selectedIndex
                              ? AppColors.white
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Orange alert card with a black "!" circle (screen 15, "You're offline").
class DsAlertBanner extends StatelessWidget {
  const DsAlertBanner({super.key, required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.orange,
          borderRadius: BorderRadius.circular(AppRadii.card),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.ink,
                shape: BoxShape.circle,
              ),
              child: const Text(
                '!',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.white,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    message,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: StudentShades.onOrange,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Concentric periwinkle rings around a big number (screen 14's "0").
class DsCountRing extends StatelessWidget {
  const DsCountRing({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 112,
      height: 112,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.periwinkleLight,
        shape: BoxShape.circle,
      ),
      child: Container(
        width: 72,
        height: 72,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: AppColors.periwinkle,
          shape: BoxShape.circle,
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

/// Centered message used for empty and error states in the student area:
/// a ring, a bold title, helper text and an optional black pill action.
class DsMessageState extends StatelessWidget {
  const DsMessageState({
    super.key,
    required this.title,
    this.message,
    this.ringLabel,
    this.icon,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? message;

  /// Text inside the ring ("0"); ignored when [icon] is set.
  final String? ringLabel;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null)
              Container(
                width: 112,
                height: 112,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.periwinkleLight,
                  shape: BoxShape.circle,
                ),
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(
                    color: AppColors.periwinkle,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 30, color: AppColors.ink),
                ),
              )
            else if (ringLabel != null)
              DsCountRing(label: ringLabel!),
            const SizedBox(height: 22),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 12),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              FilledButton(
                onPressed: onAction,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(64, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Label/value row inside a #F7F8FB card (screen 06's Issue / Where /
/// Status rows). Set [divider] on all but the last row.
class DsInfoRow extends StatelessWidget {
  const DsInfoRow({
    super.key,
    required this.label,
    required this.value,
    this.divider = true,
  });

  final String label;
  final Widget value;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 50),
      decoration: BoxDecoration(
        border: divider
            ? const Border(bottom: BorderSide(color: AppColors.divider))
            : null,
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: DefaultTextStyle.merge(
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
                child: value,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Same look as `DsSearchField`, but takes a [focusNode] so another tab can
/// hand focus to it (Home's search → Feed).
class DsFocusableSearchField extends StatelessWidget {
  const DsFocusableSearchField({
    super.key,
    required this.hint,
    required this.controller,
    this.focusNode,
    this.onChanged,
  });

  final String hint;
  final TextEditingController controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(26),
      borderSide: BorderSide.none,
    );
    return SizedBox(
      height: 52,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: hint,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          prefixIcon: const Padding(
            padding: EdgeInsets.only(left: 18, right: 10),
            child: Icon(Icons.search, size: 20, color: AppColors.textSecondary),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 0),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) => value.text.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    tooltip: 'Clear search',
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () {
                      controller.clear();
                      onChanged?.call('');
                    },
                  ),
          ),
          border: border,
          enabledBorder: border,
          focusedBorder: border.copyWith(
            borderSide: const BorderSide(color: AppColors.ink, width: 1.5),
          ),
        ),
      ),
    );
  }
}

/// Dashed rounded-rectangle border (the "Add photo" tile).
class DashedBorderPainter extends CustomPainter {
  const DashedBorderPainter({
    this.color = StudentShades.dashed,
    this.radius = AppRadii.card,
    this.strokeWidth = 1.5,
    this.dash = 6,
    this.gap = 4,
  });

  final Color color;
  final double radius;
  final double strokeWidth;
  final double dash;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(strokeWidth / 2);
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + dash), paint);
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(DashedBorderPainter old) =>
      old.color != color || old.radius != radius;
}
