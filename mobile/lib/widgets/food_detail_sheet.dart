import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants.dart';
import '../models/food.dart';
import '../providers/compare_provider.dart';
import '../providers/entries_provider.dart';
import '../providers/foods_provider.dart';
import '../providers/settings_provider.dart';
import '../theme.dart';
import 'add_entry_sheet.dart';
import 'compare_sheet.dart' show compareColors;
import 'food_detail/composition_card.dart';
import 'food_detail/section_card.dart';
import 'food_detail/usage_card.dart';


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
                  CompositionCard(food: food),
                  if (food.isRecipe) ...[
                    const SizedBox(height: 12),
                    _IngredientsCard(food: food),
                    if (food.instructions != null &&
                        food.instructions!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _InstructionsCard(instructions: food.instructions!),
                    ],
                  ],
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
                        ? UsageCard(entries: const [], food: food)
                        : UsageCard(entries: entries, food: food),
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
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      food.name,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (food.isRecipe) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.carbs.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Recipe',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.carbs),
                      ),
                    ),
                  ],
                ],
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

// ── Recipe: Ingredients ───────────────────────────────────────────────────────

class _IngredientsCard extends ConsumerWidget {
  const _IngredientsCard({required this.food});
  final Food food;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = AppColorScheme.of(context);
    final allFoods = ref.watch(foodListProvider);

    final rows = food.components.map((ing) {
      final f = allFoods.where((x) => x.id == ing.foodId).firstOrNull;
      final name = f?.displayName ?? 'Unknown food';
      final label = f?.unit == 'perServing'
          ? '${(ing.quantity / (f!.servingSize ?? 1.0)).toStringAsFixed(1)} srv'
          : '${ing.quantity.round()} g';
      return (name: name, label: label);
    }).toList();

    return SectionCard(
      title: 'Ingredients (${rows.length})',
      child: Column(
        children: rows.asMap().entries.map((e) {
          final isLast = e.key == rows.length - 1;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: cs.textMuted,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        e.value.name,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    Text(
                      e.value.label,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: cs.textMuted),
                    ),
                  ],
                ),
              ),
              if (!isLast) Divider(height: 1, color: cs.border),
            ],
          );
        }).toList(),
      ),
    );
  }
}

// ── Recipe: Instructions ──────────────────────────────────────────────────────

class _InstructionsCard extends StatelessWidget {
  const _InstructionsCard({required this.instructions});
  final String instructions;

  @override
  Widget build(BuildContext context) {
    final cs = AppColorScheme.of(context);
    return SectionCard(
      title: 'Instructions',
      child: Text(
        instructions,
        style: TextStyle(fontSize: 13, height: 1.55, color: cs.textPrimary),
      ),
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

    return SectionCard(
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

// UsageCard, ScatterPlot, MealDistribution live in food_detail/usage_card.dart
