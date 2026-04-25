import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils.dart';
import '../../providers/date_provider.dart';
import '../../providers/entries_provider.dart';
import '../../providers/settings_provider.dart';
import '../../theme.dart';
import '../../widgets/activity_rings_panel.dart';
import '../../widgets/mode_pill.dart';

import 'widgets/food_logging_card.dart';
import 'widgets/weekly_nutrition_chart.dart';
import 'widgets/weight_trend_card.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final date = ref.watch(dashboardDateProvider);
    final totals = ref.watch(macroTotalsProvider(date));
    final goals = ref.watch(settingsProvider).goalsForDate(date);
    final isToday = date == todayISO();

    final cs = AppColorScheme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Dashboard'),
            Row(
              children: [
                Text(
                  formatDateFull(date),
                  style: TextStyle(fontSize: 12, color: cs.textMuted, fontWeight: FontWeight.w400),
                ),
                const SizedBox(width: 8),
                ModePill(date: date),
              ],
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
          // Concentric rings
          Card(
            margin: EdgeInsets.zero,
            child: ActivityRingsPanel(totals: totals, goals: goals),
          ),
          const SizedBox(height: 16),

          // Avg per Meal (rolling period × macro)
          const FoodLoggingCard(),
          const SizedBox(height: 16),

          // Weekly Nutrition (multi-macro toggle)
          WeeklyNutritionChart(date: date),
          const SizedBox(height: 16),

          // Weight Trend
          const WeightTrendCard(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

