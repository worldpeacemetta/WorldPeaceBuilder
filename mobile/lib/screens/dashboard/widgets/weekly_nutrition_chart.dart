import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/utils.dart';
import '../../../providers/entries_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../theme.dart';

/// Multi-macro weekly chart — mirrors the web app's Weekly Nutrition area chart.
class WeeklyNutritionChart extends ConsumerStatefulWidget {
  const WeeklyNutritionChart({super.key, required this.date});
  final String date;

  @override
  ConsumerState<WeeklyNutritionChart> createState() => _WeeklyNutritionChartState();
}

class _WeeklyNutritionChartState extends ConsumerState<WeeklyNutritionChart> {
  // Which macro is shown: 'kcal' | 'protein' | 'carbs' | 'fat'
  String _macro = 'kcal';

  static const _macros = ['kcal', 'protein', 'carbs', 'fat'];
  static const _labels = {'kcal': 'Calories', 'protein': 'Protein', 'carbs': 'Carbs', 'fat': 'Fat'};
  static const _units  = {'kcal': 'kcal', 'protein': 'g', 'carbs': 'g', 'fat': 'g'};
  static const _colors = {
    'kcal'   : AppColors.kcal,
    'protein': AppColors.protein,
    'carbs'  : AppColors.carbs,
    'fat'    : AppColors.fat,
  };

  @override
  Widget build(BuildContext context) {
    final days  = weekDates(widget.date);
    final goals = ref.watch(settingsProvider).activeGoals;
    final color = _colors[_macro]!;

    final double goal = switch (_macro) {
      'kcal'    => goals.kcal,
      'protein' => goals.protein,
      'carbs'   => goals.carbs,
      _         => goals.fat,
    };

    final dayValues = days.map((d) {
      final t = ref.watch(macroTotalsProvider(d));
      return switch (_macro) {
        'kcal'    => t.kcal,
        'protein' => t.protein,
        'carbs'   => t.carbs,
        _         => t.fat,
      };
    }).toList();

    final maxY = ([...dayValues, goal]).reduce((a, b) => a > b ? a : b) * 1.18;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Weekly Nutrition',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const Spacer(),
                Text(weekRangeLabel(widget.date),
                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
              ],
            ),
            const SizedBox(height: 10),

            // Macro toggle chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _macros.map((m) {
                  final sel = m == _macro;
                  final c = _colors[m]!;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: GestureDetector(
                      onTap: () => setState(() => _macro = m),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: sel ? c.withValues(alpha: 0.18) : AppColors.bg,
                          border: Border.all(color: sel ? c : AppColors.border),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _labels[m]!,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: sel ? FontWeight.w700 : FontWeight.normal,
                            color: sel ? c : AppColors.textMuted,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 14),

            SizedBox(
              height: 150,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: maxY > 0 ? maxY : 100,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) =>
                        FlLine(color: AppColors.border, strokeWidth: 1),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles  : const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles : const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles   : const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 22,
                        getTitlesWidget: (v, _) {
                          final i = v.toInt();
                          if (i < 0 || i >= days.length) return const SizedBox.shrink();
                          final dt = DateTime.parse(days[i]);
                          final isToday = days[i] == widget.date;
                          return Text(
                            DateFormat('E').format(dt).substring(0, 1),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isToday ? FontWeight.w700 : FontWeight.normal,
                              color: isToday ? color : AppColors.textMuted,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  lineBarsData: [
                    // Goal dashed reference
                    if (goal > 0)
                      LineChartBarData(
                        spots: List.generate(7, (i) => FlSpot(i.toDouble(), goal)),
                        isCurved: false,
                        color: color.withValues(alpha: 0.3),
                        barWidth: 1.5,
                        dotData: const FlDotData(show: false),
                        dashArray: [6, 4],
                      ),
                    // Actual values
                    LineChartBarData(
                      spots: List.generate(7, (i) => FlSpot(i.toDouble(), dayValues[i])),
                      isCurved: true,
                      curveSmoothness: 0.3,
                      color: color,
                      barWidth: 2.5,
                      belowBarData: BarAreaData(
                        show: true,
                        color: color.withValues(alpha: 0.1),
                      ),
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                          radius: 3.5,
                          color: color,
                          strokeWidth: 0,
                        ),
                      ),
                    ),
                  ],
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (spots) => spots.map((s) {
                        if (goal > 0 && s.barIndex == 0) return null;
                        return LineTooltipItem(
                          '${s.y.round()} ${_units[_macro]}',
                          TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
