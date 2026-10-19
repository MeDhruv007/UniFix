import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Circular avatar with a short code (EL, PL, RM...).
class CodeAvatar extends StatelessWidget {
  const CodeAvatar({
    super.key,
    required this.code,
    required this.background,
    required this.foreground,
    this.size = AppSizes.avatar,
  });

  final String code;
  final Color background;
  final Color foreground;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(color: background, shape: BoxShape.circle),
    child: Text(
      code,
      style: TextStyle(
        fontSize: size >= 44 ? 12 : 10,
        fontWeight: FontWeight.w700,
        color: foreground,
      ),
    ),
  );

  /// Initials from a display name ("Rohan Mehta" → "RM").
  static String initialsOf(String? name) {
    final parts = (name ?? '')
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    final first = parts.first.characters.first;
    final last = parts.length > 1 ? parts.last.characters.first : '';
    return (first + last).toUpperCase();
  }
}

/// The design's striped periwinkle placeholder (profile pictures and
/// illustration/photo slots).
class StripedPlaceholder extends StatelessWidget {
  const StripedPlaceholder({
    super.key,
    this.width,
    this.height,
    this.shape = BoxShape.rectangle,
    this.radius = AppRadii.card,
    this.label,
    this.colors = const (AppColors.periwinkle, AppColors.periwinkleMid),
  });

  final double? width;
  final double? height;
  final BoxShape shape;
  final double radius;
  final String? label;
  final (Color, Color) colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: shape,
        borderRadius: shape == BoxShape.circle
            ? null
            : BorderRadius.circular(radius),
      ),
      child: CustomPaint(
        painter: _StripePainter(colors.$1, colors.$2),
        child: label == null
            ? null
            : Center(
                child: Text(
                  label!,
                  style: const TextStyle(
                    fontFamily: 'GeistMono',
                    fontSize: 11,
                    color: AppColors.textOnPeriwinkle,
                  ),
                ),
              ),
      ),
    );
  }
}

class _StripePainter extends CustomPainter {
  _StripePainter(this.a, this.b);

  final Color a;
  final Color b;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = a);
    final stripe = Paint()
      ..color = b
      ..strokeWidth = 5;
    final d = size.width + size.height;
    for (double x = -size.height; x < d; x += 10) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        stripe,
      );
    }
  }

  @override
  bool shouldRepaint(_StripePainter old) => old.a != a || old.b != b;
}

/// Ring showing "step/total" (the design's 2/3 progress ring). Also used for
/// single numbers ("34 fixed this week") via [label].
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.value,
    required this.label,
    this.size = 58,
    this.color = AppColors.ink,
    this.trackColor = const Color(0x26111111),
    this.stroke = 4,
    this.semanticsLabel,
  });

  /// 0..1
  final double value;
  final String label;
  final double size;
  final Color color;
  final Color trackColor;
  final double stroke;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticsLabel ?? label,
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _RingPainter(value.clamp(0, 1), color, trackColor, stroke),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: size >= 56 ? 14 : 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.value, this.color, this.track, this.stroke);

  final double value;
  final Color color;
  final Color track;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track;
    canvas.drawArc(rect, 0, math.pi * 2, false, base);
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * value,
      false,
      base..color = color,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value || old.color != color || old.track != track;
}

/// Three-segment progress bar used on "My reports" cards.
class StepBar extends StatelessWidget {
  const StepBar({super.key, required this.colors}) : assert(colors.length == 3);

  /// Colour of each of the three segments.
  final List<Color> colors;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (var i = 0; i < 3; i++) ...[
        if (i > 0) const SizedBox(width: 6),
        Expanded(
          child: Container(
            height: 4,
            decoration: BoxDecoration(
              color: colors[i],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ],
    ],
  );
}
