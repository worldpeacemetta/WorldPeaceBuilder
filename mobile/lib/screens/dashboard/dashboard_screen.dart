import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils.dart';
import '../../models/food.dart';
import '../../providers/date_provider.dart';
import '../../providers/entries_provider.dart';
import '../../providers/settings_provider.dart';
import '../../theme.dart';
import '../../widgets/mode_pill.dart';

import 'widgets/food_logging_card.dart';
import 'widgets/weekly_nutrition_chart.dart';
import 'widgets/weight_trend_card.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final date = ref.watch(dashboardDateProvider);
    final totals = ref.watch(macroTotalsProvider(date));
    final goals = ref.watch(settingsProvider).goalsForDate(date);
    final isToday = date == todayISO();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Dashboard'),
            Row(
              children: [
                Text(
                  formatDateFull(date),
                  style: const TextStyle(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w400),
                ),
                const SizedBox(width: 8),
                ModePill(date: date),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () {
              final dt = DateTime.parse(date).subtract(const Duration(days: 1));
              ref.read(dashboardDateProvider.notifier).state =
                  '${dt.year.toString().padLeft(4,'0')}-${dt.month.toString().padLeft(2,'0')}-${dt.day.toString().padLeft(2,'0')}';
            },
          ),
          if (!isToday)
            TextButton(
              onPressed: () => ref.read(dashboardDateProvider.notifier).state = todayISO(),
              child: const Text('Today', style: TextStyle(fontSize: 12)),
            ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: isToday
                ? null
                : () {
                    final dt = DateTime.parse(date).add(const Duration(days: 1));
                    ref.read(dashboardDateProvider.notifier).state =
                        '${dt.year.toString().padLeft(4,'0')}-${dt.month.toString().padLeft(2,'0')}-${dt.day.toString().padLeft(2,'0')}';
                  },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // Macro progress bars
          _MacroProgressCard(totals: totals, goals: goals),
          const SizedBox(height: 16),

          // Food Logging per-meal breakdown
          FoodLoggingCard(date: date),
          const SizedBox(height: 16),

          // Top foods
          _TopFoodsCard(date: date),
          const SizedBox(height: 16),

          // Weekly Nutrition (multi-macro toggle)
          WeeklyNutritionChart(date: date),
          const SizedBox(height: 16),

          // Weight Trend
          const WeightTrendCard(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Macro breakdown — tappable donut + three pills, tap pill to swap into donut
// ---------------------------------------------------------------------------
class _MacroProgressCard extends StatefulWidget {
  const _MacroProgressCard({required this.totals, required this.goals});
  final MacroValues totals;
  final MacroGoals goals;

  @override
  State<_MacroProgressCard> createState() => _MacroProgressCardState();
}

class _MacroProgressCardState extends State<_MacroProgressCard>
    with SingleTickerProviderStateMixin {
  int _featured = 0; // 0=kcal 1=protein 2=carbs 3=fat
  int _prev = 0;
  double _prevPct = 0;

  late final AnimationController _ctrl;

  static const _labels = ['Calories', 'Protein', 'Carbs', 'Fat'];
  static const _units  = ['kcal', 'g', 'g', 'g'];
  static const _colors = <Color>[
    AppColors.kcal, AppColors.protein, AppColors.carbs, AppColors.fat
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
    _ctrl.value = 1.0; // start complete so first render draws full ring
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
    final currPct = _goal(_featured) > 0
        ? (_actual(_featured) / _goal(_featured)).clamp(0.0, 1.0)
        : 0.0;
    final isOver =
        _goal(_featured) > 0 && _actual(_featured) > _goal(_featured);
    final pillIndices =
        [0, 1, 2, 3].where((i) => i != _featured).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Macro Breakdown',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 16),

            // ── Donut ──────────────────────────────────────────────────────
            Center(
              child: SizedBox(
                width: 148,
                height: 148,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Ring animates: shrink old → grow new
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
                        return CustomPaint(
                          size: const Size(148, 148),
                          painter: _DonutPainter(
                            progress: displayPct,
                            color: displayColor,
                            isOver: t >= 1.0 && isOver,
                          ),
                        );
                      },
                    ),
                    // Center text fades + scales in when featured changes
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 260),
                      transitionBuilder: (child, anim) => FadeTransition(
                        opacity: anim,
                        child: ScaleTransition(
                          scale: Tween<double>(begin: 0.75, end: 1.0)
                              .animate(CurvedAnimation(
                                  parent: anim, curve: Curves.easeOut)),
                          child: child,
                        ),
                      ),
                      child: _DonutCenter(
                        key: ValueKey(_featured),
                        actual: _actual(_featured),
                        goal: _goal(_featured),
                        pct: currPct,
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

            // ── Tappable pills ─────────────────────────────────────────────
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
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Center content of the donut
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
    final c = isOver ? AppColors.danger : color;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(actual.round().toString(),
            style: TextStyle(
                fontSize: 28, fontWeight: FontWeight.w700,
                color: isOver ? AppColors.danger : AppColors.textPrimary)),
        Text('/ ${goal.round()} $unit',
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
        const SizedBox(height: 2),
        Text('${(pct * 100).round()}%',
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: c)),
        const SizedBox(height: 1),
        Text(label,
            style: TextStyle(
                fontSize: 9, color: c.withValues(alpha: 0.8),
                letterSpacing: 0.3)),
      ],
    );
  }
}

// Tappable pill (shows tap affordance via slight scale on press)
class _TappablePill extends StatelessWidget {
  const _TappablePill({
    required this.label, required this.actual, required this.goal,
    required this.unit,  required this.color,  required this.onTap,
  });
  final String label, unit;
  final double actual, goal;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final over = goal > 0 && actual > goal;
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
                          fontSize: 10, color: c,
                          fontWeight: FontWeight.w600)),
                ),
                Icon(Icons.keyboard_arrow_up_rounded,
                    size: 12, color: c.withValues(alpha: 0.5)),
              ],
            ),
            const SizedBox(height: 4),
            Text('${actual.round()}$unit',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700, color: c)),
            Text('/ ${goal.round()}$unit',
                style: const TextStyle(
                    fontSize: 10, color: AppColors.textMuted)),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: pct,
                backgroundColor: AppColors.border,
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
  const _DonutPainter(
      {required this.progress, required this.color, required this.isOver});
  final double progress;
  final Color color;
  final bool isOver;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 14;
    const sw = 14.0;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2, 2 * pi, false,
      Paint()
        ..color = AppColors.border
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
      old.progress != progress || old.color != color || old.isOver != isOver;
}

