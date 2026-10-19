import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'ds/ds_access.dart';

/// Compact spinner. Also used inline (e.g. a list's "loading more" row),
/// so it stays small.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) => const Center(
    child: SizedBox.square(
      dimension: 28,
      child: CircularProgressIndicator(
        strokeWidth: 3,
        color: AppColors.ink,
        backgroundColor: AppColors.periwinkleLight,
        semanticsLabel: 'Loading',
      ),
    ),
  );
}

/// Empty state in the design's ring style (screen 14).
class EmptyView extends StatelessWidget {
  const EmptyView({
    super.key,
    required this.message,
    this.icon = Icons.inbox_outlined,
  });

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) => _MessageView(
    halo: HaloIcon(icon: icon),
    message: message,
  );
}

/// Error state: dark ring icon and a black "Try again" pill.
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => _MessageView(
    halo: const HaloIcon(
      icon: Icons.priority_high_rounded,
      innerColor: AppColors.ink,
      foreground: AppColors.white,
    ),
    message: message,
    action: onRetry == null
        ? null
        : FilledButton(
            onPressed: onRetry,
            style: FilledButton.styleFrom(
              minimumSize: const Size(64, 48),
              padding: const EdgeInsets.symmetric(horizontal: 22),
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            child: const Text('Try again'),
          ),
  );
}

class _MessageView extends StatelessWidget {
  const _MessageView({required this.halo, required this.message, this.action});

  final Widget halo;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          halo,
          const SizedBox(height: 22),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              height: 1.45,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
          if (action != null) ...[const SizedBox(height: 20), action!],
        ],
      ),
    );
    // Scrolls rather than overflowing when given a short, bounded space.
    return LayoutBuilder(
      builder: (context, constraints) => constraints.hasBoundedHeight
          ? Center(child: SingleChildScrollView(child: content))
          : Center(child: content),
    );
  }
}

extension SnackBarX on BuildContext {
  void showSnack(String message, {bool isError = false}) {
    final scheme = Theme.of(this).colorScheme;
    ScaffoldMessenger.of(this)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? scheme.error : null,
        ),
      );
  }
}
