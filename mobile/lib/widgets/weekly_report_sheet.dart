import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/utils.dart';
import '../models/food.dart';
import '../providers/log_history_provider.dart';
import '../providers/weekly_report_provider.dart';
import '../theme.dart';
import '../widgets/mode_pill.dart';
import 'food_detail/section_card.dart';

// ── Meal colours (mirrors usage_card.dart) ────────────────────────────────────

const _mealColors = {
  'breakfast': AppColors.protein,
  'lunch':     AppColors.carbs,
  'dinner':    AppColors.fat,
  'snack':     AppColors.kcal,
  'other':     Color(0xFF94A3B8),
};

const _mealEmojis = {
  'breakfast': '🌅',
  'lunch':     '☀️',
  'dinner':    '🌙',
  'snack':     '🍿',
};

// ── Entry point ───────────────────────────────────────────────────────────────

void showWeeklyReportSheet(BuildContext context, WidgetRef ref, String mondayISO) {
  final container = ProviderScope.containerOf(context);
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => ProviderScope(
      parent: container,
      child: _WeeklyReportSheet(mondayISO: mondayISO),
    ),
  );
}

// ── Sheet root ────────────────────────────────────────────────────────────────

class _WeeklyReportSheet extends ConsumerWidget {
  const _WeeklyReportSheet({required this.mondayISO});
  final String mondayISO;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs    = AppColorScheme.of(context);
    final async = ref.watch(weeklyReportProvider(mondayISO));

    return DraggableScrollableSheet(
      initialChildSize: 0.94,
      minChildSize:     0.5,
      maxChildSize:     1.0,
      builder: (ctx, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color:        cs.bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error:   (_, __) => Center(
            child: Text('Unable to load report',
                style: TextStyle(color: AppColorScheme.of(context).textMuted)),
          ),
          data: (report) {
            if (report == null) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.bar_chart_outlined, size: 40, color: AppColors.textMuted),
                    const SizedBox(height: 12),
                    Text('No activity recorded last week',
                        style: TextStyle(color: AppColorScheme.of(context).textMuted)),
                  ],
                ),
              );
            }
            return _ReportBody(report: report, scrollCtrl: scrollCtrl);
          },
        ),
      ),
    );
  }
}

// ── Report body (scrollable) ──────────────────────────────────────────────────

class _ReportBody extends StatelessWidget {
  const _ReportBody({required this.report, required this.scrollCtrl});
  final WeeklyReportData  report;
  final ScrollController  scrollCtrl;

  @override
  Widget build(BuildContext context) {
    final cs      = AppColorScheme.of(context);
    final bottom  = MediaQuery.of(context).padding.bottom;
    final hasWoW  = report.prevWeekAvg != null;
    final hasWknd = report.weekdayLogged > 0 || report.weekendLogged > 0;
    final achievements = _collectAchievements(report);

    return ListView(
      controller: scrollCtrl,
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottom + 28),
      children: [
        // Drag handle
        Center(
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: cs.border, borderRadius: BorderRadius.circular(2)),
          ),
        ),

        _HeroHeader(report: report),
        const SizedBox(height: 14),

        _DailyBreakdownCard(report: report),
        const SizedBox(height: 12),

        _MacroAveragesCard(report: report),
        const SizedBox(height: 12),

        _CalorieJourneyCard(report: report),
        const SizedBox(height: 12),

        _MealSpotlightCard(report: report),
        const SizedBox(height: 12),

        if (hasWknd) ...[
          _WeekdayWeekendCard(report: report),
          const SizedBox(height: 12),
        ],

        if (hasWoW) ...[
          _WeekOverWeekCard(report: report),
          const SizedBox(height: 12),
        ],

        _FoodVarietyCard(report: report),

        if (achievements.isNotEmpty) ...[
          const SizedBox(height: 12),
          _HighlightsCard(achievements: achievements),
        ],
      ],
    );
  }

  List<_Achievement> _collectAchievements(WeeklyReportData r) {
    final list = <_Achievement>[];
    if (r.allDaysLogged)           list.add(const _Achievement(Icons.star_rounded,        'Full week logged!',          AppColors.kcal));
    if (r.hadPerfectDay)           list.add(const _Achievement(Icons.emoji_events_rounded, 'Perfect day achieved',       Color(0xFFFBBF24)));
    if (r.proteinEveryLoggedDay)   list.add(const _Achievement(Icons.fitness_center,       'Protein goal every day',     AppColors.protein));
    if (r.daysLogged >= 5 && !r.allDaysLogged) {
      list.add(const _Achievement(Icons.local_fire_department, '5+ days consistent',       AppColors.carbs));
    }
    return list;
  }
}

