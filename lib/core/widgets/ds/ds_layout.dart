import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_colors.dart';
import 'ds_controls.dart';

/// Top bar used by pushed screens: circle back button, centred bold title,
/// optional trailing widget (design screens 02, 05, 13...).
class DsTopBar extends StatelessWidget implements PreferredSizeWidget {
  const DsTopBar({
    super.key,
    this.title,
    this.trailing,
    this.onBack,
    this.backIcon = Icons.arrow_back,
    this.showBack = true,
  });

  final String? title;
  final Widget? trailing;

  /// Defaults to popping the route.
  final VoidCallback? onBack;

  /// Use [Icons.close] for modal-style screens like "New report".
  final IconData backIcon;
  final bool showBack;

  @override
  Size get preferredSize => const Size.fromHeight(68);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSizes.gutter,
          8,
          AppSizes.gutter,
          12,
        ),
        child: Row(
          children: [
            if (showBack)
              CircleIconButton(
                icon: backIcon,
                tooltip: backIcon == Icons.close ? 'Close' : 'Back',
                onPressed: onBack ?? () => context.pop(),
              )
            else
              const SizedBox(width: AppSizes.iconButton),
            Expanded(
              child: title == null
                  ? const SizedBox.shrink()
                  : Text(
                      title!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
            SizedBox(
              width: AppSizes.iconButton,
              child: Center(child: trailing),
            ),
          ],
        ),
      ),
    );
  }
}

/// Large left-aligned screen title with a subtitle (Campus feed / My
/// reports / Needs triage) and an optional trailing circle button.
class DsPageHeader extends StatelessWidget {
  const DsPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(AppSizes.gutter, 12, AppSizes.gutter, 0),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.44,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
            ],
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

/// Pill-shaped search field (design: 52px, #F3F4F8, ring icon).
class DsSearchField extends StatelessWidget {
  const DsSearchField({
    super.key,
    required this.hint,
    this.controller,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.readOnly = false,
  });

  final String hint;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  /// With [readOnly], acts as a button that opens search elsewhere.
  final VoidCallback? onTap;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        onTap: onTap,
        readOnly: readOnly,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: hint,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          prefixIcon: const Padding(
            padding: EdgeInsets.only(left: 18, right: 10),
            child: Icon(Icons.search, size: 20, color: AppColors.textSecondary),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 0),
          suffixIcon: controller == null
              ? null
              : ValueListenableBuilder<TextEditingValue>(
                  valueListenable: controller!,
                  builder: (context, value, _) => value.text.isEmpty
                      ? const SizedBox.shrink()
                      : IconButton(
                          tooltip: 'Clear search',
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () {
                            controller!.clear();
                            onChanged?.call('');
                          },
                        ),
                ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(26),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(26),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(26),
            borderSide: const BorderSide(color: AppColors.ink, width: 1.5),
          ),
        ),
      ),
    );
  }
}

/// One destination in [DsBottomNav].
class DsNavItem {
  const DsNavItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

/// The design's 76px bottom bar. With [onCenterTap], a black "+" circle sits
/// in the middle slot (student nav: Home · Feed · + · Mine · Profile).
class DsBottomNav extends StatelessWidget {
  const DsBottomNav({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
    this.onCenterTap,
    this.centerTooltip = 'Report an issue',
  });

  final List<DsNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback? onCenterTap;
  final String centerTooltip;

  @override
  Widget build(BuildContext context) {
    final slots = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      if (onCenterTap != null && i == items.length ~/ 2) {
        slots.add(
          Expanded(
            child: Center(
              child: Tooltip(
                message: centerTooltip,
                child: Material(
                  color: AppColors.ink,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: onCenterTap,
                    child: const SizedBox.square(
                      dimension: AppSizes.fab,
                      child: Icon(Icons.add, color: AppColors.white, size: 26),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }
      final selected = i == currentIndex;
      final item = items[i];
      slots.add(
        Expanded(
          child: Semantics(
            selected: selected,
            button: true,
            label: item.label,
            child: InkResponse(
              onTap: () => onTap(i),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    selected ? item.selectedIcon : item.icon,
                    size: 22,
                    color: selected
                        ? AppColors.periwinkle
                        : AppColors.textTertiary,
                  ),
                  const SizedBox(height: 4),
                  ExcludeSemantics(
                    child: Text(
                      item.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: selected
                            ? AppColors.ink
                            : AppColors.textTertiary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: AppSizes.bottomNav,
          child: Row(children: slots),
        ),
      ),
    );
  }
}