// ---------------------------------------------------------------------------
// Top foods by kcal for the day
// ---------------------------------------------------------------------------
class _TopFoodsCard extends ConsumerStatefulWidget {
  const _TopFoodsCard({required this.date});
  final String date;

  @override
  ConsumerState<_TopFoodsCard> createState() => _TopFoodsCardState();
}

class _TopFoodsCardState extends ConsumerState<_TopFoodsCard> {
  String _macro = 'kcal';

  double _value(MacroValues m) => switch (_macro) {
    'protein' => m.protein,
    'carbs'   => m.carbs,
    'fat'     => m.fat,
    _         => m.kcal,
  };

  String _unit() => _macro == 'kcal' ? 'kcal' : 'g';

  Color _color() => switch (_macro) {
    'protein' => AppColors.protein,
    'carbs'   => AppColors.carbs,
    'fat'     => AppColors.fat,
    _         => AppColors.kcal,
  };

  @override
  Widget build(BuildContext context) {
    final entries = ref.watch(entriesProvider(widget.date)).valueOrNull ?? [];
    if (entries.isEmpty) return const SizedBox.shrink();

    final sorted = [...entries]
      ..sort((a, b) => _value(b.macros).compareTo(_value(a.macros)));
    final top5 = sorted.take(5).toList();
    final maxVal = _value(top5.first.macros);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header + macro toggle
            Row(
              children: [
                const Expanded(
                  child: Text('Top Foods Today',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                ),
                _MacroToggle(selected: _macro, onChanged: (v) => setState(() => _macro = v)),
              ],
            ),
            const SizedBox(height: 12),
            ...top5.map((e) {
              final val = _value(e.macros);
              final pct = maxVal > 0 ? val / maxVal : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            e.food?.displayName ?? e.foodId,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${val.round()} ${_unit()}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _color(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: pct.toDouble(),
                        minHeight: 3,
                        backgroundColor: AppColors.border,
                        valueColor: AlwaysStoppedAnimation(_color()),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _MacroToggle extends StatelessWidget {
  const _MacroToggle({required this.selected, required this.onChanged});
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    const macros = ['kcal', 'protein', 'carbs', 'fat'];
    const colors = {
      'kcal': AppColors.kcal, 'protein': AppColors.protein,
      'carbs': AppColors.carbs, 'fat': AppColors.fat,
    };
    const labels = {
      'kcal': 'Cal', 'protein': 'Pro', 'carbs': 'Carb', 'fat': 'Fat',
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: macros.map((m) {
        final active = m == selected;
        final color = colors[m]!;
        return GestureDetector(
          onTap: () => onChanged(m),
          child: Container(
            margin: const EdgeInsets.only(left: 4),
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: active ? color.withValues(alpha: 0.2) : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: active ? color : AppColors.border,
                width: active ? 1.2 : 1,
              ),
            ),
            child: Text(
              labels[m]!,
              style: TextStyle(
                fontSize: 10,
                fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                color: active ? color : AppColors.textMuted,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
