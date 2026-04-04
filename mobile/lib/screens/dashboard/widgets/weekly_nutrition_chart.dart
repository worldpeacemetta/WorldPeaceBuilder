import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/utils.dart';
import '../../../models/food.dart';
import '../../../providers/date_provider.dart';
import '../../../providers/entries_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../theme.dart';
import '../../../widgets/mode_pill.dart';

// ── Layout constants ─────────────────────────────────────────────────────────

/// Height of each macro row (bar track).
const _barRowH  = 82.0;
/// Vertical gap between macro rows.
const _rowGap   = 10.0;
/// Width of each individual pill bar.
const _barW     = 22.0;
/// The track represents goal × _scale so bars can visually overflow the
/// goal-line when consumption exceeds target (no red-color trick needed).
const _scale    = 1.30;
/// Pill corner radius.
const _radius   = Radius.circular(6);

// ── Macro config ─────────────────────────────────────────────────────────────

const _keys   = ['kcal', 'protein', 'carbs', 'fat'];
const _names  = {'kcal': 'Calories', 'protein': 'Protein',
                 'carbs': 'Carbs',   'fat': 'Fat'};
const _units  = {'kcal': 'kcal', 'protein': 'g', 'carbs': 'g', 'fat': 'g'};
Map<String, Color> _colorsFor(BuildContext ctx) => {
  'kcal'   : AppColorScheme.of(ctx).kcalColor,
  'protein': AppColors.protein,
  'carbs'  : AppColors.carbs,
  'fat'    : AppColors.fat,
};

double _actual(MacroValues t, String k) =>
    switch (k) { 'kcal' => t.kcal, 'protein' => t.protein,
                 'fat'  => t.fat,  _ => t.carbs };
double _goal(MacroGoals g, String k) =>
    switch (k) { 'kcal' => g.kcal, 'protein' => g.protein,
                 'fat'  => g.fat,  _ => g.carbs };

// ─────────────────────────────────────────────────────────────────────────────
// Widget
// ─────────────────────────────────────────────────────────────────────────────

class WeeklyNutritionChart extends ConsumerStatefulWidget {
  const WeeklyNutritionChart({super.key, required this.date});
  final String date;

  @override
  ConsumerState<WeeklyNutritionChart> createState() =>
      _WeeklyNutritionChartState();
}

