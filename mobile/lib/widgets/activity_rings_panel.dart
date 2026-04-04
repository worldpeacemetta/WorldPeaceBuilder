import 'dart:math';

import 'package:flutter/material.dart';

import '../providers/settings_provider.dart';
import '../theme.dart';

class ActivityRingsPanel extends StatelessWidget {
  const ActivityRingsPanel({super.key, required this.totals, required this.goals});
  final MacroValues totals;
  final MacroGoals goals;

  @override
  Widget build(BuildContext context) {
    final cs = AppColorScheme.of(context);
    final items = [
      _RingItem('Calories', totals.kcal,    goals.kcal,    AppColors.kcal,    'kcal'),
      _RingItem('Protein',  totals.protein,  goals.protein,  AppColors.protein, 'g'),
      _RingItem('Carbs',    totals.carbs,    goals.carbs,    AppColors.carbs,   'g'),
      _RingItem('Fat',      totals.fat,      goals.fat,      AppColors.fat,     'g'),
    ];

    final progresses = items
        .map((it) => it.goal > 0 ? (it.actual / it.goal).clamp(0.0, 1.0) : 0.0)
        .toList();

    return Container(
      color: cs.card,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 150,
            height: 150,
            child: CustomPaint(
              painter: _ActivityRingsPainter(
                progresses: progresses,
                colors: items.map((it) => it.color).toList(),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: items.asMap().entries.map((e) {
                final it = e.value;
                final isProtein = e.key == 1;
                final over = !isProtein && it.goal > 0 && it.actual > it.goal * 1.05;
                final c = over ? AppColors.danger : it.color;
                final pct = it.goal > 0
                    ? '${(it.actual / it.goal * 100).round()}%'
                    : '—';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: Row(
                    children: [
                      Container(
                          width: 8, height: 8,
                          decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Text(it.label,
                          style: TextStyle(fontSize: 10, color: cs.textMuted)),
                      const Spacer(),
                      Text('${it.actual.round()} / ${it.goal.round()} ${it.unit}',
                          style: TextStyle(fontSize: 10, color: cs.textMuted)),
                      const SizedBox(width: 6),
                      SizedBox(
                        width: 30,
                        child: Text(pct,
                            textAlign: TextAlign.right,
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: c)),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _RingItem {
  final String label, unit;
  final double actual, goal;
  final Color color;
  _RingItem(this.label, this.actual, this.goal, this.color, this.unit);
}

class _ActivityRingsPainter extends CustomPainter {
  const _ActivityRingsPainter({required this.progresses, required this.colors});
  final List<double> progresses;
  final List<Color> colors;

  static const _strokeWidth = 11.0;
  static const _gap = 3.0;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2 - _strokeWidth / 2 - 1;

    for (int i = 0; i < progresses.length; i++) {
      final radius = maxRadius - i * (_strokeWidth + _gap);
      final rect = Rect.fromCircle(center: center, radius: radius);

      canvas.drawArc(rect, -pi / 2, 2 * pi, false,
          Paint()
            ..color = colors[i].withValues(alpha: 0.15)
            ..style = PaintingStyle.stroke
            ..strokeWidth = _strokeWidth
            ..strokeCap = StrokeCap.round);

      final p = progresses[i].clamp(0.0, 1.0);
      if (p > 0) {
        canvas.drawArc(rect, -pi / 2, 2 * pi * p, false,
            Paint()
              ..color = colors[i]
              ..style = PaintingStyle.stroke
              ..strokeWidth = _strokeWidth
              ..strokeCap = StrokeCap.round);
      }
    }
  }

  @override
  bool shouldRepaint(_ActivityRingsPainter old) =>
      old.progresses != progresses || old.colors != colors;
}
