import 'dart:math';

import 'package:flutter/material.dart';

import '../../theme.dart';

// Donut chart — shows current macro fill + projected addition

class MacroDonut extends StatelessWidget {
  const MacroDonut({
    required this.label,
    required this.addition,
    required this.current,
    required this.goal,
    required this.color,
    required this.unit,
    this.size = 58.0,
  });

  final String label;
  final double addition;
  final double current;
  final double goal;
  final Color color;
  final String unit;
  final double size;

  @override
  Widget build(BuildContext context) {
    final cs = AppColorScheme.of(context);
    final projected = current + addition;
    final overGoal = goal > 0 && projected > goal;
    final addStr = '+${addition.round()}$unit';
    final totalStr = goal > 0
        ? '${projected.round()}/${goal.round()}'
        : '${projected.round()}';

    final innerFont = (size * 9 / 58).floorToDouble();
    final labelFont = (size * 8 / 58).floorToDouble();
    final stroke = size * 5 / 58;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          // Soft red glow on overshoot — keeps macro color intact,
          // two shadow layers fade the warning outward.
          decoration: overGoal
              ? BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.danger.withValues(alpha: 0.28),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                    BoxShadow(
                      color: AppColors.danger.withValues(alpha: 0.10),
                      blurRadius: 20,
                      spreadRadius: 6,
                    ),
                  ],
                )
              : null,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size(size, size),
                painter: _DonutPainter(
                  current: current,
                  addition: addition,
                  goal: goal,
                  color: color,
                  strokeWidth: stroke,
                ),
              ),
              Text(
                addStr,
                style: TextStyle(
                  fontSize: innerFont,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: labelFont,
            fontWeight: FontWeight.w600,
            color: cs.textMuted,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          totalStr,
          style: TextStyle(fontSize: labelFont, color: cs.textMuted),
        ),
      ],
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({
    required this.current,
    required this.addition,
    required this.goal,
    required this.color,
    this.strokeWidth = 5.0,
  });

  final double current;
  final double addition;
  final double goal;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    if (goal <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - strokeWidth;
    final stroke = strokeWidth;
    const start = -pi / 2;
    const full = pi * 2;

    final bg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = color.withValues(alpha: 0.12);
    canvas.drawCircle(center, radius, bg);

    final currentFrac = (current / goal).clamp(0.0, 1.0);
    final projectedFrac = ((current + addition) / goal).clamp(0.0, 1.0);
    final currentSweep = currentFrac * full;
    final addSweep = (projectedFrac - currentFrac) * full;
    final rect = Rect.fromCircle(center: center, radius: radius);

    if (currentSweep > 0.01) {
      canvas.drawArc(
        rect,
        start,
        currentSweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.butt
          ..color = color.withValues(alpha: 0.38),
      );
    }
    if (addSweep > 0.01) {
      canvas.drawArc(
        rect,
        start + currentSweep,
        addSweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.butt
          ..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.current != current ||
      old.addition != addition ||
      old.goal != goal ||
      old.color != color ||
      old.strokeWidth != strokeWidth;
}
