import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/utils.dart';
import '../providers/entries_provider.dart';
import '../providers/settings_provider.dart';
import '../theme.dart';

/// Weekly kcal area chart for the 7 days containing [date].
class WeeklyChartCard extends ConsumerWidget {
  const WeeklyChartCard({super.key, required this.date});
  final String date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final days = weekDates(date);
    final goal = ref.watch(settingsProvider).activeGoals.kcal;

    // Collect kcal per day from already-loaded entries providers.
    final dayData = days.map((d) {
      final totals = ref.watch(macroTotalsProvider(d));
      return totals.kcal;
    }).toList();

    final maxY = ([...dayData, goal]).reduce((a, b) => a > b ? a : b) * 1.15;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Weekly Calories',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const Spacer(),
                Text(weekRangeLabel(date),
                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 160,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: maxY,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: AppColors.border,
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 24,
                        getTitlesWidget: (value, _) {
                          final i = value.toInt();
                          if (i < 0 || i >= days.length) return const SizedBox.shrink();
                          final dt = DateTime.parse(days[i]);
                          return Text(
                            DateFormat('E').format(dt).substring(0, 2),
                            style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                          );
                        },
                      ),
                    ),
                  ),
                  lineBarsData: [
                    // Goal reference line
                    if (goal > 0)
                      LineChartBarData(
                        spots: List.generate(7, (i) => FlSpot(i.toDouble(), goal)),
                        isCurved: false,
                        color: AppColors.kcal.withValues(alpha: 0.35),
                        barWidth: 1.5,
                        dotData: const FlDotData(show: false),
                        dashArray: [5, 5],
                      ),
                    // Actual kcal line
                    LineChartBarData(
                      spots: List.generate(
                        7,
                        (i) => FlSpot(i.toDouble(), dayData[i]),
                      ),
                      isCurved: true,
                      color: AppColors.kcal,
                      barWidth: 2.5,
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppColors.kcal.withValues(alpha: 0.12),
                      ),
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                          radius: 3,
                          color: AppColors.kcal,
                          strokeWidth: 0,
                        ),
                      ),
                    ),
                  ],
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (spots) => spots.map((s) {
                        if (s.barIndex == 0 && goal > 0) return null;
                        return LineTooltipItem(
                          '${s.y.round()} kcal',
                          const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
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
