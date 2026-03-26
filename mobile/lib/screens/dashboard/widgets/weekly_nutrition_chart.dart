import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/utils.dart';
import '../../../models/food.dart';
import '../../../providers/date_provider.dart';
import '../../../providers/entries_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../theme.dart';

/// Weekly Nutrition — vertical pill bar grid, inspired by MacroFactor.
///
/// Layout:
///   4 macro rows × 7 day columns
///   Each cell: dark pill with colored fill, white goal-line tick
///   Selected day column: white rounded-rect highlight
///   Right panel: selected-day KPI for each macro
///   Bottom: day-of-week labels + Consumed / Remaining toggle
class WeeklyNutritionChart extends ConsumerStatefulWidget {
  const WeeklyNutritionChart({super.key, required this.date});
  final String date;

  @override
  ConsumerState<WeeklyNutritionChart> createState() =>
      _WeeklyNutritionChartState();
}

class _WeeklyNutritionChartState extends ConsumerState<WeeklyNutritionChart> {
  late String _selectedDay;
  bool _showRemaining = false;

  static const _macroKeys   = ['kcal', 'protein', 'fat', 'carbs'];
  static const _macroLabels = {'kcal': 'Cal', 'protein': 'P', 'fat': 'F', 'carbs': 'C'};
  static const _macroUnits  = {'kcal': 'kcal', 'protein': 'g', 'fat': 'g', 'carbs': 'g'};
  static const _macroColors = {
    'kcal'   : AppColors.kcal,
    'protein': AppColors.protein,
    'fat'    : AppColors.fat,
    'carbs'  : AppColors.carbs,
  };

  @override
  void initState() {
    super.initState();
    _selectedDay = widget.date;
  }

  @override
  void didUpdateWidget(WeeklyNutritionChart old) {
    super.didUpdateWidget(old);
    if (old.date != widget.date) _selectedDay = widget.date;
  }

  double _macroActual(MacroValues t, String key) => switch (key) {
    'kcal'    => t.kcal,
    'protein' => t.protein,
    'fat'     => t.fat,
    _         => t.carbs,
  };

  double _macroGoal(MacroGoals g, String key) => switch (key) {
    'kcal'    => g.kcal,
    'protein' => g.protein,
    'fat'     => g.fat,
    _         => g.carbs,
  };

