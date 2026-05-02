import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/entry.dart';
import '../../models/food.dart';
import '../../theme.dart';
import 'section_card.dart';

const _mealColors = {
  'breakfast': AppColors.protein,
  'lunch': AppColors.carbs,
  'dinner': AppColors.fat,
  'snack': AppColors.kcal,
  'other': Color(0xFF94A3B8),
};

const _mealEmojis = {
  'breakfast': '🌅',
  'lunch': '☀️',
  'dinner': '🌙',
  'snack': '🍿',
  'other': '·',
};

class UsageCard extends StatelessWidget {
  const UsageCard({super.key, required this.entries, required this.food});
  final List<Entry> entries;
  final Food food;

  @override
  Widget build(BuildContext context) {
    final cs = AppColorScheme.of(context);
    final addedLabel = food.createdAt != null
        ? DateFormat('MMM d, yyyy').format(food.createdAt!.toLocal())
        : null;

    if (entries.isEmpty) {
      if (addedLabel == null) return const SizedBox.shrink();
      return SectionCard(
        title: 'History',
        child: Row(
          children: [
            _StatPill(label: 'Added', value: addedLabel),
            const Expanded(child: SizedBox()),
            const Expanded(child: SizedBox()),
          ],
        ),
      );
    }

    final count = entries.length;
    final avgQty = entries.fold<double>(0.0, (s, e) => s + e.qty) / count;

    final mealCounts = <String, int>{};
    for (final e in entries) {
      mealCounts[e.meal] = (mealCounts[e.meal] ?? 0) + 1;
    }
    final favMeal =
        mealCounts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    final favColor = _mealColors[favMeal] ?? _mealColors['other']!;
    final favEmoji = _mealEmojis[favMeal] ?? '·';

    final allMealCounts = {
      for (final m in ['breakfast', 'lunch', 'dinner', 'snack', 'other'])
        m: mealCounts[m] ?? 0
    };

    final isPer100g = food.unit == 'per100g';
    final avgLabel =
        isPer100g ? '${avgQty.round()} g' : avgQty.toStringAsFixed(1);

    return SectionCard(
      title: 'History',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _StatPill(label: 'Logged', value: '${count}×'),
              const SizedBox(width: 8),
              _StatPill(label: 'Avg qty', value: avgLabel),
              const SizedBox(width: 8),
              _StatPill(
                label: 'Fav meal',
                value: '$favEmoji ${_cap(favMeal)}',
                valueColor: favColor,
              ),
            ],
          ),
          if (addedLabel != null) ...[
            const SizedBox(height: 8),
            Text(
              'Added $addedLabel',
              style: TextStyle(fontSize: 11, color: cs.textMuted),
            ),
          ],
          const SizedBox(height: 18),
          _ScatterPlot(entries: entries, isPer100g: isPer100g),
          const SizedBox(height: 18),
          _MealDistribution(mealCounts: allMealCounts, total: count),
        ],
      ),
    );
  }

  static String _cap(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.label,
    required this.value,
    this.valueColor,
  });
  final String label, value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final cs = AppColorScheme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: cs.bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: cs.border),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: valueColor ?? cs.textPrimary,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontSize: 10, color: cs.textMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ScatterPlot extends StatelessWidget {
  const _ScatterPlot({required this.entries, required this.isPer100g});
  final List<Entry> entries;
  final bool isPer100g;

  @override
  Widget build(BuildContext context) {
    final cs = AppColorScheme.of(context);

    final spots = entries.map((e) {
      final dt = DateTime.parse(e.date);
      final x = dt.millisecondsSinceEpoch / 86400000.0;
      final color = _mealColors[e.meal] ?? _mealColors['other']!;
      return ScatterSpot(
        x,
        e.qty,
        dotPainter: FlDotCirclePainter(radius: 5, color: color, strokeWidth: 0),
      );
    }).toList();

    final xs = spots.map((s) => s.x).toList();
    final ys = entries.map((e) => e.qty).toList();
    final minX = xs.reduce(min);
    final maxX = xs.reduce(max);
    final maxY = ys.reduce(max);

    final xRange = max(maxX - minX, 14.0);
    final xPad = xRange * 0.08;
    final interval =
        xRange > 365 ? 90.0 : xRange > 90 ? 30.0 : xRange > 30 ? 14.0 : 7.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        SizedBox(
          height: 160,
          child: ScatterChart(
            ScatterChartData(
              scatterSpots: spots,
              minX: minX - xPad,
              maxX: maxX + xPad,
              minY: 0,
              maxY: maxY * 1.35,
              scatterTouchData: ScatterTouchData(enabled: false),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) =>
                    FlLine(color: cs.border, strokeWidth: 0.5),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 24,
                    interval: interval,
                    getTitlesWidget: (value, meta) {
                      final dt = DateTime.fromMillisecondsSinceEpoch(
                          (value * 86400000).round());
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          DateFormat('MMM d').format(dt),
                          style:
                              TextStyle(fontSize: 9, color: cs.textMuted),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          isPer100g ? 'y-axis: grams' : 'y-axis: servings',
          style: TextStyle(fontSize: 9, color: cs.textMuted),
        ),
      ],
    );
  }
}

class _MealDistribution extends StatelessWidget {
  const _MealDistribution(
      {required this.mealCounts, required this.total});
  final Map<String, int> mealCounts;
  final int total;

  @override
  Widget build(BuildContext context) {
    final cs = AppColorScheme.of(context);
    final active = mealCounts.entries.where((e) => e.value > 0).toList();
    if (active.isEmpty) return const SizedBox.shrink();

    final sections = active
        .map((e) => PieChartSectionData(
              value: e.value.toDouble(),
              color: _mealColors[e.key] ?? _mealColors['other']!,
              radius: 30,
              showTitle: false,
            ))
        .toList();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 80,
          height: 80,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 22,
              sections: sections,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Wrap(
            spacing: 12,
            runSpacing: 8,
            children: active.map((e) {
              final pct = (e.value / total * 100).round();
              final color = _mealColors[e.key] ?? _mealColors['other']!;
              final emoji = _mealEmojis[e.key] ?? '·';
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration:
                        BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$emoji ${_cap(e.key)}  $pct%',
                    style: TextStyle(fontSize: 11, color: cs.textMuted),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  static String _cap(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}
