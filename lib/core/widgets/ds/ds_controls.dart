import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Full-width black pill (design: 54px, radius 27). Shows a spinner while
/// [busy]. Pass [trailing] for the round "→ / ✓" badge some screens use.
class PrimaryPillButton extends StatelessWidget {
  const PrimaryPillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
    this.trailing,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: AppSizes.field,
      child: FilledButton(
        onPressed: busy ? null : onPressed,
        style: trailing == null
            ? null
            : FilledButton.styleFrom(
                padding: const EdgeInsets.only(left: 24, right: 6),
              ),
        child: busy
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.white,
                ),
              )
            : trailing == null
            ? Text(label)
            : Row(
                children: [
                  Expanded(child: Text(label)),
                  trailing!,
                ],
              ),
      ),
    );
  }
}

/// The white circle with an arrow/check inside a [PrimaryPillButton].
class PillBadge extends StatelessWidget {
  const PillBadge({super.key, this.icon = Icons.arrow_forward});

  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    width: 42,
    height: 42,
    decoration: const BoxDecoration(
      color: AppColors.white,
      shape: BoxShape.circle,
    ),
    child: Icon(icon, size: 20, color: AppColors.ink),
  );
}

/// Full-width outlined pill (secondary action).
class SecondaryPillButton extends StatelessWidget {
  const SecondaryPillButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: AppSizes.field,
    child: OutlinedButton(onPressed: onPressed, child: Text(label)),
  );
}

/// 48px circle with a hairline border (back, filter, bell buttons).
class CircleIconButton extends StatelessWidget {
  const CircleIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.filled = false,
    this.size = AppSizes.iconButton,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String tooltip;

  /// Solid white fill (used over coloured or photo headers).
  final bool filled;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: filled ? AppColors.white : Colors.transparent,
        shape: CircleBorder(
          side: filled
              ? BorderSide.none
              : const BorderSide(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox.square(
            dimension: size,
            child: Icon(icon, size: 20, color: AppColors.ink),
          ),
        ),
      ),
    );
  }
}

/// Selectable pill chip (design: 44px; black when selected, outlined
/// otherwise). [count] renders a small orange badge (e.g. "Urgent 7").
class DsChip extends StatelessWidget {
  const DsChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
    this.dense = false,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final int? count;

  /// 40px instead of 44px, for compact rows such as the report form.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final height = dense ? 40.0 : AppSizes.chip;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? AppColors.ink : AppColors.white,
        shape: StadiumBorder(
          side: selected
              ? BorderSide.none
              : const BorderSide(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          // IntrinsicWidth: an aligned Container would otherwise stretch to
          // the full row inside a Wrap.
          child: IntrinsicWidth(
            child: Container(
              height: height,
              padding: EdgeInsets.symmetric(horizontal: dense ? 14 : 18),
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      color: selected ? AppColors.white : AppColors.ink,
                    ),
                  ),
                  if (count != null && count! > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      constraints: const BoxConstraints(minWidth: 20),
                      height: 20,
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: AppColors.orange,
                        borderRadius: BorderRadius.all(Radius.circular(10)),
                      ),
                      child: Text(
                        '$count',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Small rounded label (status / priority / tags). Design: 24px, radius 12,
/// 11px semibold.
class DsPill extends StatelessWidget {
  const DsPill({
    super.key,
    required this.label,
    required this.background,
    this.foreground = AppColors.ink,
    this.outlined = false,
    this.large = false,
  });

  final String label;
  final Color background;
  final Color foreground;

  /// Hairline border instead of fill (e.g. "5h" age tags on cards).
  final bool outlined;

  /// 30px variant used on hero cards and the legend.
  final bool large;

  @override
  Widget build(BuildContext context) {
    final height = large ? 30.0 : 24.0;
    return Container(
      height: height,
      padding: EdgeInsets.symmetric(horizontal: large ? 12 : 9),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: outlined ? Colors.transparent : background,
        borderRadius: BorderRadius.circular(height / 2),
        border: outlined ? Border.all(color: foreground, width: 1.5) : null,
      ),
      child: Text(
        label,
        maxLines: 1,
        style: TextStyle(
          fontSize: large ? 12 : 11,
          fontWeight: FontWeight.w600,
          color: foreground,
          height: 1,
        ),
      ),
    );
  }
}

/// Rounded info box with a white "i" circle (design: #D9E2FD, radius 28).
class InfoBanner extends StatelessWidget {
  const InfoBanner({
    super.key,
    required this.message,
    this.icon,
    this.background = AppColors.periwinkleLight,
    this.foreground = AppColors.textOnPeriwinkle,
    this.title,
    this.action,
  });

  final String message;
  final String? title;
  final IconData? icon;
  final Color background;
  final Color foreground;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.white,
              shape: BoxShape.circle,
            ),
            child: icon == null
                ? const Text(
                    'i',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  )
                : Icon(icon, size: 16, color: AppColors.ink),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null)
                  Text(
                    title!,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: foreground,
                    ),
                  ),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: foreground,
                  ),
                ),
              ],
            ),
          ),
          if (action != null) ...[const SizedBox(width: 8), action!],
        ],
      ),
    );
  }
}

/// Uppercase section label ("HISTORY", "PROOF OF REPAIR").
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
        ),
      ),
      ?trailing,
    ],
  );
}