  @override
  Widget build(BuildContext context) {
    final days  = weekDates(widget.date);
    final goals = ref.watch(settingsProvider).activeGoals;

    final dayTotals = days
        .map((d) => ref.watch(macroTotalsProvider(d)))
        .toList();

    final selIdx    = days.indexOf(_selectedDay).clamp(0, 6);
    final selTotals = dayTotals[selIdx];

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Row(
              children: [
                const Text('Weekly Nutrition',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.chevron_left, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    final prev = DateTime.parse(widget.date)
                        .subtract(const Duration(days: 7));
                    ref.read(dashboardDateProvider.notifier).state =
                        DateFormat('yyyy-MM-dd').format(prev);
                  },
                ),
                const SizedBox(width: 4),
                Text(weekRangeLabel(widget.date),
                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.chevron_right, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: days.last == todayISO()
                      ? null
                      : () {
                          final next = DateTime.parse(widget.date)
                              .add(const Duration(days: 7));
                          if (next.isAfter(DateTime.now())) return;
                          ref.read(dashboardDateProvider.notifier).state =
                              DateFormat('yyyy-MM-dd').format(next);
                        },
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Grid + KPI ───────────────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 7 day columns
                Expanded(
                  child: _DayGrid(
                    days: days,
                    dayTotals: dayTotals,
                    goals: goals,
                    selectedDay: _selectedDay,
                    showRemaining: _showRemaining,
                    macroKeys: _macroKeys,
                    macroColors: _macroColors,
                    onDayTap: (d) => setState(() => _selectedDay = d),
                  ),
                ),
                const SizedBox(width: 12),

                // KPI panel
                SizedBox(
                  width: 86,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _macroKeys.map((key) {
                      final actual = _macroActual(selTotals, key);
                      final goal   = _macroGoal(goals, key);
                      final color  = _macroColors[key]!;
                      final over   = actual > goal && goal > 0;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: SizedBox(
                          height: _barRowHeight + _barGap,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              RichText(
                                text: TextSpan(
                                  children: [
                                    TextSpan(
                                      text: _showRemaining
                                          ? (goal - actual).clamp(0, double.infinity).round().toString()
                                          : actual.round().toString(),
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: over && !_showRemaining
                                            ? AppColors.danger
                                            : color,
                                      ),
                                    ),
                                    TextSpan(
                                      text: ' ${_macroLabels[key]}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: color.withValues(alpha: 0.8),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                'of ${goal.round()} ${_macroUnits[key]}',
                                style: const TextStyle(
                                    fontSize: 9, color: AppColors.textMuted),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Consumed / Remaining toggle ──────────────────────────────────
            Center(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.bg,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ToggleBtn('Consumed', !_showRemaining,
                        () => setState(() => _showRemaining = false)),
                    _ToggleBtn('Remaining', _showRemaining,
                        () => setState(() => _showRemaining = true)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Layout constants ─────────────────────────────────────────────────────────
const _barRowHeight = 64.0;
const _barGap       = 6.0;
const _barWidth     = 26.0;

// ── Day grid: 7 columns, 4 macro-row cells each ──────────────────────────────
class _DayGrid extends StatelessWidget {
  const _DayGrid({
    required this.days,
    required this.dayTotals,
    required this.goals,
    required this.selectedDay,
    required this.showRemaining,
    required this.macroKeys,
    required this.macroColors,
    required this.onDayTap,
  });

  final List<String> days;
  final List<MacroValues> dayTotals;
  final MacroGoals goals;
  final String selectedDay;
  final bool showRemaining;
  final List<String> macroKeys;
  final Map<String, Color> macroColors;
  final ValueChanged<String> onDayTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(7, (col) {
        final day    = days[col];
        final totals = dayTotals[col];
        final isSel  = day == selectedDay;
        final dt     = DateTime.parse(day);
        final isToday = day == todayISO();

        return Expanded(
          child: GestureDetector(
            onTap: () => onDayTap(day),
            behavior: HitTestBehavior.opaque,
            child: Container(
              decoration: isSel
                  ? BoxDecoration(
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.7), width: 1.5),
                      borderRadius: BorderRadius.circular(12),
                    )
                  : null,
              padding: EdgeInsets.symmetric(
                  horizontal: isSel ? 2 : 3, vertical: isSel ? 4 : 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 4 macro cells
                  ...macroKeys.map((key) => Padding(
                    padding: const EdgeInsets.only(bottom: _barGap),
                    child: _BarCell(
                      actual : _macroActual(totals, key),
                      goal   : _macroGoal(goals, key),
                      color  : macroColors[key]!,
                      showRem: showRemaining,
                    ),
                  )),
                  // Day label
                  Text(
                    DateFormat('E').format(dt).substring(0, 1),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
                      color: isToday ? Colors.white : AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  double _macroActual(MacroValues t, String key) => switch (key) {
    'kcal'    => t.kcal,
    'protein' => t.protein,
    'fat'     => t.fat,
    _         => t.carbs,
  };

  double _macroGoal(MacroGoals g, String key) => switch (key) {
    'kcal'    => g.kcal,
    'protein' => g.protein,
    'fat'     => g.fat,
    _         => g.carbs,
  };
}

// ── Single macro bar cell ────────────────────────────────────────────────────
class _BarCell extends StatelessWidget {
  const _BarCell({
    required this.actual,
    required this.goal,
    required this.color,
    required this.showRem,
  });

  final double actual;
  final double goal;
  final Color  color;
  final bool   showRem;

  @override
  Widget build(BuildContext context) {
    final pct    = goal > 0 ? (actual / goal).clamp(0.0, 1.25) : 0.0;
    final over   = pct > 1.0;

    // In "remaining" mode show how much is left (clamped to 0–1).
    final fillPct = showRem
        ? (goal > 0 ? ((goal - actual) / goal).clamp(0.0, 1.0) : 0.0)
        : pct.clamp(0.0, 1.0);

    final barColor = over && !showRem ? AppColors.danger : color;

    return SizedBox(
      width: _barWidth,
      height: _barRowHeight,
      child: CustomPaint(
        painter: _BarPainter(
          fillPct  : fillPct,
          barColor : barColor,
          goalPct  : 1.0, // goal line always at 100% of the track
        ),
      ),
    );
  }
}

class _BarPainter extends CustomPainter {
  const _BarPainter({
    required this.fillPct,
    required this.barColor,
    required this.goalPct,
  });

  final double fillPct;
  final Color  barColor;
  final double goalPct;

  @override
  void paint(Canvas canvas, Size size) {
    const radius = Radius.circular(7);
    final rect   = Offset.zero & size;
    final rRect  = RRect.fromRectAndRadius(rect, radius);

    // ── Background track ──────────────────────────────────────────────────
    canvas.drawRRect(rRect,
        Paint()..color = const Color(0xFF1E2235));

    if (fillPct > 0) {
      // ── Filled portion (from bottom) ────────────────────────────────────
      final fillH  = size.height * fillPct;
      final fillTop = size.height - fillH;
      final fillRect = Rect.fromLTWH(0, fillTop, size.width, fillH);
      canvas.clipRRect(rRect);
      canvas.drawRect(
        fillRect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [barColor, barColor.withValues(alpha: 0.6)],
          ).createShader(fillRect),
      );
      // Reset clip
      canvas.clipRect(rect);
    }

    // ── Goal tick line ───────────────────────────────────────────────────
    final goalY = size.height * (1 - goalPct);
    canvas.drawLine(
      Offset(2, goalY),
      Offset(size.width - 2, goalY),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.45)
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_BarPainter old) =>
      old.fillPct != fillPct || old.barColor != barColor;
}

// ── Toggle button ─────────────────────────────────────────────────────────────
class _ToggleBtn extends StatelessWidget {
  const _ToggleBtn(this.label, this.selected, this.onTap);
  final String label;
  final bool   selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.black : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}