// ── Hero header ───────────────────────────────────────────────────────────────

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({required this.report});
  final WeeklyReportData report;

  @override
  Widget build(BuildContext context) {
    final cs = AppColorScheme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            cs.kcalColor.withValues(alpha: 0.18),
            AppColors.protein.withValues(alpha: 0.1),
          ],
          begin: Alignment.topLeft,
          end:   Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.kcalColor.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'WEEKLY REVIEW',
            style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w700,
              color: cs.kcalColor, letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            weekRangeLabel(report.weekStart),
            style: TextStyle(
              fontSize: 22, fontWeight: FontWeight.w800, color: cs.textPrimary),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _HeroStat(
                icon: Icons.calendar_today_rounded,
                value: '${report.daysLogged}/7',
                label: 'Days logged',
                color: cs.kcalColor,
              ),
              const SizedBox(width: 8),
              _HeroStat(
                icon: Icons.local_fire_department_rounded,
                value: report.avgActual.kcal > 0
                    ? report.avgActual.kcal.round().toString()
                    : '—',
                label: 'Avg kcal',
                color: AppColors.protein,
              ),
              const SizedBox(width: 8),
              _HeroStat(
                icon: Icons.fitness_center_rounded,
                value: report.avgActual.protein > 0
                    ? '${report.avgActual.protein.round()}g'
                    : '—',
                label: 'Avg protein',
                color: AppColors.carbs,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });
  final IconData icon;
  final String   value;
  final String   label;
  final Color    color;

  @override
  Widget build(BuildContext context) {
    final cs = AppColorScheme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color:        color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border:       Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w800, color: color),
            ),
            Text(
              label,
              style: TextStyle(fontSize: 9, color: cs.textMuted),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Daily breakdown — 7-day strip ─────────────────────────────────────────────

class _DailyBreakdownCard extends StatelessWidget {
  const _DailyBreakdownCard({required this.report});
  final WeeklyReportData report;

  static const _letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final cs = AppColorScheme.of(context);

    return SectionCard(
      title: 'Daily Breakdown',
      child: Row(
        children: List.generate(7, (i) {
          final day   = report.days[i];
          final color = modeColor(day.modeLabel, context);
          final score = day.score;
          final isBest = report.bestDayIndex == i;

          return Expanded(
            child: Column(
              children: [
                // Ring circle with score fill
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 34, height: 34,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: day.logged ? color : cs.border,
                          width: isBest ? 2.5 : 1.5,
                        ),
                        color: day.logged
                            ? color.withValues(alpha: 0.1 + score * 0.45)
                            : cs.bg,
                      ),
                    ),
                    if (!day.logged)
                      Text('—', style: TextStyle(color: cs.textMuted, fontSize: 11)),
                    if (isBest && day.logged)
                      Positioned(
                        top: 0, right: 0,
                        child: Container(
                          width: 10, height: 10,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFBBF24),
                            shape: BoxShape.circle,
                            border: Border.all(color: cs.bg, width: 1.5),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 5),
                // Day letter
                Text(
                  _letters[i],
                  style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600,
                    color: day.logged ? cs.textPrimary : cs.textMuted,
                  ),
                ),
                const SizedBox(height: 3),
                // Mode label abbreviation
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                  decoration: BoxDecoration(
                    color: day.logged
                        ? color.withValues(alpha: 0.12)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    day.logged ? _shortMode(day.modeLabel) : '·',
                    style: TextStyle(
                      fontSize: 7.5, fontWeight: FontWeight.w700,
                      color: day.logged ? color : cs.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  String _shortMode(String label) => switch (label) {
    'Train Day'   => 'TRAIN',
    'Rest Day'    => 'REST',
    'Bulking'     => 'BULK',
    'Cutting'     => 'CUT',
    _             => 'MAINT',
  };
}

// ── Macro averages ────────────────────────────────────────────────────────────

class _MacroAveragesCard extends StatelessWidget {
  const _MacroAveragesCard({required this.report});
  final WeeklyReportData report;

  @override
  Widget build(BuildContext context) {
    final cs = AppColorScheme.of(context);
    final rows = [
      ('Calories', 'kcal', report.avgActual.kcal,    report.avgGoal.kcal,    report.daysHitKcal,    cs.kcalColor),
      ('Protein',  'g',    report.avgActual.protein,  report.avgGoal.protein,  report.daysHitProtein,  AppColors.protein),
      ('Carbs',    'g',    report.avgActual.carbs,    report.avgGoal.carbs,    report.daysHitCarbs,    AppColors.carbs),
      ('Fat',      'g',    report.avgActual.fat,      report.avgGoal.fat,      report.daysHitFat,      AppColors.fat),
    ];

    return SectionCard(
      title: 'Weekly Averages',
      child: Column(
        children: [
          for (int i = 0; i < rows.length; i++) ...[
            if (i > 0) const SizedBox(height: 16),
            _MacroRow(
              label:      rows[i].$1,
              unit:       rows[i].$2,
              actual:     rows[i].$3,
              goal:       rows[i].$4,
              daysHit:    rows[i].$5,
              daysLogged: report.daysLogged,
              color:      rows[i].$6,
            ),
          ],
        ],
      ),
    );
  }
}

class _MacroRow extends StatelessWidget {
  const _MacroRow({
    required this.label,
    required this.unit,
    required this.actual,
    required this.goal,
    required this.daysHit,
    required this.daysLogged,
    required this.color,
  });

  final String label;
  final String unit;
  final double actual;
  final double goal;
  final int    daysHit;
  final int    daysLogged;
  final Color  color;

  @override
  Widget build(BuildContext context) {
    final cs       = AppColorScheme.of(context);
    final progress = safeProgress(actual, goal);

    return Column(
      children: [
        Row(
          children: [
            SizedBox(
              width: 64,
              child: Text(label,
                  style: TextStyle(fontSize: 12, color: cs.textMuted)),
            ),
            Text(
              '${actual.round()} $unit',
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700, color: color),
            ),
            const SizedBox(width: 4),
            Text(
              '/ ${goal.round()}',
              style: TextStyle(fontSize: 11, color: cs.textMuted),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color:  daysHit > 0 ? color.withValues(alpha: 0.12) : cs.bg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: daysHit > 0 ? color.withValues(alpha: 0.35) : cs.border),
              ),
              child: Text(
                '$daysHit/$daysLogged d',
                style: TextStyle(
                  fontSize: 9, fontWeight: FontWeight.w600,
                  color: daysHit > 0 ? color : cs.textMuted,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value:           progress,
            minHeight:       6,
            backgroundColor: color.withValues(alpha: 0.12),
            valueColor:      AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

// ── Calorie journey — BarChart (daily) + balance line ────────────────────────

class _CalorieJourneyCard extends StatelessWidget {
  const _CalorieJourneyCard({required this.report});
  final WeeklyReportData report;

  @override
  Widget build(BuildContext context) {
    final cs          = AppColorScheme.of(context);
    final kcalColor   = cs.kcalColor;
    final isSurplus   = report.totalSurplus >= 0;
    final balColor    = isSurplus ? AppColors.success : AppColors.danger;
    final avgGoalKcal = report.avgGoal.kcal;

    // Bar groups — one per day
    final maxKcal = report.days
        .map((d) => d.totals.kcal)
        .fold(avgGoalKcal * 1.1, (a, b) => math.max(a, b));

    final barGroups = List.generate(7, (i) {
      final day = report.days[i];
      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY:          day.logged ? day.totals.kcal : 0,
            width:        20,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
            gradient: day.logged
                ? LinearGradient(
                    colors: [kcalColor, kcalColor.withValues(alpha: 0.5)],
                    begin: Alignment.topCenter,
                    end:   Alignment.bottomCenter,
                  )
                : null,
            color: day.logged ? null : cs.border.withValues(alpha: 0.4),
          ),
        ],
      );
    });

    // Cumulative balance line spots
    final balSpots = <FlSpot>[];
    for (int i = 0; i < report.cumulativeBalance.length; i++) {
      balSpots.add(FlSpot(i.toDouble(), report.cumulativeBalance[i]));
    }
    final balMin = report.cumulativeBalance.fold(0.0, (a, b) => math.min(a, b)) * 1.2;
    final balMax = report.cumulativeBalance.fold(0.0, (a, b) => math.max(a, b)) * 1.2;
    final balRange = math.max(math.max(balMax, -balMin), 200.0);

    return SectionCard(
      title: 'Calorie Journey',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Total balance chip
          Row(
            children: [
              Icon(
                isSurplus ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                color: balColor, size: 16,
              ),
              const SizedBox(width: 6),
              RichText(
                text: TextSpan(
                  style: TextStyle(fontSize: 12, color: cs.textMuted),
                  children: [
                    TextSpan(
                      text: '${isSurplus ? '+' : ''}${report.totalSurplus.round()} kcal ',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, color: balColor),
                    ),
                    TextSpan(
                      text: isSurplus ? 'weekly surplus' : 'weekly deficit',
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Daily kcal bar chart
          SizedBox(
            height: 150,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY:      maxKcal * 1.15,
                minY:      0,
                barGroups: barGroups,
                gridData:  FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  leftTitles:  AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles:   AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 20,
                      getTitlesWidget: (v, _) {
                        const letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                        final i = v.toInt();
                        if (i < 0 || i > 6) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(letters[i],
                              style: TextStyle(fontSize: 10, color: cs.textMuted)),
                        );
                      },
                    ),
                  ),
                ),
                extraLinesData: avgGoalKcal > 0
                    ? ExtraLinesData(horizontalLines: [
                        HorizontalLine(
                          y:           avgGoalKcal,
                          color:       kcalColor.withValues(alpha: 0.5),
                          strokeWidth: 1.5,
                          dashArray:   [5, 4],
                          label: HorizontalLineLabel(
                            show: true,
                            alignment: Alignment.topRight,
                            style: TextStyle(fontSize: 9, color: kcalColor),
                            labelResolver: (_) => 'goal',
                          ),
                        ),
                      ])
                    : null,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Divider + cumulative balance label
          Row(
            children: [
              Expanded(child: Divider(color: cs.border, height: 1)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  'Cumulative balance',
                  style: TextStyle(fontSize: 10, color: cs.textMuted, letterSpacing: 0.4),
                ),
              ),
              Expanded(child: Divider(color: cs.border, height: 1)),
            ],
          ),
          const SizedBox(height: 12),

          // Cumulative balance line chart
          if (balSpots.length >= 2)
            SizedBox(
              height: 90,
              child: LineChart(
                LineChartData(
                  gridData:   FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  minX: 0, maxX: 6,
                  minY: -balRange, maxY: balRange,
                  lineTouchData: LineTouchData(enabled: false),
                  extraLinesData: ExtraLinesData(horizontalLines: [
                    HorizontalLine(
                      y:           0,
                      color:       cs.textMuted.withValues(alpha: 0.35),
                      strokeWidth: 1,
                      dashArray:   [4, 4],
                    ),
                  ]),
                  titlesData: FlTitlesData(
                    leftTitles:   AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles:  AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles:    AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots:    balSpots,
                      isCurved: true,
                      color:    balColor,
                      barWidth: 2.5,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                          radius:      3.5,
                          color:       spot.y >= 0 ? AppColors.success : AppColors.danger,
                          strokeWidth: 0,
                          strokeColor: Colors.transparent,
                        ),
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            AppColors.success.withValues(alpha: 0.18),
                            Colors.transparent,
                          ],
                          begin: Alignment.topCenter,
                          end:   Alignment.bottomCenter,
                        ),
                        cutOffY:      0,
                        applyCutOffY: true,
                      ),
                      aboveBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            AppColors.danger.withValues(alpha: 0.18),
                            Colors.transparent,
                          ],
                          begin: Alignment.bottomCenter,
                          end:   Alignment.topCenter,
                        ),
                        cutOffY:      0,
                        applyCutOffY: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Meal spotlight — donut + protein bar chart ────────────────────────────────

class _MealSpotlightCard extends StatefulWidget {
  const _MealSpotlightCard({required this.report});
  final WeeklyReportData report;

  @override
  State<_MealSpotlightCard> createState() => _MealSpotlightCardState();
}

class _MealSpotlightCardState extends State<_MealSpotlightCard> {
  int? _touched;

  @override
  Widget build(BuildContext context) {
    final cs      = AppColorScheme.of(context);
    final report  = widget.report;
    final slots   = ['breakfast', 'lunch', 'dinner', 'snack'];

    // Donut sections — kcal by slot (exclude slots with 0 kcal).
    // secIdx tracks the position WITHIN sections so _touched aligns with
    // touchedSectionIndex returned by fl_chart (which skips empty slots).
    final totalKcal = slots.fold(0.0, (s, sl) => s + (report.kcalBySlot[sl] ?? 0));
    final sections  = <PieChartSectionData>[];
    int secIdx = 0;
    for (final sl in slots) {
      final kcal = report.kcalBySlot[sl] ?? 0;
      if (kcal <= 0) continue;
      final isTouched = _touched == secIdx;
      final color     = _mealColors[sl]!;
      sections.add(PieChartSectionData(
        value:      kcal,
        color:      color,
        radius:     isTouched ? 58 : 48,
        showTitle:  isTouched,
        title:      '${(kcal / totalKcal * 100).round()}%',
        titleStyle: const TextStyle(
            fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
      ));
      secIdx++;
    }

    // Protein bar chart data
    final maxProtein = slots
        .map((sl) => report.proteinBySlot[sl] ?? 0)
        .fold(1.0, (a, b) => math.max(a, b));

    return SectionCard(
      title: 'Meal Spotlight',
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Donut
              SizedBox(
                width: 150, height: 150,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                      PieChartData(
                        startDegreeOffset: -90,
                        sectionsSpace:     2,
                        centerSpaceRadius: 38,
                        sections:          sections.isEmpty ? _emptySlices() : sections,
                        pieTouchData: PieTouchData(
                          touchCallback: (event, response) {
                            setState(() {
                              if (event.isInterestedForInteractions &&
                                  response?.touchedSection != null) {
                                _touched = response!.touchedSection!.touchedSectionIndex;
                              } else {
                                _touched = null;
                              }
                            });
                          },
                        ),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${totalKcal.round()}',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w800,
                              color: cs.kcalColor),
                        ),
                        Text('kcal',
                            style: TextStyle(fontSize: 10, color: cs.textMuted)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Legend
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: slots.map((sl) {
                    final kcal  = report.kcalBySlot[sl] ?? 0;
                    final color = _mealColors[sl]!;
                    final pct   = totalKcal > 0 ? (kcal / totalKcal * 100).round() : 0;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Text(_mealEmojis[sl]!, style: const TextStyle(fontSize: 12)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              sl[0].toUpperCase() + sl.substring(1),
                              style: TextStyle(fontSize: 11, color: cs.textMuted),
                            ),
                          ),
                          Text(
                            '$pct%',
                            style: TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w700,
                                color: kcal > 0 ? color : cs.textMuted),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),
          // Divider
          Row(
            children: [
              Expanded(child: Divider(color: cs.border, height: 1)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text('Protein by meal',
                    style: TextStyle(fontSize: 10, color: cs.textMuted, letterSpacing: 0.4)),
              ),
              Expanded(child: Divider(color: cs.border, height: 1)),
            ],
          ),
          const SizedBox(height: 14),

          // Protein bar chart
          SizedBox(
            height: 110,
            child: BarChart(
              BarChartData(
                alignment:    BarChartAlignment.spaceAround,
                maxY:         maxProtein * 1.25,
                minY:         0,
                barTouchData: BarTouchData(enabled: false),
                gridData:     FlGridData(show: false),
                borderData:   FlBorderData(show: false),
                barGroups: List.generate(slots.length, (i) {
                  final sl      = slots[i];
                  final protein = report.proteinBySlot[sl] ?? 0;
                  final color   = _mealColors[sl]!;
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY:          protein,
                        width:        28,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
                        gradient: LinearGradient(
                          colors: [color, color.withValues(alpha: 0.5)],
                          begin: Alignment.topCenter,
                          end:   Alignment.bottomCenter,
                        ),
                      ),
                    ],
                  );
                }),
                titlesData: FlTitlesData(
                  leftTitles:  AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles:   AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (v, _) {
                        final i = v.toInt();
                        if (i < 0 || i >= slots.length) return const SizedBox.shrink();
                        final sl      = slots[i];
                        final protein = report.proteinBySlot[sl] ?? 0;
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_mealEmojis[sl]!,
                                style: const TextStyle(fontSize: 13)),
                            Text('${protein.round()}g',
                                style: TextStyle(fontSize: 8, color: AppColorScheme.of(context).textMuted)),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<PieChartSectionData> _emptySlices() => [
    PieChartSectionData(
      value:     1,
      color:     AppColorScheme.of(context).border,
      radius:    48,
      showTitle: false,
    ),
  ];
}

// ── Weekday vs Weekend ────────────────────────────────────────────────────────

class _WeekdayWeekendCard extends StatelessWidget {
  const _WeekdayWeekendCard({required this.report});
  final WeeklyReportData report;

  @override
  Widget build(BuildContext context) {
    final cs = AppColorScheme.of(context);

    return SectionCard(
      title: 'Weekdays vs. Weekend',
      child: Row(
        children: [
          Expanded(
            child: _DayTypeColumn(
              label:  'Weekdays',
              logged: report.weekdayLogged,
              total:  5,
              avg:    report.weekdayAvg,
              color:  AppColors.protein,
            ),
          ),
          Container(width: 1, height: 80, color: cs.border),
          Expanded(
            child: _DayTypeColumn(
              label:  'Weekend',
              logged: report.weekendLogged,
              total:  2,
              avg:    report.weekendAvg,
              color:  cs.kcalColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _DayTypeColumn extends StatelessWidget {
  const _DayTypeColumn({
    required this.label,
    required this.logged,
    required this.total,
    required this.avg,
    required this.color,
  });
  final String      label;
  final int         logged;
  final int         total;
  final MacroValues avg;
  final Color       color;

  @override
  Widget build(BuildContext context) {
    final cs = AppColorScheme.of(context);
    return Column(
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600, color: cs.textMuted)),
        const SizedBox(height: 4),
        Text(
          '$logged/$total days',
          style: TextStyle(fontSize: 10, color: cs.textMuted),
        ),
        const SizedBox(height: 10),
        if (logged > 0) ...[
          _MiniStat(value: '${avg.kcal.round()}', unit: 'kcal', color: color),
          const SizedBox(height: 6),
          _MiniStat(value: '${avg.protein.round()}g', unit: 'protein', color: AppColors.protein),
          const SizedBox(height: 6),
          _MiniStat(value: '${avg.carbs.round()}g', unit: 'carbs', color: AppColors.carbs),
        ] else
          Text('No data', style: TextStyle(fontSize: 11, color: cs.textMuted)),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.value, required this.unit, required this.color});
  final String value;
  final String unit;
  final Color  color;

  @override
  Widget build(BuildContext context) {
    final cs = AppColorScheme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700, color: color)),
        const SizedBox(width: 3),
        Text(unit,
            style: TextStyle(fontSize: 10, color: cs.textMuted)),
      ],
    );
  }
}

// ── Week-over-week ────────────────────────────────────────────────────────────

class _WeekOverWeekCard extends StatelessWidget {
  const _WeekOverWeekCard({required this.report});
  final WeeklyReportData report;

  @override
  Widget build(BuildContext context) {
    final prev = report.prevWeekAvg!;
    final curr = report.avgActual;

    return SectionCard(
      title: 'Week over Week',
      child: Column(
        children: [
          // Prev week note
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'vs previous week (${report.prevWeekLogged} days logged)',
              style: TextStyle(
                  fontSize: 10, color: AppColorScheme.of(context).textMuted),
            ),
          ),
          Row(
            children: [
              _DeltaChip(
                  label: 'Calories', curr: curr.kcal, prev: prev.kcal,
                  color: AppColorScheme.of(context).kcalColor),
              const SizedBox(width: 8),
              _DeltaChip(
                  label: 'Protein',  curr: curr.protein, prev: prev.protein,
                  color: AppColors.protein),
              const SizedBox(width: 8),
              _DeltaChip(
                  label: 'Carbs',    curr: curr.carbs,   prev: prev.carbs,
                  color: AppColors.carbs),
              const SizedBox(width: 8),
              _DeltaChip(
                  label: 'Fat',      curr: curr.fat,     prev: prev.fat,
                  color: AppColors.fat),
            ],
          ),
        ],
      ),
    );
  }
}

class _DeltaChip extends StatelessWidget {
  const _DeltaChip({
    required this.label,
    required this.curr,
    required this.prev,
    required this.color,
  });
  final String label;
  final double curr;
  final double prev;
  final Color  color;

  @override
  Widget build(BuildContext context) {
    final cs      = AppColorScheme.of(context);
    final delta   = prev > 0 ? ((curr - prev) / prev * 100) : 0.0;
    final isUp    = delta >= 0;
    final sign    = isUp ? '+' : '';
    final dColor  = isUp ? AppColors.success : AppColors.danger;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color:        color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(12),
          border:       Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text(label,
                style: TextStyle(fontSize: 9, color: cs.textMuted),
                textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(isUp ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                    size: 11, color: dColor),
                const SizedBox(width: 2),
                Text(
                  '$sign${delta.abs().round()}%',
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w800, color: dColor),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Food variety ──────────────────────────────────────────────────────────────

class _FoodVarietyCard extends StatelessWidget {
  const _FoodVarietyCard({required this.report});
  final WeeklyReportData report;

  @override
  Widget build(BuildContext context) {
    final cs = AppColorScheme.of(context);

    return SectionCard(
      title: 'Food Variety',
      child: Row(
        children: [
          // Unique foods stat
          Expanded(
            child: Column(
              children: [
                Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(
                    color:        AppColors.protein.withValues(alpha: 0.12),
                    shape:        BoxShape.circle,
                    border:       Border.all(color: AppColors.protein.withValues(alpha: 0.3)),
                  ),
                  child: Center(
                    child: Text(
                      '${report.uniqueFoodsCount}',
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w800,
                          color: AppColors.protein),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text('unique foods', style: TextStyle(fontSize: 11, color: cs.textMuted)),
              ],
            ),
          ),

          Container(width: 1, height: 70, color: cs.border),

          // Most logged food
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Most logged',
                      style: TextStyle(fontSize: 10, color: cs.textMuted)),
                  const SizedBox(height: 6),
                  if (report.topFoodName != null) ...[
                    Text(
                      report.topFoodName!,
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700,
                          color: cs.textPrimary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${report.topFoodFrequency}× this week',
                      style: TextStyle(fontSize: 11, color: cs.kcalColor),
                    ),
                  ] else
                    Text('—', style: TextStyle(color: cs.textMuted)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Highlights / achievements ─────────────────────────────────────────────────

class _Achievement {
  const _Achievement(this.icon, this.label, this.color);
  final IconData icon;
  final String   label;
  final Color    color;
}

class _HighlightsCard extends StatelessWidget {
  const _HighlightsCard({required this.achievements});
  final List<_Achievement> achievements;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Highlights',
      child: Wrap(
        spacing:   10,
        runSpacing: 10,
        children: achievements.map((a) => _AchievementChip(achievement: a)).toList(),
      ),
    );
  }
}

class _AchievementChip extends StatelessWidget {
  const _AchievementChip({required this.achievement});
  final _Achievement achievement;

  @override
  Widget build(BuildContext context) {
    final c = achievement.color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color:        c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(24),
        border:       Border.all(color: c.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(achievement.icon, size: 15, color: c),
          const SizedBox(width: 6),
          Text(
            achievement.label,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: c),
          ),
        ],
      ),
    );
  }
}

// ── Weekly reports history list ───────────────────────────────────────────────

void showWeeklyReportsListSheet(BuildContext context, WidgetRef ref) {
  final container = ProviderScope.containerOf(context);
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => ProviderScope(
      parent: container,
      child: const _WeeklyReportsListSheet(),
    ),
  );
}

class _WeeklyReportsListSheet extends ConsumerWidget {
  const _WeeklyReportsListSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs          = AppColorScheme.of(context);
    final loggedAsync = ref.watch(loggedDatesProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize:     0.4,
      maxChildSize:     0.95,
      builder: (ctx, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color:        cs.bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: loggedAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error:   (_, __) => Center(
            child: Text('Unable to load history',
                style: TextStyle(color: cs.textMuted)),
          ),
          data: (loggedDates) {
            final weeks = _computeAvailableWeeks(loggedDates);
            return _WeeklyReportsListBody(
              weeks:      weeks,
              scrollCtrl: scrollCtrl,
            );
          },
        ),
      ),
    );
  }

  /// Groups logged dates into completed Mon–Sun weeks (excluding the current
  /// incomplete week), sorted newest first. Returns a list of
  /// (mondayISO, daysLogged) records.
  List<(String, int)> _computeAvailableWeeks(List<String> loggedDates) {
    if (loggedDates.isEmpty) return [];

    final now            = DateTime.now();
    final currentMonday  = now.subtract(Duration(days: now.weekday - 1));
    final currentMondayISO = isoDate(
      DateTime(currentMonday.year, currentMonday.month, currentMonday.day),
    );

    final weekMap = <String, int>{};
    for (final d in loggedDates) {
      final dt   = DateTime.parse(d);
      final mon  = dt.subtract(Duration(days: dt.weekday - 1));
      final mISO = isoDate(DateTime(mon.year, mon.month, mon.day));
      // Skip the current week — it's not yet complete.
      if (mISO == currentMondayISO) continue;
      weekMap[mISO] = (weekMap[mISO] ?? 0) + 1;
    }

    final sorted = weekMap.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));

    return sorted.map((e) => (e.key, e.value)).toList();
  }
}

class _WeeklyReportsListBody extends StatelessWidget {
  const _WeeklyReportsListBody({
    required this.weeks,
    required this.scrollCtrl,
  });
  final List<(String, int)> weeks;
  final ScrollController    scrollCtrl;

  @override
  Widget build(BuildContext context) {
    final cs     = AppColorScheme.of(context);
    final bottom = MediaQuery.of(context).padding.bottom;

    return ListView(
      controller: scrollCtrl,
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottom + 20),
      children: [
        // Drag handle
        Center(
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: cs.border, borderRadius: BorderRadius.circular(2)),
          ),
        ),

        // Header
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color:        cs.kcalColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.bar_chart_rounded,
                    color: cs.kcalColor, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'Weekly Reports',
                style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w800,
                  color: cs.textPrimary,
                ),
              ),
            ],
          ),
        ),

        if (weeks.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Column(
              children: [
                Icon(Icons.bar_chart_outlined, size: 40, color: cs.textMuted),
                const SizedBox(height: 12),
                Text(
                  'No completed weeks yet',
                  style: TextStyle(color: cs.textMuted, fontSize: 14),
                ),
                const SizedBox(height: 6),
                Text(
                  'Reports appear once a full Mon–Sun week passes.',
                  style: TextStyle(color: cs.textMuted, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          for (final week in weeks)
            _WeekReportRow(mondayISO: week.$1, daysLogged: week.$2),
      ],
    );
  }
}

class _WeekReportRow extends ConsumerWidget {
  const _WeekReportRow({
    required this.mondayISO,
    required this.daysLogged,
  });
  final String mondayISO;
  final int    daysLogged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = AppColorScheme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => showWeeklyReportSheet(context, ref, mondayISO),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          decoration: BoxDecoration(
            color:        cs.card,
            borderRadius: BorderRadius.circular(16),
            border:       Border.all(color: cs.border),
          ),
          child: Row(
            children: [
              // Calendar icon with subtle kcal tint
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color:        cs.kcalColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.bar_chart_rounded,
                    color: cs.kcalColor, size: 20),
              ),
              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      weekRangeLabel(mondayISO),
                      style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700,
                        color: cs.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$daysLogged/7 days logged',
                      style: TextStyle(fontSize: 12, color: cs.textMuted),
                    ),
                  ],
                ),
              ),

              // Consistency dots
              Row(
                children: List.generate(7, (i) => Container(
                  width: 6, height: 6,
                  margin: const EdgeInsets.only(left: 3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < daysLogged
                        ? cs.kcalColor
                        : cs.border,
                  ),
                )),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, size: 20, color: cs.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
