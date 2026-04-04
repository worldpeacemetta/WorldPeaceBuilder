import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils.dart';
import '../../models/food.dart';
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

          // Food Logging per-meal breakdown
          FoodLoggingCard(date: date),
          const SizedBox(height: 16),

          // Top foods
          _TopFoodsCard(date: date),
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

// ---------------------------------------------------------------------------
// Top foods by kcal for the day
// ---------------------------------------------------------------------------
class _TopFoodsCard extends ConsumerStatefulWidget {
  const _TopFoodsCard({required this.date});
  final String date;

  @override
  ConsumerState<_TopFoodsCard> createState() => _TopFoodsCardState();
}

class _TopFoodsCardState extends ConsumerState<_TopFoodsCard> {
  String _macro = 'kcal';

  double _value(MacroValues m) => switch (_macro) {
    'protein' => m.protein,
    'carbs'   => m.carbs,
    'fat'     => m.fat,
    _         => m.kcal,
  };

  String _unit() => _macro == 'kcal' ? 'kcal' : 'g';

  Color _color() => switch (_macro) {
    'protein' => AppColors.protein,
    'carbs'   => AppColors.carbs,
    'fat'     => AppColors.fat,
    _         => AppColors.kcal,
  };

  @override
  Widget build(BuildContext context) {
    final entries = ref.watch(entriesProvider(widget.date)).valueOrNull ?? [];
    if (entries.isEmpty) return const SizedBox.shrink();

    final sorted = [...entries]
      ..sort((a, b) => _value(b.macros).compareTo(_value(a.macros)));
    final top5 = sorted.take(5).toList();
    final maxVal = _value(top5.first.macros);

    final cs = AppColorScheme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header + macro toggle
            Row(
              children: [
                const Expanded(
                  child: Text('Top Foods Today',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                ),
                _MacroToggle(selected: _macro, onChanged: (v) => setState(() => _macro = v)),
              ],
            ),
            const SizedBox(height: 12),
            ...top5.map((e) {
              final val = _value(e.macros);
              final pct = maxVal > 0 ? val / maxVal : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
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
                          '${val.round()} ${_unit()}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _color(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: pct.toDouble(),
                        minHeight: 3,
                        backgroundColor: cs.border,
                        valueColor: AlwaysStoppedAnimation(_color()),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _MacroToggle extends StatelessWidget {
  const _MacroToggle({required this.selected, required this.onChanged});
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = AppColorScheme.of(context);
    const macros = ['kcal', 'protein', 'carbs', 'fat'];
    const colors = {
      'kcal': AppColors.kcal, 'protein': AppColors.protein,
      'carbs': AppColors.carbs, 'fat': AppColors.fat,
    };
    const labels = {
      'kcal': 'Cal', 'protein': 'Pro', 'carbs': 'Carb', 'fat': 'Fat',
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: macros.map((m) {
        final active = m == selected;
        final color = colors[m]!;
        return GestureDetector(
          onTap: () => onChanged(m),
          child: Container(
            margin: const EdgeInsets.only(left: 4),
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: active ? color.withValues(alpha: 0.2) : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: active ? color : cs.border,
                width: active ? 1.2 : 1,
              ),
            ),
            child: Text(
              labels[m]!,
              style: TextStyle(
                fontSize: 10,
                fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                color: active ? color : cs.textMuted,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
