import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/constants.dart';
import '../models/entry.dart';
import '../models/food.dart';
import '../providers/compare_provider.dart';
import '../providers/entries_provider.dart';
import '../providers/settings_provider.dart';
import '../theme.dart';
import 'add_entry_sheet.dart';
import 'compare_sheet.dart' show compareColors;

// ── Meal slot colours & labels ────────────────────────────────────────────────

const _mealColors = {
  'breakfast': AppColors.protein,
  'lunch':     AppColors.carbs,
  'dinner':    AppColors.fat,
  'snack':     AppColors.kcal,
  'other':     Color(0xFF94A3B8),
};

const _mealEmojis = {
  'breakfast': '🌅',
  'lunch':     '☀️',
  'dinner':    '🌙',
  'snack':     '🍿',
  'other':     '·',
};

// ── Entry point ───────────────────────────────────────────────────────────────

void showFoodDetailSheet(
  BuildContext context,
  WidgetRef ref,
  Food food,
  String logDate,
) {
  final container = ProviderScope.containerOf(context);
  showModalBottomSheet(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => ProviderScope(
      parent: container,
      child: _FoodDetailSheet(food: food, logDate: logDate),
    ),
  );
}

// ── Main sheet ────────────────────────────────────────────────────────────────

class _FoodDetailSheet extends ConsumerStatefulWidget {
  const _FoodDetailSheet({required this.food, required this.logDate});
  final Food food;
  final String logDate;

  @override
  ConsumerState<_FoodDetailSheet> createState() => _FoodDetailSheetState();
}

class _FoodDetailSheetState extends ConsumerState<_FoodDetailSheet> {
  late double _qty;

  @override
  void initState() {
    super.initState();
    _qty = widget.food.unit == 'perServing' ? 1.0 : 100.0;
  }

