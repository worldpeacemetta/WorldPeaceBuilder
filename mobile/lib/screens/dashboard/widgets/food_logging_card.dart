import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/entry.dart';
import '../../../models/food.dart';
import '../../../providers/entries_provider.dart';
import '../../../theme.dart';

const _mealIcons = {
  'breakfast': '🌅',
  'lunch'    : '☀️',
  'dinner'   : '🌙',
  'snack'    : '🍎',
  'other'    : '🍽️',
};

/// Average macro intake per meal slot over a selectable rolling period.
class FoodLoggingCard extends ConsumerStatefulWidget {
  const FoodLoggingCard({super.key});

  @override
  ConsumerState<FoodLoggingCard> createState() => _FoodLoggingCardState();
}

class _FoodLoggingCardState extends ConsumerState<FoodLoggingCard> {
  String _period = '1W';
  String _macro  = 'kcal';

  // Cache the last successfully computed averages so we can crossfade
  // instead of showing a spinner while a new period loads.
  Map<String, double>? _lastAvgs;
  double _lastMaxVal = 1;
  double _lastTotal  = 0;

  static const _periods      = ['1W', '1M', '3M', '1Y'];
  static const _macros       = ['kcal', 'protein', 'carbs', 'fat'];
  static const _macroLabels  = ['Cal', 'Pro', 'Carb', 'Fat'];
  static const _macroColors  = <Color>[
    AppColors.kcal, AppColors.protein, AppColors.carbs, AppColors.fat,
  ];

  String _startDate() {
    final days = switch (_period) {
      '1W' => 7,
      '1M' => 30,
      '3M' => 91,
      '1Y' => 365,
      _    => 30,
    };
    final start = DateTime.now().subtract(Duration(days: days));
    return '${start.year.toString().padLeft(4, '0')}'
        '-${start.month.toString().padLeft(2, '0')}'
        '-${start.day.toString().padLeft(2, '0')}';
  }

  double _macroValue(MacroValues m) => switch (_macro) {
        'protein' => m.protein,
        'carbs'   => m.carbs,
        'fat'     => m.fat,
        _         => m.kcal,
      };

  Color _colorFor(BuildContext ctx) => switch (_macro) {
        'protein' => AppColors.protein,
        'carbs'   => AppColors.carbs,
        'fat'     => AppColors.fat,
        _         => AppColorScheme.of(ctx).kcalColor,
      };

  String get _unit => _macro == 'kcal' ? 'kcal' : 'g';

  int get _macroIndex => _macros.indexOf(_macro);

  /// Avg macro per meal slot — only counts days where the slot was logged.
  Map<String, double> _computeAvg(List<Entry> entries) {
    // Accumulate per-day per-meal totals
    final dayMeal = <String, Map<String, double>>{};
    for (final e in entries) {
      dayMeal.putIfAbsent(e.date, () => {});
      final m = dayMeal[e.date]!;
      m[e.meal] = (m[e.meal] ?? 0) + _macroValue(e.macros);
    }
    // Sum across days, count days logged per meal slot
    final sums   = <String, double>{};
    final counts = <String, int>{};
    for (final dayMap in dayMeal.values) {
      for (final kv in dayMap.entries) {
        sums[kv.key]   = (sums[kv.key]   ?? 0) + kv.value;
        counts[kv.key] = (counts[kv.key] ?? 0) + 1;
      }
    }
    // Return in mealOrder, skip slots with no data
    return {
      for (final meal in mealOrder)
        if (sums.containsKey(meal)) meal: sums[meal]! / counts[meal]!,
    };
  }

