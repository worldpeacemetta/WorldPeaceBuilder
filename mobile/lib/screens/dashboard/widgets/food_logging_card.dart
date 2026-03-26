import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/entry.dart';
import '../../../models/food.dart';
import '../../../providers/entries_provider.dart';
import '../../../theme.dart';

/// Per-meal calorie breakdown card — matches web app's Food Logging section.
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
                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
              ],
            ),
            const SizedBox(height: 14),
            ...mealTotals.entries.map((e) =>
                _MealRow(meal: e.key, macros: e.value, totalKcal: totalKcal)),
          ],
        ),
      ),
    );
  }
}

class _MealRow extends StatelessWidget {
  const _MealRow({required this.meal, required this.macros, required this.totalKcal});
  final String meal;
  final MacroValues macros;
  final double totalKcal;

  static const _mealIcons = {
    'breakfast': '🌅',
    'lunch'    : '☀️',
    'dinner'   : '🌙',
    'snack'    : '🍎',
    'other'    : '🍽️',
  };

  @override
  Widget build(BuildContext context) {
    final pct = totalKcal > 0 ? (macros.kcal / totalKcal).clamp(0.0, 1.0) : 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(_mealIcons[meal] ?? '🍽️', style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Text(mealLabels[meal] ?? meal,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              const Spacer(),
              Text(
                '${macros.kcal.round()} kcal',
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.kcal),
              ),
              const SizedBox(width: 6),
              Text(
                '· P${macros.protein.round()} C${macros.carbs.round()} F${macros.fat.round()}',
                style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: AppColors.border,
              valueColor: const AlwaysStoppedAnimation(AppColors.kcal),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }
}
