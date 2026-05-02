import 'package:flutter/material.dart';

/// Slow continuous 360° rotation — used in the main sheet header and nav bar.
class SpinningSparkle extends StatefulWidget {
  const SpinningSparkle({super.key, required this.size, required this.color});
  final double size;
  final Color color;

  @override
  State<SpinningSparkle> createState() => SpinningSparkleState();
}

class SpinningSparkleState extends State<SpinningSparkle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RotationTransition(
        turns: _ctrl,
        child: Icon(Icons.auto_awesome_rounded,
            size: widget.size, color: widget.color),
      );
}

/// Three staggered stars that pop in and fade out sequentially —
/// used in the "What is Smart Insight?" dialog.
class _SequentialStarsSparkle extends StatefulWidget {
  const _SequentialStarsSparkle({required this.color});
  final Color color;

  @override
  State<_SequentialStarsSparkle> createState() =>
      _SequentialStarsSparkleState();
}

class _SequentialStarsSparkleState extends State<_SequentialStarsSparkle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  // opacity: 0→1→0 within each star's interval
  late final Animation<double> _op1, _op2, _op3;
  // scale: elastic pop-in then hold within each star's interval
  late final Animation<double> _sc1, _sc2, _sc3;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();

    // Star 1 (large, center-left):  0.00 – 0.45
    // Star 2 (medium, upper-right): 0.30 – 0.75
    // Star 3 (small,  lower-right): 0.58 – 0.98
    // Gaps at the end give a brief "all dark" pause before the next cycle.
    _op1 = _fadeSequence(0.00, 0.45);
    _sc1 = _popScale(0.00, 0.45);
    _op2 = _fadeSequence(0.30, 0.75);
    _sc2 = _popScale(0.30, 0.75);
    _op3 = _fadeSequence(0.58, 0.98);
    _sc3 = _popScale(0.58, 0.98);
  }

  /// Opacity 0 → 1 → 0 over the given interval (30 % in / 40 % hold / 30 % out).
  Animation<double> _fadeSequence(double begin, double end) =>
      TweenSequence<double>([
        TweenSequenceItem(
          tween: Tween(begin: 0.0, end: 1.0)
              .chain(CurveTween(curve: Curves.easeOut)),
          weight: 30,
        ),
        TweenSequenceItem(tween: ConstantTween(1.0), weight: 40),
        TweenSequenceItem(
          tween: Tween(begin: 1.0, end: 0.0)
              .chain(CurveTween(curve: Curves.easeIn)),
          weight: 30,
        ),
      ]).animate(CurvedAnimation(
        parent: _ctrl,
        curve: Interval(begin, end),
      ));

  /// Scale 0 → 1 (elastic pop) then holds at 1 over the given interval.
  Animation<double> _popScale(double begin, double end) =>
      TweenSequence<double>([
        TweenSequenceItem(
          tween: Tween(begin: 0.0, end: 1.0)
              .chain(CurveTween(curve: Curves.elasticOut)),
          weight: 45,
        ),
        TweenSequenceItem(tween: ConstantTween(1.0), weight: 55),
      ]).animate(CurvedAnimation(
        parent: _ctrl,
        curve: Interval(begin, end),
      ));

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 44,
        height: 44,
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) => Stack(
            children: [
              // Large star — center-left
              Positioned(
                left: 6,
                top: 10,
                child: _Star(
                    size: 26,
                    color: widget.color,
                    scale: _sc1.value,
                    opacity: _op1.value),
              ),
              // Medium star — upper-right
              Positioned(
                right: 0,
                top: 0,
                child: _Star(
                    size: 17,
                    color: widget.color,
                    scale: _sc2.value,
                    opacity: _op2.value),
              ),
              // Small star — lower-right
              Positioned(
                right: 1,
                bottom: 0,
                child: _Star(
                    size: 11,
                    color: widget.color,
                    scale: _sc3.value,
                    opacity: _op3.value),
              ),
            ],
          ),
        ),
      );
}

class _Star extends StatelessWidget {
  const _Star({
    required this.size,
    required this.color,
    required this.scale,
    required this.opacity,
  });
  final double size;
  final Color color;
  final double scale;
  final double opacity;

  @override
  Widget build(BuildContext context) => Opacity(
        opacity: opacity.clamp(0.0, 1.0),
        child: Transform.scale(
          scale: scale,
          child: Icon(Icons.auto_awesome_rounded, size: size, color: color),
        ),
      );
}
