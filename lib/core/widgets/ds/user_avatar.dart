import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'ds_visuals.dart';

/// Preset profile avatars. The ids are stored by the API (`users.avatar`)
/// and must match `AVATARS` in backend/src/domain.js.
enum AvatarPreset {
  spark(
    'spark',
    'Spark',
    Icons.auto_awesome,
    AppColors.periwinkle,
    AppColors.ink,
  ),
  leaf('leaf', 'Leaf', Icons.eco, Color(0xFFBFE8CF), AppColors.ink),
  wave(
    'wave',
    'Wave',
    Icons.water_drop,
    AppColors.periwinkleLight,
    AppColors.ink,
  ),
  sun('sun', 'Sun', Icons.wb_sunny, AppColors.orange, AppColors.ink),
  star('star', 'Star', Icons.star_rounded, AppColors.pink, AppColors.ink),
  bolt('bolt', 'Bolt', Icons.bolt, AppColors.ink, AppColors.white),
  heart(
    'heart',
    'Heart',
    Icons.favorite,
    AppColors.statusReopened,
    AppColors.ink,
  ),
  book(
    'book',
    'Book',
    Icons.menu_book,
    AppColors.statusReported,
    AppColors.ink,
  );

  const AvatarPreset(
    this.id,
    this.label,
    this.icon,
    this.background,
    this.foreground,
  );

  final String id;
  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;

  static AvatarPreset? fromId(String? id) {
    for (final p in values) {
      if (p.id == id) return p;
    }
    return null;
  }
}

/// A user's avatar: their chosen preset, or the design's striped periwinkle
/// circle when none is set.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.avatarId,
    this.name,
    this.size = AppSizes.avatar,
  });

  final String? avatarId;

  /// Used for the accessibility label.
  final String? name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final preset = AvatarPreset.fromId(avatarId);
    final label = name == null ? 'Profile picture' : '$name, profile picture';
    return Semantics(
      image: true,
      label: label,
      child: ExcludeSemantics(
        child: preset == null
            ? StripedPlaceholder(
                width: size,
                height: size,
                shape: BoxShape.circle,
              )
            : Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: preset.background,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  preset.icon,
                  size: size * 0.48,
                  color: preset.foreground,
                ),
              ),
      ),
    );
  }
}

/// Bottom sheet grid for choosing an avatar. Returns the chosen preset id,
/// `''` for "Default", or null if dismissed.
Future<String?> showAvatarPicker(
  BuildContext context, {
  required String? currentId,
}) {
  return showModalBottomSheet<String>(
    context: context,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSizes.gutter,
          0,
          AppSizes.gutter,
          20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Choose an avatar',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.95,
              children: [
                _AvatarOption(
                  label: 'Default',
                  selected: AvatarPreset.fromId(currentId) == null,
                  onTap: () => Navigator.pop(context, ''),
                  child: const UserAvatar(avatarId: null, size: 60),
                ),
                for (final p in AvatarPreset.values)
                  _AvatarOption(
                    label: p.label,
                    selected: p.id == currentId,
                    onTap: () => Navigator.pop(context, p.id),
                    child: UserAvatar(avatarId: p.id, size: 60),
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _AvatarOption extends StatelessWidget {
  const _AvatarOption({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.child,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '$label avatar',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.card),
        child: Container(
          decoration: BoxDecoration(
            color: selected ? AppColors.surface : null,
            borderRadius: BorderRadius.circular(AppRadii.card),
            border: Border.all(
              color: selected ? AppColors.ink : AppColors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: ExcludeSemantics(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                child,
                const SizedBox(height: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
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
