import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils.dart';
import '../../models/food.dart';
import '../../providers/date_provider.dart';
import '../../providers/entries_provider.dart';
import '../../providers/settings_provider.dart';
import '../../theme.dart';
import '../../widgets/macro_ring_chart.dart';
import 'widgets/food_logging_card.dart';
import 'widgets/weekly_nutrition_chart.dart';
import 'widgets/weight_trend_card.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final date = ref.watch(dashboardDateProvider);
    final totals = ref.watch(macroTotalsProvider(date));
    final goals = ref.watch(settingsProvider).activeGoals;
    final isToday = date == todayISO();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Dashboard'),
            Text(
              formatDateFull(date),
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w400),
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
          // Macro rings row
          _MacroRingsCard(totals: totals, goals: goals),
          const SizedBox(height: 16),

          // Per-macro progress bars
          _MacroProgressCard(totals: totals, goals: goals),
          const SizedBox(height: 16),

          // Weekly Nutrition (multi-macro toggle)
          WeeklyNutritionChart(date: date),
          const SizedBox(height: 16),

          // Food Logging per-meal breakdown
          FoodLoggingCard(date: date),
          const SizedBox(height: 16),

          // Weight Trend
          const WeightTrendCard(),
          const SizedBox(height: 16),

          // Top foods
          _TopFoodsCard(date: date),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Macro rings (4 donut rings side by side)
// ---------------------------------------------------------------------------
class _MacroRingsCard extends StatelessWidget {
  const _MacroRingsCard({required this.totals, required this.goals});
  final MacroValues totals;
  final MacroGoals goals;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            MacroRingChart(
              label: 'Calories',
              actual: totals.kcal,
              goal: goals.kcal,
              unit: 'kcal',
              color: AppColors.kcal,
            ),
            MacroRingChart(
              label: 'Protein',
              actual: totals.protein,
              goal: goals.protein,
              unit: 'g',
              color: AppColors.protein,
            ),
            MacroRingChart(
              label: 'Carbs',
              actual: totals.carbs,
              goal: goals.carbs,
              unit: 'g',
              color: AppColors.carbs,
            ),
            MacroRingChart(
              label: 'Fat',
              actual: totals.fat,
              goal: goals.fat,
              unit: 'g',
              color: AppColors.fat,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Macro progress bars
// ---------------------------------------------------------------------------
class _MacroProgressCard extends StatelessWidget {
  const _MacroProgressCard({required this.totals, required this.goals});
  final MacroValues totals;
  final MacroGoals goals;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Macro Breakdown',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 14),
            _bar('Calories', totals.kcal, goals.kcal, 'kcal', AppColors.kcal),
            const SizedBox(height: 10),
            _bar('Protein',  totals.protein, goals.protein, 'g', AppColors.protein),
            const SizedBox(height: 10),
            _bar('Carbs',    totals.carbs,   goals.carbs,   'g', AppColors.carbs),
            const SizedBox(height: 10),
            _bar('Fat',      totals.fat,     goals.fat,     'g', AppColors.fat),
          ],
        ),
      ),
    );
  }

  Widget _bar(String label, double actual, double goal, String unit, Color color) {
    final pct = goal > 0 ? (actual / goal).clamp(0.0, 1.0) : 0.0;
    final over = goal > 0 && actual > goal;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
            Text(
              '${actual.round()} / ${goal.round()} $unit',
              style: TextStyle(
                fontSize: 12,
                color: over ? AppColors.danger : AppColors.textMuted,
                fontWeight: over ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            backgroundColor: AppColors.border,
            valueColor: AlwaysStoppedAnimation(over ? AppColors.danger : color),
            minHeight: 6,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Top foods by kcal for the day
// ---------------------------------------------------------------------------
class _TopFoodsCard extends ConsumerWidget {
  const _TopFoodsCard({required this.date});
  final String date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(entriesProvider(date)).valueOrNull ?? [];
    if (entries.isEmpty) return const SizedBox.shrink();

    final sorted = [...entries]
      ..sort((a, b) => b.macros.kcal.compareTo(a.macros.kcal));
    final top5 = sorted.take(5).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Top Foods Today',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 12),
            ...top5.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
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
                    '${e.macros.kcal.round()} kcal',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.kcal,
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }
}
