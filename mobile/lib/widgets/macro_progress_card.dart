import 'dart:math';

import 'package:flutter/material.dart';

import '../models/food.dart';
import '../providers/settings_provider.dart';
import '../theme.dart';

class MacroProgressCard extends StatefulWidget {
  const MacroProgressCard({super.key, required this.totals, required this.goals});
  final MacroValues totals;
  final MacroGoals goals;

  @override
  State<MacroProgressCard> createState() => _MacroProgressCardState();
}

class _MacroProgressCardState extends State<MacroProgressCard>
    with SingleTickerProviderStateMixin {
  int _featured = 0;
  int _prev = 0;
  double _prevPct = 0;

  late final AnimationController _ctrl;

  static const _labels = ['Calories', 'Protein', 'Carbs', 'Fat'];
  static const _units  = ['kcal', 'g', 'g', 'g'];
  static const _colors = <Color>[
    AppColors.kcal, AppColors.protein, AppColors.carbs, AppColors.fat,
  ];

  double _actual(int i) {
    final t = widget.totals;
    return switch (i) { 1 => t.protein, 2 => t.carbs, 3 => t.fat, _ => t.kcal };
  }

  double _goal(int i) {
    final g = widget.goals;
    return switch (i) { 1 => g.protein, 2 => g.carbs, 3 => g.fat, _ => g.kcal };
  }

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 420));
    _ctrl.value = 1.0;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _selectFeatured(int index) {
    if (index == _featured) return;
    _prev = _featured;
    _prevPct = _goal(_featured) > 0
        ? (_actual(_featured) / _goal(_featured)).clamp(0.0, 1.0)
        : 0.0;
    setState(() => _featured = index);
    _ctrl.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final currRaw = _goal(_featured) > 0
        ? _actual(_featured) / _goal(_featured)
        : 0.0;
    final currPct = currRaw.clamp(0.0, 1.0);
    final isOver = _featured != 1 &&
        _goal(_featured) > 0 &&
        _actual(_featured) > _goal(_featured) * 1.05;
    final pillIndices = [0, 1, 2, 3].where((i) => i != _featured).toList();

    final cs = AppColorScheme.of(context);
    return Container(
      color: cs.card,
      padding: const EdgeInsets.all(16),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Macro Breakdown',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 3),
            Text('Tap a pill to switch the active macro',
                style: TextStyle(
                    fontSize: 10,
                    color: cs.textMuted,
                    fontStyle: FontStyle.italic)),
            const SizedBox(height: 16),
            Center(
              child: SizedBox(
                width: 148,
                height: 148,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AnimatedBuilder(
                      animation: _ctrl,
                      builder: (_, __) {
                        final t = _ctrl.value;
                        final double displayPct;
                        final Color displayColor;
                        if (t < 0.5) {
                          displayPct = _prevPct * (1 - t / 0.5);
                          displayColor = _colors[_prev];
                        } else {
                          displayPct = currPct * ((t - 0.5) / 0.5);
                          displayColor = _colors[_featured];
                        }
                        final cs = AppColorScheme.of(context);
                        return CustomPaint(
                          size: const Size(148, 148),
                          painter: _DonutPainter(
                            progress: displayPct,
                            color: displayColor,
                            isOver: t >= 1.0 && isOver,
                            borderColor: cs.border,
                          ),
                        );
                      },
                    ),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 260),
                      transitionBuilder: (child, anim) => FadeTransition(
                        opacity: anim,
                        child: ScaleTransition(
                          scale: Tween<double>(begin: 0.75, end: 1.0).animate(
                              CurvedAnimation(parent: anim, curve: Curves.easeOut)),
                          child: child,
                        ),
                      ),
                      child: _DonutCenter(
                        key: ValueKey(_featured),
                        actual: _actual(_featured),
                        goal: _goal(_featured),
                        pct: currRaw,
                        label: _labels[_featured],
                        unit: _units[_featured],
                        color: _colors[_featured],
                        isOver: isOver,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                for (int k = 0; k < pillIndices.length; k++) ...[
                  if (k > 0) const SizedBox(width: 8),
                  Expanded(
                    child: _TappablePill(
                      label: _labels[pillIndices[k]],
                      actual: _actual(pillIndices[k]),
                      goal: _goal(pillIndices[k]),
                      unit: _units[pillIndices[k]],
                      color: _colors[pillIndices[k]],
                      onTap: () => _selectFeatured(pillIndices[k]),
                      isProtein: pillIndices[k] == 1,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
    );
  }
}

class _DonutCenter extends StatelessWidget {
  const _DonutCenter({
    super.key,
    required this.actual, required this.goal, required this.pct,
    required this.label,  required this.unit,  required this.color,
    required this.isOver,
  });
  final double actual, goal, pct;
  final String label, unit;
  final Color color;
  final bool isOver;

  @override
  Widget build(BuildContext context) {
    final cs = AppColorScheme.of(context);
    final c = isOver ? AppColors.danger : color;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(actual.round().toString(),
            style: TextStyle(
                fontSize: 28, fontWeight: FontWeight.w700,
                color: isOver ? AppColors.danger : cs.textPrimary)),
        Text('/ ${goal.round()} $unit',
            style: TextStyle(fontSize: 11, color: cs.textMuted)),
        const SizedBox(height: 2),
        Text('${(pct * 100).round()}%',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c)),
        const SizedBox(height: 1),
        Text(label,
            style: TextStyle(
                fontSize: 9, color: c.withValues(alpha: 0.8), letterSpacing: 0.3)),
      ],
    );
  }
}

class _TappablePill extends StatelessWidget {
  const _TappablePill({
    required this.label, required this.actual, required this.goal,
    required this.unit,  required this.color,  required this.onTap,
    this.isProtein = false,
  });
  final String label, unit;
  final double actual, goal;
  final Color color;
  final VoidCallback onTap;
  final bool isProtein;

  @override
  Widget build(BuildContext context) {
    final cs = AppColorScheme.of(context);
    final over = !isProtein && goal > 0 && actual > goal * 1.05;
    final c = over ? AppColors.danger : color;
    final pct = goal > 0 ? (actual / goal).clamp(0.0, 1.0) : 0.0;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(label,
                      style: TextStyle(
                          fontSize: 10, color: c, fontWeight: FontWeight.w600)),
                ),
                Icon(Icons.keyboard_arrow_up_rounded,
                    size: 12, color: c.withValues(alpha: 0.5)),
              ],
            ),
            const SizedBox(height: 4),
            Text('${actual.round()}$unit',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: c)),
            Text('/ ${goal.round()}$unit',
                style: TextStyle(fontSize: 10, color: cs.textMuted)),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: pct,
                backgroundColor: cs.border,
                valueColor: AlwaysStoppedAnimation(c),
                minHeight: 3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  const _DonutPainter({
    required this.progress, required this.color,
    required this.isOver,   required this.borderColor,
  });
  final double progress;
  final Color color;
  final bool isOver;
  final Color borderColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 14;
    const sw = 14.0;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2, 2 * pi, false,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = sw
        ..strokeCap = StrokeCap.round,
    );

    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -pi / 2, 2 * pi * progress, false,
        Paint()
          ..color = isOver ? AppColors.danger : color
          ..style = PaintingStyle.stroke
          ..strokeWidth = sw
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.progress != progress || old.color != color ||
      old.isOver != isOver || old.borderColor != borderColor;
}
