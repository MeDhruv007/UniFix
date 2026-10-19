import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// The launch loader (design handoff "UniFix splash"): orange screen, the
/// "Pill F" mark builds itself once (~1 s), and an indeterminate bar runs
/// under the wordmark while the app loads.
class UniFixLoader extends StatefulWidget {
  const UniFixLoader({super.key});

  /// How long the mark takes to build; the app stays on the loader at
  /// least this long.
  static const buildDuration = Duration(milliseconds: 1000);

  /// Minimum time on screen at launch: the build plus a moment to see the
  /// finished mark and a full sweep of the bar, so it never just flashes.
  static const minimumShow = Duration(milliseconds: 2200);

  @override
  State<UniFixLoader> createState() => _UniFixLoaderState();
}

class _UniFixLoaderState extends State<UniFixLoader>
    with TickerProviderStateMixin {
  static const _ease = Cubic(0.5, 0, 0.2, 1);

  late final AnimationController _build = AnimationController(
    vsync: this,
    duration: UniFixLoader.buildDuration,
  );
  late final AnimationController _bar = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  );

  late final Animation<double> _stem = _part(0, 545);
  late final Animation<double> _topArm = _part(150, 695);
  late final Animation<double> _midArm = _part(300, 845);
  late final Animation<double> _dot =
      TweenSequence<double>([
        TweenSequenceItem(
          tween: Tween(begin: 0.0, end: 1.25).chain(CurveTween(curve: _ease)),
          weight: 340,
        ),
        TweenSequenceItem(
          tween: Tween(begin: 1.25, end: 1.0).chain(CurveTween(curve: _ease)),
          weight: 205,
        ),
      ]).animate(
        CurvedAnimation(parent: _build, curve: const Interval(0.45, 0.995)),
      );

  bool _started = false;

  Animation<double> _part(int startMs, int endMs) => CurvedAnimation(
    parent: _build,
    curve: Interval(startMs / 1000, endMs / 1000, curve: _ease),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      // Reduced motion: the mark fully built, nothing moving.
      _build.value = 1;
    } else {
      _build.forward();
      _bar.repeat();
    }
  }

  @override
  void dispose() {
    _build.dispose();
    _bar.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: AppColors.orange,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: AppColors.orange,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Material(
        color: AppColors.orange,
        child: Semantics(
          label: 'UniFix is loading',
          liveRegion: true,
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: ExcludeSemantics(
                    child: SizedBox.square(
                      dimension: 200,
                      child: AnimatedBuilder(
                        animation: _build,
                        builder: (context, _) => Stack(
                          children: [
                            _pill(52, 40, 34, 120, _stem.value, axis: _Axis.y),
                            _pill(52, 40, 98, 34, _topArm.value),
                            _pill(52, 86, 70, 34, _midArm.value),
                            Positioned(
                              left: 130,
                              top: 86,
                              width: 34,
                              height: 34,
                              child: Transform.scale(
                                scale: _dot.value,
                                child: const DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: AppColors.white,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  40,
                  0,
                  40,
                  56 + MediaQuery.paddingOf(context).bottom,
                ),
                child: ExcludeSemantics(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'UniFix',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 26 * -0.045,
                          color: AppColors.ink,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _ProgressTrack(bar: _bar, animate: !reduced),
                      const SizedBox(height: 14),
                      const Text(
                        'ADIT CAMPUS',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 11 * 0.12,
                          color: AppColors.ink,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// One black pill of the mark, growing from its top (stem) or left (arms).
  static Widget _pill(
    double left,
    double top,
    double width,
    double height,
    double t, {
    _Axis axis = _Axis.x,
  }) => Positioned(
    left: left,
    top: top,
    width: width,
    height: height,
    child: Transform.scale(
      scaleX: axis == _Axis.x ? t : 1,
      scaleY: axis == _Axis.y ? t : 1,
      alignment: axis == _Axis.x
          ? Alignment.centerLeft
          : Alignment.topCenter,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.ink,
          borderRadius: BorderRadius.circular(17),
        ),
      ),
    ),
  );
}

enum _Axis { x, y }

/// 120 × 4 track with a 48 dp segment sweeping across (indeterminate).
class _ProgressTrack extends StatelessWidget {
  const _ProgressTrack({required this.bar, required this.animate});

  final AnimationController bar;
  final bool animate;

  static const _segment = 48.0;
  static const _ease = Cubic(0.6, 0, 0.4, 1);

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(2),
    child: Container(
      width: 120,
      height: 4,
      color: AppColors.ink.withValues(alpha: 0.15),
      alignment: Alignment.centerLeft,
      child: animate
          ? AnimatedBuilder(
              animation: bar,
              builder: (context, child) => Transform.translate(
                // −100% → +250% of the segment's own width.
                offset: Offset(
                  _segment * (-1 + 3.5 * _ease.transform(bar.value)),
                  0,
                ),
                child: child,
              ),
              child: _bar(),
            )
          : null,
    ),
  );

  static Widget _bar() => Container(
    width: _segment,
    height: 4,
    decoration: BoxDecoration(
      color: AppColors.ink,
      borderRadius: BorderRadius.circular(2),
    ),
  );
}
