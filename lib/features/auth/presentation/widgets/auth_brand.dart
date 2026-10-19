import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/ds/ds.dart';

/// The periwinkle top block of design screen 01: brand pills, headline and
/// illustration, inset 10px with a 40px radius. It runs up under the status
/// bar, so it adds the top safe-area inset itself.
class AuthBrandBlock extends StatelessWidget {
  const AuthBrandBlock({super.key, this.expand = false, this.bottom});

  /// Fill the available height (splash screen).
  final bool expand;

  /// Replaces the illustration (e.g. a progress indicator on splash).
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final content = Column(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [BrandPill(), _CampusPill()],
        ),
        if (expand) const Spacer(),
        const SizedBox(height: 22),
        const AuthHeadline(),
        const SizedBox(height: 16),
        if (expand) const Spacer(),
        bottom ?? const AuthIllustration(),
      ],
    );
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 10, 10, 0),
      padding: EdgeInsets.fromLTRB(18, (top - 6).clamp(8, 60) + 4, 18, 20),
      decoration: BoxDecoration(
        color: AppColors.periwinkle,
        borderRadius: BorderRadius.circular(AppRadii.sheet),
      ),
      child: content,
    );
  }
}

/// Outlined app-name pill (AppConstants.appName).
class BrandPill extends StatelessWidget {
  const BrandPill({super.key});

  @override
  Widget build(BuildContext context) => Container(
    height: 40,
    padding: const EdgeInsets.symmetric(horizontal: 14),
    alignment: Alignment.center,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: AppColors.ink.withValues(alpha: 0.25),
        width: 1.5,
      ),
    ),
    child: const Text(
      AppConstants.appName,
      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
    ),
  );
}

class _CampusPill extends StatelessWidget {
  const _CampusPill();

  @override
  Widget build(BuildContext context) => Container(
    height: 40,
    padding: const EdgeInsets.symmetric(horizontal: 14),
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: AppColors.white.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(20),
    ),
    child: const Text(
      'ADIT',
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
    ),
  );
}

/// "Report campus issues and **track every fix**".
class AuthHeadline extends StatelessWidget {
  const AuthHeadline({super.key});

  @override
  Widget build(BuildContext context) => Text.rich(
    const TextSpan(
      children: [
        TextSpan(text: 'Report campus issues and\n'),
        TextSpan(
          text: 'track every fix',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ],
    ),
    textAlign: TextAlign.center,
    style: const TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w500,
      height: 1.25,
      letterSpacing: -0.48,
      color: AppColors.ink,
    ),
  );
}

/// The design's illustration slot, drawn with shapes: a report (wrench)
/// travelling along a dashed track to a fix (check), over soft stripes.
class AuthIllustration extends StatelessWidget {
  const AuthIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        height: 150,
        child: Stack(
          fit: StackFit.expand,
          children: [
            StripedPlaceholder(
              radius: AppRadii.card,
              colors: (
                AppColors.white.withValues(alpha: 0.18),
                AppColors.white.withValues(alpha: 0.08),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Row(
                children: [
                  _Node(
                    icon: Icons.build_outlined,
                    background: AppColors.white,
                    foreground: AppColors.ink,
                  ),
                  const Expanded(child: _DashedTrack()),
                  _Node(
                    icon: Icons.schedule,
                    background: AppColors.periwinkleLight,
                    foreground: AppColors.ink,
                    small: true,
                  ),
                  const Expanded(child: _DashedTrack()),
                  _Node(
                    icon: Icons.check,
                    background: AppColors.ink,
                    foreground: AppColors.white,
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

class _Node extends StatelessWidget {
  const _Node({
    required this.icon,
    required this.background,
    required this.foreground,
    this.small = false,
  });

  final IconData icon;
  final Color background;
  final Color foreground;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final size = small ? 44.0 : 64.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      child: Icon(icon, size: size * 0.42, color: foreground),
    );
  }
}

class _DashedTrack extends StatelessWidget {
  const _DashedTrack();

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final count = (c.maxWidth / 10).floor().clamp(1, 40);
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var i = 0; i < count - 1; i++)
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.ink.withValues(alpha: 0.35),
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      );
    },
  );
}
