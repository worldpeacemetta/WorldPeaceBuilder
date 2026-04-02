import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/entry.dart';
import '../../../models/food.dart';
import '../../../providers/entries_provider.dart';
import '../../../theme.dart';

const _mealColors = {
  'breakfast': Color(0xFFFFB347),
  'lunch'    : AppColors.protein,
  'dinner'   : AppColors.kcal,
  'snack'    : AppColors.carbs,
  'other'    : AppColors.fat,
};

const _mealIcons = {
  'breakfast': '🌅',
  'lunch'    : '☀️',
  'dinner'   : '🌙',
  'snack'    : '🍎',
  'other'    : '🍽️',
};

/// Per-meal calorie breakdown card — stacked proportion bar + meal cards.
class FoodLoggingCard extends ConsumerWidget {
  const FoodLoggingCard({super.key, required this.date});
  final String date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(entriesProvider(date)).valueOrNull ?? [];
    if (entries.isEmpty) return const SizedBox.shrink();

    // Aggregate by meal
    final mealTotals = <String, MacroValues>{};
    for (final meal in mealOrder) {
      final items = entries.where((e) => e.meal == meal).toList();
      if (items.isEmpty) continue;
      mealTotals[meal] = items.fold<MacroValues>(
        const MacroValues(),
        (acc, e) => acc + e.macros,
      );
    }
    if (mealTotals.isEmpty) return const SizedBox.shrink();

    final totalKcal = mealTotals.values.fold(0.0, (s, m) => s + m.kcal);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Food Logging',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                Text('${totalKcal.round()} kcal total',
                    style: TextStyle(fontSize: 12, color: AppColorScheme.of(context).textMuted)),
              ],
            ),
            const SizedBox(height: 12),
            // Stacked proportion bar
            _StackedBar(mealTotals: mealTotals, totalKcal: totalKcal),
            const SizedBox(height: 14),
            // Meal cards (no individual bars)
            ...mealTotals.entries.map((e) => _MealCard(
              meal: e.key,
              macros: e.value,
              color: _mealColors[e.key] ?? AppColors.kcal,
              icon: _mealIcons[e.key] ?? '🍽️',
            )),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _StackedBar extends StatelessWidget {
  const _StackedBar({required this.mealTotals, required this.totalKcal});
  final Map<String, MacroValues> mealTotals;
  final double totalKcal;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(5),
      child: SizedBox(
        height: 8,
        child: Row(
          children: mealTotals.entries.map((e) {
            final flex = totalKcal > 0
                ? ((e.value.kcal / totalKcal) * 1000).round()
                : 0;
            return Flexible(
              flex: flex,
              child: Container(color: _mealColors[e.key] ?? AppColors.kcal),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _MealCard extends StatelessWidget {
  const _MealCard({
    required this.meal, required this.macros,
    required this.color, required this.icon,
  });
  final String meal;
  final MacroValues macros;
  final Color color;
  final String icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          // Colored accent dot
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(icon, style: const TextStyle(fontSize: 15)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              mealLabels[meal] ?? meal,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
          // kcal value
          Text(
            '${macros.kcal.round()}',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color),
          ),
          const SizedBox(width: 3),
          Text('kcal', style: TextStyle(fontSize: 11, color: AppColorScheme.of(context).textMuted)),
          const SizedBox(width: 10),
          // P / C / F chips
          _Chip('P', macros.protein.round(), AppColors.protein),
          const SizedBox(width: 4),
          _Chip('C', macros.carbs.round(), AppColors.carbs),
          const SizedBox(width: 4),
          _Chip('F', macros.fat.round(), AppColors.fat),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.label, this.value, this.color);
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '$label$value',
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}
