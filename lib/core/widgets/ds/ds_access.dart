import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// The design's "ring" motif (screens 14 and 16): a 112px periwinkle-light
/// halo around a 72px circle holding an icon or a short label.
class HaloIcon extends StatelessWidget {
  const HaloIcon({
    super.key,
    this.icon,
    this.label,
    this.innerColor = AppColors.periwinkle,
    this.foreground = AppColors.ink,
    this.haloColor = AppColors.periwinkleLight,
    this.size = 112,
  }) : assert(icon != null || label != null);

  final IconData? icon;
  final String? label;
  final Color innerColor;
  final Color foreground;
  final Color haloColor;
  final double size;

  @override
  Widget build(BuildContext context) {
    final inner = size * 72 / 112;
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: haloColor, shape: BoxShape.circle),
        child: Container(
          width: inner,
          height: inner,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: innerColor, shape: BoxShape.circle),
          child: icon != null
              ? Icon(icon, size: inner * 0.38, color: foreground)
              : Text(
                  label!,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: foreground,
                  ),
                ),
        ),
      ),
    );
  }
}

/// Small helper text under a pill field ("8+ characters, one number").
class FieldHelper extends StatelessWidget {
  const FieldHelper(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 20),
    child: Text(
      text,
      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
    ),
  );
}