  @override
  Widget build(BuildContext context) {
    final cs = AppColorScheme.of(context);
    final food = widget.food;
    final scaled = food.scaledMacros(_qty);
    final goals = ref.watch(settingsProvider).goalsForDate(widget.logDate);
    final historyAsync = ref.watch(foodEntriesProvider(food.id));

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) => Container(
        decoration: BoxDecoration(
          color: cs.bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Drag handle
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                children: [
                  _buildHeader(context, cs, food),
                  const SizedBox(height: 16),
                  _CompositionCard(food: food),
                  const SizedBox(height: 12),
                  _GoalContributionCard(
                    food: food,
                    scaled: scaled,
                    qty: _qty,
                    goals: goals,
                    onQtyChanged: (v) => setState(() => _qty = v),
                  ),
                  const SizedBox(height: 12),
                  historyAsync.when(
                    loading: () => const SizedBox(
                      height: 80,
                      child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (entries) => entries.isEmpty
                        ? const SizedBox.shrink()
                        : _UsageCard(entries: entries, food: food),
                  ),
                  const SizedBox(height: 20),
                  // ── Compare button ──────────────────────────────────────
                  _CompareButton(food: food),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () {
                      final qty = _qty;
                      Navigator.pop(context);
                      showAddEntrySheet(
                        context,
                        ref,
                        widget.logDate,
                        preselectedFood: food,
                        preselectedQty: qty,
                      );
                    },
                    child: const Text('Log this food'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AppColorScheme cs, Food food) {
    final emoji = categoryEmojis[food.category] ?? '🍽️';
    final unitLabel = food.unit == 'per100g' ? 'per 100 g' : 'per serving';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 36)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                food.name,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (food.brand != null && food.brand!.isNotEmpty)
                Text(
                  food.brand!,
                  style: TextStyle(fontSize: 13, color: cs.textMuted),
                ),
              const SizedBox(height: 2),
              Text(
                '${food.kcal.round()} kcal · $unitLabel',
                style: TextStyle(fontSize: 13, color: cs.textMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Section card shell ────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = AppColorScheme.of(context);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cs.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.border),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: cs.textMuted,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

// ── Composition donut ─────────────────────────────────────────────────────────

class _CompositionCard extends StatefulWidget {
  const _CompositionCard({required this.food});
  final Food food;

  @override
  State<_CompositionCard> createState() => _CompositionCardState();
}

class _CompositionCardState extends State<_CompositionCard> {
  int? _touched;

  @override
  Widget build(BuildContext context) {
    final cs = AppColorScheme.of(context);
    final food = widget.food;
    final proteinKcal = food.protein * 4;
    final carbsKcal = food.carbs * 4;
    final fatKcal = food.fat * 9;
    final total = proteinKcal + carbsKcal + fatKcal;

    if (total <= 0) return const SizedBox.shrink();

    final pctC = carbsKcal / total * 100;
    final pctF = fatKcal / total * 100;
    final pctP = proteinKcal / total * 100;

    // Sections: 0 = carbs, 1 = fat, 2 = protein
    final sections = [
      PieChartSectionData(
        value: carbsKcal,
        color: AppColors.carbs,
        radius: _touched == 0 ? 58.0 : 50.0,
        showTitle: _touched == 0,
        title: '${pctC.round()}%',
        titleStyle: const TextStyle(
            fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
      ),
      PieChartSectionData(
        value: fatKcal,
        color: AppColors.fat,
        radius: _touched == 1 ? 58.0 : 50.0,
        showTitle: _touched == 1,
        title: '${pctF.round()}%',
        titleStyle: const TextStyle(
            fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
      ),
      PieChartSectionData(
        value: proteinKcal,
        color: AppColors.protein,
        radius: _touched == 2 ? 58.0 : 50.0,
        showTitle: _touched == 2,
        title: '${pctP.round()}%',
        titleStyle: const TextStyle(
            fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
      ),
    ];

    return _SectionCard(
      title: 'Composition',
      child: Row(
        children: [
          SizedBox(
            width: 160,
            height: 160,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    startDegreeOffset: -90,
                    sectionsSpace: 2,
                    centerSpaceRadius: 40,
                    sections: sections,
                    pieTouchData: PieTouchData(
                      touchCallback: (event, response) {
                        setState(() {
                          if (event.isInterestedForInteractions &&
                              response?.touchedSection != null) {
                            _touched = response!
                                .touchedSection!.touchedSectionIndex;
                          } else {
                            _touched = null;
                          }
                        });
                      },
                    ),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${food.kcal.round()}',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: cs.kcalColor,
                      ),
                    ),
                    Text(
                      'kcal',
                      style: TextStyle(fontSize: 10, color: cs.textMuted),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _LegendItem(
                    color: AppColors.carbs,
                    label: 'Carbs',
                    grams: food.carbs,
                    pct: pctC),
                const SizedBox(height: 14),
                _LegendItem(
                    color: AppColors.fat,
                    label: 'Fat',
                    grams: food.fat,
                    pct: pctF),
                const SizedBox(height: 14),
                _LegendItem(
                    color: AppColors.protein,
                    label: 'Protein',
                    grams: food.protein,
                    pct: pctP),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.label,
    required this.grams,
    required this.pct,
  });
  final Color color;
  final String label;
  final double grams;
  final double pct;

  @override
  Widget build(BuildContext context) {
    final cs = AppColorScheme.of(context);
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label,
              style: TextStyle(fontSize: 12, color: cs.textMuted)),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('${grams.round()} g',
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
            Text('${pct.round()}%',
                style: TextStyle(fontSize: 10, color: cs.textMuted)),
          ],
        ),
      ],
    );
  }
}

// ── Goal contribution ─────────────────────────────────────────────────────────

class _GoalContributionCard extends StatelessWidget {
  const _GoalContributionCard({
    required this.food,
    required this.scaled,
    required this.qty,
    required this.goals,
    required this.onQtyChanged,
  });
  final Food food;
  final MacroValues scaled;
  final double qty;
  final MacroGoals goals;
  final ValueChanged<double> onQtyChanged;

  @override
  Widget build(BuildContext context) {
    final cs = AppColorScheme.of(context);
    final isPer100g = food.unit == 'per100g';
    final sliderMin = isPer100g ? 10.0 : 0.25;
    final sliderMax = isPer100g ? 600.0 : 6.0;
    // steps of 5 g or 0.25 srv
    final divisions = isPer100g ? 118 : 23;
    final qtyLabel = isPer100g
        ? '${qty.round()} g'
        : '${qty % 1 == 0 ? qty.round() : qty.toStringAsFixed(2)} srv';

    return _SectionCard(
      title: 'Goal contribution',
      child: Column(
        children: [
          Row(
            children: [
              Text('Qty', style: TextStyle(fontSize: 12, color: cs.textMuted)),
              Expanded(
                child: Slider(
                  value: qty,
                  min: sliderMin,
                  max: sliderMax,
                  divisions: divisions,
                  onChanged: onQtyChanged,
                  activeColor: cs.kcalColor,
                  inactiveColor: cs.border,
                ),
              ),
              SizedBox(
                width: 64,
                child: Text(
                  qtyLabel,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _GoalBar(
              label: 'Kcal',
              actual: scaled.kcal,
              goal: goals.kcal,
              color: cs.kcalColor,
              unit: 'kcal'),
          const SizedBox(height: 12),
          _GoalBar(
              label: 'Protein',
              actual: scaled.protein,
              goal: goals.protein,
              color: AppColors.protein,
              unit: 'g'),
          const SizedBox(height: 12),
          _GoalBar(
              label: 'Carbs',
              actual: scaled.carbs,
              goal: goals.carbs,
              color: AppColors.carbs,
              unit: 'g'),
          const SizedBox(height: 12),
          _GoalBar(
              label: 'Fat',
              actual: scaled.fat,
              goal: goals.fat,
              color: AppColors.fat,
              unit: 'g'),
        ],
      ),
    );
  }
}

class _GoalBar extends StatelessWidget {
  const _GoalBar({
    required this.label,
    required this.actual,
    required this.goal,
    required this.color,
    required this.unit,
  });
  final String label, unit;
  final double actual, goal;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final cs = AppColorScheme.of(context);
    final pct = goal > 0 ? (actual / goal).clamp(0.0, 1.0) : 0.0;
    final pctStr = goal > 0 ? '${(actual / goal * 100).round()}%' : '—';
    final isOver = goal > 0 && actual > goal;
    final barColor = isOver ? AppColors.danger : color;

    return Column(
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration:
                  BoxDecoration(color: barColor, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(fontSize: 12, color: cs.textMuted)),
            const Spacer(),
            Text(
              '${actual.round()} $unit',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: barColor),
            ),
            Text(
              '  ·  $pctStr of goal',
              style: TextStyle(fontSize: 11, color: cs.textMuted),
            ),
          ],
        ),
        const SizedBox(height: 6),
        LayoutBuilder(builder: (ctx, box) {
          return Stack(
            children: [
              Container(
                height: 6,
                decoration: BoxDecoration(
                  color: cs.border,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              Container(
                height: 6,
                width: box.maxWidth * pct,
                decoration: BoxDecoration(
                  color: barColor,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ],
          );
        }),
      ],
    );
  }
}

// ── Usage / history ───────────────────────────────────────────────────────────

class _UsageCard extends StatelessWidget {
  const _UsageCard({required this.entries, required this.food});
  final List<Entry> entries;
  final Food food;

  @override
  Widget build(BuildContext context) {
    final count = entries.length;
    final avgQty =
        entries.fold<double>(0.0, (s, e) => s + e.qty) / count;

    // Most-used meal slot
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
    final avgLabel = isPer100g
        ? '${avgQty.round()} g'
        : avgQty.toStringAsFixed(1);

    return _SectionCard(
      title: 'History',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Stat pills ─────────────────────────────────────────────────
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
          const SizedBox(height: 18),
          // ── Scatter plot ───────────────────────────────────────────────
          _ScatterPlot(entries: entries, isPer100g: isPer100g),
          const SizedBox(height: 18),
          // ── Meal-slot donut ────────────────────────────────────────────
          _MealDistribution(mealCounts: allMealCounts, total: count),
        ],
      ),
    );
  }

  static String _cap(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}

// ── Compare button (reads compare state, shows slot colour when active) ────────

class _CompareButton extends ConsumerWidget {
  const _CompareButton({required this.food});
  final Food food;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foods = ref.watch(compareProvider);
    final idx = foods.indexWhere((f) => f.id == food.id);
    final inCompare = idx >= 0;
    final isFull = foods.length >= CompareNotifier.maxFoods && !inCompare;
    final slotColor = inCompare ? compareColors[idx] : null;

    return OutlinedButton.icon(
      icon: Icon(
        inCompare
            ? Icons.check_circle_outline
            : Icons.compare_arrows_rounded,
        size: 18,
        color: slotColor,
      ),
      label: Text(
        inCompare
            ? 'In comparison (${foods.length}/${CompareNotifier.maxFoods})'
            : isFull
                ? 'Compare full (${CompareNotifier.maxFoods}/${CompareNotifier.maxFoods})'
                : 'Add to compare',
        style: TextStyle(color: slotColor),
      ),
      onPressed: isFull
          ? null
          : () => ref.read(compareProvider.notifier).toggle(food),
      style: slotColor != null
          ? OutlinedButton.styleFrom(
              side: BorderSide(color: slotColor.withValues(alpha: 0.6)),
            )
          : null,
    );
  }
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
        padding:
            const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
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
              style:
                  TextStyle(fontSize: 10, color: cs.textMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Scatter dot plot ──────────────────────────────────────────────────────────

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
        dotPainter:
            FlDotCirclePainter(radius: 5, color: color, strokeWidth: 0),
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
                          style: TextStyle(
                              fontSize: 9, color: cs.textMuted),
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

// ── Meal-slot donut ───────────────────────────────────────────────────────────

class _MealDistribution extends StatelessWidget {
  const _MealDistribution(
      {required this.mealCounts, required this.total});
  final Map<String, int> mealCounts;
  final int total;

  @override
  Widget build(BuildContext context) {
    final cs = AppColorScheme.of(context);
    final active =
        mealCounts.entries.where((e) => e.value > 0).toList();
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
              final color =
                  _mealColors[e.key] ?? _mealColors['other']!;
              final emoji = _mealEmojis[e.key] ?? '·';
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                        color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$emoji ${_cap(e.key)}  $pct%',
                    style: TextStyle(
                        fontSize: 11, color: cs.textMuted),
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
