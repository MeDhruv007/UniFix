import 'package:flutter/material.dart';

/// Wraps a horizontally scrolling widget (a [ListView] or
/// [SingleChildScrollView] using [controller]) with a soft edge fade.
///
/// The fade on a side appears only while there is more content to scroll to
/// in that direction, and disappears once you reach the end — a visual hint
/// that a row (category chips, issue cards) continues off-screen, which a
/// hard-clipped edge doesn't convey on its own.
class FadeEdgeScroll extends StatefulWidget {
  const FadeEdgeScroll({
    super.key,
    required this.controller,
    required this.child,
    this.fadeWidth = 28,
  });

  final ScrollController controller;
  final Widget child;
  final double fadeWidth;

  @override
  State<FadeEdgeScroll> createState() => _FadeEdgeScrollState();
}

class _FadeEdgeScrollState extends State<FadeEdgeScroll> {
  bool _fadeStart = false;
  bool _fadeEnd = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_update);
    // The initial metrics aren't available until after the first layout.
    WidgetsBinding.instance.addPostFrameCallback((_) => _update());
  }

  @override
  void didUpdateWidget(FadeEdgeScroll oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_update);
      widget.controller.addListener(_update);
      WidgetsBinding.instance.addPostFrameCallback((_) => _update());
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_update);
    super.dispose();
  }

  void _update() {
    if (!widget.controller.hasClients) return;
    final position = widget.controller.position;
    final fadeStart = position.pixels > position.minScrollExtent + 1;
    final fadeEnd = position.pixels < position.maxScrollExtent - 1;
    if (fadeStart != _fadeStart || fadeEnd != _fadeEnd) {
      setState(() {
        _fadeStart = fadeStart;
        _fadeEnd = fadeEnd;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_fadeStart && !_fadeEnd) return widget.child;
    return ShaderMask(
      shaderCallback: (bounds) {
        final stop = (widget.fadeWidth / bounds.width).clamp(0.0, 0.5);
        return LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            _fadeStart ? Colors.transparent : Colors.white,
            Colors.white,
            Colors.white,
            _fadeEnd ? Colors.transparent : Colors.white,
          ],
          stops: [0, stop, 1 - stop, 1],
        ).createShader(bounds);
      },
      blendMode: BlendMode.dstIn,
      child: widget.child,
    );
  }
}
