import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../core/utils.dart';
import '../theme.dart';

/// Circular ring chart for a single macro.
class MacroRingChart extends StatelessWidget {
  const MacroRingChart({
    super.key,
    required this.label,
    required this.actual,
    required this.goal,
    required this.unit,
    required this.color,
    this.size = 76,
  });

  final String label;
  final double actual;
  final double goal;
  final String unit;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final pct = goal > 0 ? (actual / goal).clamp(0.0, 1.25) : 0.0;
    final over = goal > 0 && actual > goal;
    final displayColor = over ? const Color(0xFFEF4444) : color;
    final remaining = (1.0 - pct).clamp(0.0, 1.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  startDegreeOffset: -90,
                  sectionsSpace: 0,
                  centerSpaceRadius: size * 0.32,
                  sections: [
                    PieChartSectionData(
                      value: pct > 0 ? pct : 0.001,
                      color: displayColor,
                      radius: size * 0.18,
                      showTitle: false,
                    ),
                    PieChartSectionData(
                      value: remaining > 0 ? remaining : 0.001,
                      color: displayColor.withValues(alpha: 0.15),
                      radius: size * 0.18,
                      showTitle: false,
                    ),
                  ],
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    formatNum(actual, decimals: 0),
                    style: TextStyle(
                      fontSize: size * 0.175,
                      fontWeight: FontWeight.w700,
                      color: displayColor,
                      height: 1.1,
                    ),
                  ),
                  if (goal > 0)
                    Text(
                      '${(pct * 100).round()}%',
                      style: TextStyle(
                        fontSize: size * 0.13,
                        color: displayColor.withValues(alpha: 0.8),
                        height: 1.1,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: AppColorScheme.of(context).textMuted),
        ),
        Text(
          '/ ${goal.round()} $unit',
          style: TextStyle(fontSize: 10, color: AppColorScheme.of(context).textMuted),
        ),
      ],
    );
  }
}
