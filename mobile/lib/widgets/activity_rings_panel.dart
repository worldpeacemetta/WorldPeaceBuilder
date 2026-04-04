import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/food.dart';
import '../providers/date_provider.dart';
import '../providers/settings_provider.dart';
import '../theme.dart';

class ActivityRingsPanel extends ConsumerStatefulWidget {
  const ActivityRingsPanel({super.key, required this.totals, required this.goals});
  final MacroValues totals;
  final MacroGoals goals;

  @override
  ConsumerState<ActivityRingsPanel> createState() => _ActivityRingsPanelState();
}

class _ActivityRingsPanelState extends ConsumerState<ActivityRingsPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  int _lastActivation = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 840));
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(ActivityRingsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-run the animation when real data arrives (replaces the initial zero state).
    final hadNoData = oldWidget.totals.kcal == 0 && oldWidget.totals.protein == 0
        && oldWidget.totals.carbs == 0 && oldWidget.totals.fat == 0;
    final hasData = widget.totals.kcal > 0 || widget.totals.protein > 0
        || widget.totals.carbs > 0 || widget.totals.fat > 0;
    if (hadNoData && hasData) {
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Replay animation each time the Dashboard tab is tapped.
    final activation = ref.watch(dashboardActivationProvider);
    if (activation != _lastActivation) {
      _lastActivation = activation;
      // Schedule after build to avoid calling forward() mid-frame.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _ctrl.forward(from: 0);
      });
    }

    final cs = AppColorScheme.of(context);
    final items = [
      _RingItem('Calories', widget.totals.kcal,    widget.goals.kcal,    AppColors.kcal,    'kcal'),
      _RingItem('Protein',  widget.totals.protein,  widget.goals.protein,  AppColors.protein, 'g'),
      _RingItem('Carbs',    widget.totals.carbs,    widget.goals.carbs,    AppColors.carbs,   'g'),
      _RingItem('Fat',      widget.totals.fat,      widget.goals.fat,      AppColors.fat,     'g'),
    ];

    final targets = items
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
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (_, __) {
                final t = Curves.easeOut.transform(_ctrl.value);
                return CustomPaint(
                  painter: _ActivityRingsPainter(
                    progresses: targets.map((p) => p * t).toList(),
                    colors: items.map((it) => it.color).toList(),
                  ),
                );
              },
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
