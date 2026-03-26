import 'package:flutter/material.dart';

import '../models/food.dart';
import '../providers/settings_provider.dart';
import '../theme.dart';

/// Sticky horizontal macro summary shown at top of Daily Log.
class MacroSummaryBar extends StatelessWidget {
  const MacroSummaryBar({super.key, required this.totals, required this.goals});
  final MacroValues totals;
  final MacroGoals goals;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.card,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          _MacroKpi('Calories', totals.kcal, goals.kcal, 'kcal', AppColors.kcal),
          _MacroKpi('Protein',  totals.protein, goals.protein, 'g', AppColors.protein),
          _MacroKpi('Carbs',    totals.carbs,   goals.carbs,   'g', AppColors.carbs),
          _MacroKpi('Fat',      totals.fat,     goals.fat,     'g', AppColors.fat),
        ],
      ),
    );
  }
}

class _MacroKpi extends StatelessWidget {
  const _MacroKpi(this.label, this.actual, this.goal, this.unit, this.color);
  final String label;
  final double actual;
  final double goal;
  final String unit;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final remaining = goal - actual;
    final over = remaining < 0;

    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${actual.round()}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: over ? AppColors.danger : color,
            ),
          ),
          Text(
            over
                ? '${remaining.abs().round()} over'
                : '${remaining.round()} left',
            style: TextStyle(
              fontSize: 10,
              color: over ? AppColors.danger : AppColors.textMuted,
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 9, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}