class _WeeklyNutritionChartState
    extends ConsumerState<WeeklyNutritionChart> {
  late String _sel;
  bool _rem = false; // false = Consumed, true = Remaining

  @override
  void initState() {
    super.initState();
    _sel = widget.date;
  }

  @override
  void didUpdateWidget(WeeklyNutritionChart old) {
    super.didUpdateWidget(old);
    if (old.date != widget.date) _sel = widget.date;
  }

  @override
  Widget build(BuildContext context) {
    final cs       = AppColorScheme.of(context);
    final colors   = _colorsFor(context);
    final days     = weekDates(widget.date);
    final settings = ref.watch(settingsProvider);
    final totals   = days.map((d) => ref.watch(macroTotalsProvider(d))).toList();
    final goals    = days.map((d) => settings.goalsForDate(d)).toList();
    final dotColors = days.map((d) => modeColor(settings.modeLabelForDate(d), context)).toList();

    final selIdx    = days.indexOf(_sel).clamp(0, 6);
    final selTotals = totals[selIdx];
    final selGoals  = goals[selIdx];

    // ── total chart height (used by KPI rows to align with bars) ──────────
    final gridH = _keys.length * _barRowH + (_keys.length - 1) * _rowGap;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Header ─────────────────────────────────────────────────────
            Row(
              children: [
                const Text('Weekly Nutrition',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const Spacer(),
                _NavBtn(
                  icon: Icons.chevron_left,
                  onPressed: () {
                    final prev = DateTime.parse(widget.date)
                        .subtract(const Duration(days: 7));
                    ref.read(dashboardDateProvider.notifier).state =
                        DateFormat('yyyy-MM-dd').format(prev);
                  },
                ),
                const SizedBox(width: 4),
                Text(weekRangeLabel(widget.date),
                    style: TextStyle(
                        fontSize: 11, color: AppColorScheme.of(context).textMuted)),
                const SizedBox(width: 4),
                _NavBtn(
                  icon: Icons.chevron_right,
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
            const SizedBox(height: 14),

            // ── Grid + KPI ─────────────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 7-day bar grid
                Expanded(
                  child: _Grid(
                    days: days,
                    totals: totals,
                    goals: goals,
                    dotColors: dotColors,
                    selectedDay: _sel,
                    showRemaining: _rem,
                    onDayTap: (d) => setState(() => _sel = d),
                  ),
                ),
                const SizedBox(width: 10),

                // KPI panel — one row per macro, vertically aligned to bars
                SizedBox(
                  width: 90,
                  height: gridH + 22, // +22 for day-label row below bars
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (int i = 0; i < _keys.length; i++) ...[
                        if (i > 0) const SizedBox(height: _rowGap),
                        _KpiCell(
                          macroKey : _keys[i],
                          actual   : _actual(selTotals, _keys[i]),
                          goal     : _goal(selGoals, _keys[i]),
                          color    : colors[_keys[i]]!,
                          showRem  : _rem,
                          height   : _barRowH,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // ── Consumed / Remaining toggle ─────────────────────────────────
            Center(
              child: Container(
                decoration: BoxDecoration(
                  color: cs.bg,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: cs.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ToggleBtn('Consumed', !_rem,
                        () => setState(() => _rem = false)),
                    _ToggleBtn('Remaining', _rem,
                        () => setState(() => _rem = true)),
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

// ─────────────────────────────────────────────────────────────────────────────
// Grid — 7 columns, 4 macro rows each
// ─────────────────────────────────────────────────────────────────────────────

class _Grid extends StatelessWidget {
  const _Grid({
    required this.days,
    required this.totals,
    required this.goals,
    required this.dotColors,
    required this.selectedDay,
    required this.showRemaining,
    required this.onDayTap,
  });

  final List<String>      days;
  final List<MacroValues> totals;
  final List<MacroGoals>  goals;
  final List<Color>       dotColors;
  final String            selectedDay;
  final bool              showRemaining;
  final ValueChanged<String> onDayTap;

  @override
  Widget build(BuildContext context) {
    final colors = _colorsFor(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(7, (col) {
        final day   = days[col];
        final isSel = day == selectedDay;
        final dt    = DateTime.parse(day);
        final isToday = day == todayISO();

        return Expanded(
          child: GestureDetector(
            onTap: () => onDayTap(day),
            behavior: HitTestBehavior.opaque,
            child: Container(
              decoration: isSel
                  ? BoxDecoration(
                      border: Border.all(
                          color: AppColorScheme.of(context).textMuted.withValues(alpha: 0.6),
                          width: 1.5),
                      borderRadius: BorderRadius.circular(14),
                    )
                  : null,
              padding: EdgeInsets.symmetric(
                  horizontal: isSel ? 1 : 2, vertical: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 4 macro bar cells
                  for (int r = 0; r < _keys.length; r++) ...[
                    if (r > 0) SizedBox(height: _rowGap),
                    Center(
                      child: _BarCell(
                        actual      : _actual(totals[col], _keys[r]),
                        goal        : _goal(goals[col], _keys[r]),
                        color       : colors[_keys[r]]!,
                        showRemaining: showRemaining,
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  // Day letter
                  Builder(builder: (ctx) {
                    final cs = AppColorScheme.of(ctx);
                    return Text(
                      DateFormat('E').format(dt).substring(0, 1),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight:
                            isToday ? FontWeight.w700 : FontWeight.w400,
                        color: isToday
                            ? cs.textPrimary
                            : cs.textMuted,
                      ),
                    );
                  }),
                  const SizedBox(height: 3),
                  // Mode-color dot
                  Container(
                    width: 4, height: 4,
                    decoration: BoxDecoration(
                      color: dotColors[col],
                      shape: BoxShape.circle,
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
}

// ─────────────────────────────────────────────────────────────────────────────
// Single macro bar cell
// ─────────────────────────────────────────────────────────────────────────────

class _BarCell extends StatelessWidget {
  const _BarCell({
    required this.actual,
    required this.goal,
    required this.color,
    required this.showRemaining,
  });

  final double actual;
  final double goal;
  final Color  color;
  final bool   showRemaining;

  @override
  Widget build(BuildContext context) {
    // Track represents goal × _scale — provides headroom to visualise overflow
    // without changing bar color to red.
    final trackMax = goal * _scale;

    double fillFrac;
    if (showRemaining) {
      // Remaining: shrinks toward 0 as the user eats more.
      final remaining = (goal - actual).clamp(0.0, goal);
      fillFrac = goal > 0 ? remaining / trackMax : 0.0;
    } else {
      // Consumed: grows upward; can exceed the goal line.
      fillFrac = trackMax > 0
          ? (actual / trackMax).clamp(0.0, 1.0)
          : 0.0;
    }

    // Goal line sits at goal/trackMax from bottom (= 1/_scale ≈ 77%).
    final goalLineFrac = goal > 0 ? 1.0 / _scale : 1.0;

    final cs = AppColorScheme.of(context);
    return SizedBox(
      width: _barW,
      height: _barRowH,
      child: CustomPaint(
        painter: _BarPainter(
          fillFrac    : fillFrac,
          goalLineFrac: goalLineFrac,
          color       : color,
          trackColor  : cs.card,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bar painter
// ─────────────────────────────────────────────────────────────────────────────

class _BarPainter extends CustomPainter {
  const _BarPainter({
    required this.fillFrac,
    required this.goalLineFrac,
    required this.color,
    required this.trackColor,
  });

  final double fillFrac;
  final double goalLineFrac;
  final Color  color;
  final Color  trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final rr = RRect.fromRectAndRadius(Offset.zero & size, _radius);

    // ── Background track ──────────────────────────────────────────────────
    canvas.drawRRect(rr, Paint()..color = trackColor);

    // ── Filled portion (grows from bottom) ────────────────────────────────
    if (fillFrac > 0) {
      final fillH   = size.height * fillFrac;
      final fillTop = size.height - fillH;
      final fillRect = Rect.fromLTWH(0, fillTop, size.width, fillH);

      canvas.save();
      canvas.clipRRect(rr);
      canvas.drawRect(
        fillRect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              color.withValues(alpha: 1.0),
              color.withValues(alpha: 0.55),
            ],
          ).createShader(fillRect),
      );
      canvas.restore();
    }

    // ── Goal-line tick ────────────────────────────────────────────────────
    // Drawn AFTER the fill so it's always visible.
    final goalY = size.height * (1 - goalLineFrac);
    final tickPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.55)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(3, goalY),
      Offset(size.width - 3, goalY),
      tickPaint,
    );
  }

  @override
  bool shouldRepaint(_BarPainter old) =>
      old.fillFrac != fillFrac ||
      old.goalLineFrac != goalLineFrac ||
      old.color != color ||
      old.trackColor != trackColor;
}

// ─────────────────────────────────────────────────────────────────────────────
// KPI cell — one per macro row in the right panel
// ─────────────────────────────────────────────────────────────────────────────

class _KpiCell extends StatelessWidget {
  const _KpiCell({
    required this.macroKey,
    required this.actual,
    required this.goal,
    required this.color,
    required this.showRem,
    required this.height,
  });

  final String macroKey;
  final double actual;
  final double goal;
  final Color  color;
  final bool   showRem;
  final double height;

  @override
  Widget build(BuildContext context) {
    final displayVal = showRem
        ? (goal - actual).clamp(0.0, double.infinity)
        : actual;
    final unit = _units[macroKey]!;

    return SizedBox(
      height: height,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: formatNum(displayVal, decimals: macroKey == 'kcal' ? 0 : 1),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                TextSpan(
                  text: ' ${unit.toUpperCase()}',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: color.withValues(alpha: 0.7),
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'goal ${goal.round()} $unit',
            style: TextStyle(
                fontSize: 9, color: AppColorScheme.of(context).textMuted),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Nav button (< >)
// ─────────────────────────────────────────────────────────────────────────────

class _NavBtn extends StatelessWidget {
  const _NavBtn({required this.icon, this.onPressed});
  final IconData     icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final cs = AppColorScheme.of(context);
    return IconButton(
      icon: Icon(icon, size: 18),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      onPressed: onPressed,
      color: onPressed == null ? cs.textMuted : cs.textPrimary,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Toggle button (Consumed / Remaining)
// ─────────────────────────────────────────────────────────────────────────────

class _ToggleBtn extends StatelessWidget {
  const _ToggleBtn(this.label, this.active, this.onTap);
  final String       label;
  final bool         active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = AppColorScheme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: active ? cs.card : Colors.transparent,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: active ? cs.textPrimary : cs.textMuted,
          ),
        ),
      ),
    );
  }
}