  Widget _chip({
    required String label,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Builder(builder: (context) {
      final cs = AppColorScheme.of(context);
      return GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(left: 4),
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? color : cs.border),
          ),
          child: Text(label,
              style: TextStyle(
                  color: selected ? color : cs.textMuted,
                  fontSize: 10,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal)),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = AppColorScheme.of(context);
    final entriesAsync = ref.watch(entriesInRangeProvider(_startDate()));
    final periodColor = cs.textPrimary;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title + period chips
            Row(
              children: [
                const Text('Avg per Meal',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const Spacer(),
                ..._periods.map((p) => _chip(
                      label: p,
                      selected: p == _period,
                      color: periodColor,
                      onTap: () => setState(() => _period = p),
                    )),
              ],
            ),
            const SizedBox(height: 3),
            // Subtitle + macro chips
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text('Average intake per meal slot',
                      style: TextStyle(
                          fontSize: 10,
                          color: cs.textMuted,
                          fontStyle: FontStyle.italic)),
                ),
                ..._macros.asMap().entries.map((e) => _chip(
                      label: _macroLabels[e.key],
                      selected: e.value == _macro,
                      color: e.key == 0 ? cs.kcalColor : _macroColors[e.key],
                      onTap: () => setState(() => _macro = e.value),
                    )),
              ],
            ),
            const SizedBox(height: 16),
            // Bars
            Builder(builder: (context) {
              final barColor = _colorFor(context);
              // On new data, update cache
              entriesAsync.whenData((entries) {
                final avgs = _computeAvg(entries);
                if (avgs.isNotEmpty) {
                  _lastAvgs   = avgs;
                  _lastMaxVal = avgs.values.reduce((a, b) => a > b ? a : b);
                  _lastTotal  = avgs.values.fold(0.0, (s, v) => s + v);
                }
              });

              final isLoading = entriesAsync.isLoading;
              final avgs = _lastAvgs;

              // Show spinner only while data is still in flight AND we have
              // nothing cached to display yet.
              if (avgs == null) {
                if (isLoading) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                }
                // Data loaded but no entries in this period — empty state.
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text(
                      'No meals logged in this period',
                      style: TextStyle(
                          fontSize: 12,
                          color: cs.textMuted,
                          fontStyle: FontStyle.italic),
                    ),
                  ),
                );
              }

              if (entriesAsync.hasError) {
                return Text('Failed to load',
                    style: TextStyle(color: cs.textMuted));
              }

              final maxVal   = _lastMaxVal;
              final total    = _lastTotal;
              final totalStr = total >= 10
                  ? '${total.round()} $_unit'
                  : '${total.toStringAsFixed(1)} $_unit';

              // Key forces TweenAnimationBuilder to restart from 0 whenever
              // the period or macro changes.
              final animKey = '$_period/$_macro';

              return AnimatedOpacity(
                opacity: isLoading ? 0.45 : 1.0,
                duration: const Duration(milliseconds: 300),
                child: TweenAnimationBuilder<double>(
                  key: ValueKey(animKey),
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 840),
                  curve: Curves.easeOut,
                  builder: (_, progress, __) => Column(
                    children: [
                      ...avgs.entries.map((e) {
                        final share = maxVal > 0
                            ? (e.value / maxVal).clamp(0.0, 1.0) * progress
                            : 0.0;
                        final valStr = e.value >= 10
                            ? '${e.value.round()} $_unit'
                            : '${e.value.toStringAsFixed(1)} $_unit';
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Column(
                            children: [
                              Row(children: [
                                Text(_mealIcons[e.key] ?? '🍽️',
                                    style: const TextStyle(fontSize: 13)),
                                const SizedBox(width: 7),
                                Expanded(
                                  child: Text(mealLabels[e.key] ?? e.key,
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500)),
                                ),
                                Text(valStr,
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: barColor)),
                              ]),
                              const SizedBox(height: 4),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(2),
                                child: LinearProgressIndicator(
                                  value: share,
                                  minHeight: 4,
                                  backgroundColor: cs.border,
                                  valueColor: AlwaysStoppedAnimation(barColor),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      // Total row
                      Divider(height: 16, color: cs.border),
                      Row(children: [
                        const Text('∑',
                            style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w700)),
                        const SizedBox(width: 7),
                        const Expanded(
                          child: Text('Total',
                              style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w700)),
                        ),
                        Text(totalStr,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: barColor)),
                      ]),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
