import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/food.dart';
import '../providers/compare_provider.dart';
import '../theme.dart';

// ── Public colour palette — one per comparison slot ───────────────────────────
// Imported by food_detail_sheet.dart to colour the "Add to compare" indicator.

const compareColors = [
  AppColors.protein, // slot 0 — teal mist
  AppColors.carbs,   // slot 1 — rose
  AppColors.fat,     // slot 2 — peach
];

// ── Floating bar shown at the bottom of food_db_screen ───────────────────────

class CompareBar extends ConsumerWidget {
  const CompareBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foods = ref.watch(compareProvider);
    if (foods.isEmpty) return const SizedBox.shrink();

    final cs = AppColorScheme.of(context);
    final canCompare = foods.length >= 2;

    return Container(
      decoration: BoxDecoration(
        color: cs.card,
        border: Border(top: BorderSide(color: cs.border)),
      ),
      padding: EdgeInsets.fromLTRB(
        16,
        10,
        16,
        16 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Food chips row ─────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: foods.asMap().entries.map((entry) {
                    final color = compareColors[entry.key];
                    final food = entry.value;
                    return _FoodChip(
                      food: food,
                      color: color,
                      onRemove: () =>
                          ref.read(compareProvider.notifier).remove(food.id),
                    );
                  }).toList(),
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, size: 18, color: cs.textMuted),
                onPressed: () => ref.read(compareProvider.notifier).clear(),
                tooltip: 'Clear comparison',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // ── Action row ─────────────────────────────────────────────────
          Row(
            children: [
              if (!canCompare)
                Expanded(
                  child: Text(
                    'Add ${2 - foods.length} more food to compare',
                    style: TextStyle(fontSize: 12, color: cs.textMuted),
                  ),
                ),
              if (canCompare)
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.compare_arrows_rounded, size: 18),
                    label: Text('Compare ${foods.length} foods'),
                    onPressed: () =>
                        showCompareSheet(context, foods),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FoodChip extends StatelessWidget {
  const _FoodChip({
    required this.food,
    required this.color,
    required this.onRemove,
  });
  final Food food;
  final Color color;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final cs = AppColorScheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 100),
            child: Text(
              food.name,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: cs.textPrimary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: Icon(Icons.close, size: 14, color: cs.textMuted),
          ),
        ],
      ),
    );
  }
}

// ── Compare bottom sheet ──────────────────────────────────────────────────────

void showCompareSheet(BuildContext context, List<Food> foods) {
  final cs = Theme.of(context).extension<AppColorScheme>()!;
  showModalBottomSheet(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _CompareSheet(foods: foods, cs: cs),
  );
}

class _CompareSheet extends StatelessWidget {
  const _CompareSheet({required this.foods, required this.cs});
  final List<Food> foods;
  final AppColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (_, ctrl) => Container(
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
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Row(
                children: [
                  const Icon(Icons.compare_arrows_rounded, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Compare Foods',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: cs.border),
            // Scrollable content
            Expanded(
              child: ListView(
                controller: ctrl,
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                children: [
                  // ── Food name headers ──────────────────────────────────
                  _FoodHeaderRow(foods: foods, cs: cs),
                  const SizedBox(height: 20),
                  // ── Per-100g note ──────────────────────────────────────
                  Text(
                    'Values shown per 100 g / 1 serving',
                    style: TextStyle(fontSize: 11, color: cs.textMuted),
                  ),
                  const SizedBox(height: 16),
                  // ── Macro sections ─────────────────────────────────────
                  _MacroSection(
                    label: 'Calories',
                    unit: 'kcal',
                    values: foods.map((f) => f.kcal).toList(),
                    color: cs.kcalColor,
                    cs: cs,
                  ),
                  const SizedBox(height: 20),
                  _MacroSection(
                    label: 'Protein',
                    unit: 'g',
                    values: foods.map((f) => f.protein).toList(),
                    color: AppColors.protein,
                    cs: cs,
                  ),
                  const SizedBox(height: 20),
                  _MacroSection(
                    label: 'Carbs',
                    unit: 'g',
                    values: foods.map((f) => f.carbs).toList(),
                    color: AppColors.carbs,
                    cs: cs,
                  ),
                  const SizedBox(height: 20),
                  _MacroSection(
                    label: 'Fat',
                    unit: 'g',
                    values: foods.map((f) => f.fat).toList(),
                    color: AppColors.fat,
                    cs: cs,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Food name header row ──────────────────────────────────────────────────────

class _FoodHeaderRow extends StatelessWidget {
  const _FoodHeaderRow({required this.foods, required this.cs});
  final List<Food> foods;
  final AppColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(width: 72), // label column spacer
        ...foods.asMap().entries.map((entry) {
          final color = compareColors[entry.key];
          final food = entry.value;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                      border:
                          Border.all(color: color.withValues(alpha: 0.6), width: 1.5),
                    ),
                    child: Center(
                      child: Text(
                        '${entry.key + 1}',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: color),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    food.name,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (food.brand != null && food.brand!.isNotEmpty)
                    Text(
                      food.brand!,
                      style: TextStyle(fontSize: 10, color: cs.textMuted),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

// ── Single macro section (label + bars per food) ──────────────────────────────

class _MacroSection extends StatelessWidget {
  const _MacroSection({
    required this.label,
    required this.unit,
    required this.values,
    required this.color,
    required this.cs,
  });
  final String label, unit;
  final List<double> values;
  final Color color;
  final AppColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final maxVal = values.isEmpty ? 1.0 : values.reduce(max);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: cs.textMuted,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Left spacer (aligns with header column spacer)
            const SizedBox(width: 72),
            ...values.asMap().entries.map((entry) {
              final slotColor = compareColors[entry.key];
              final val = entry.value;
              final pct = maxVal > 0 ? (val / maxVal).clamp(0.0, 1.0) : 0.0;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Bar (full width of cell = 100%)
                      LayoutBuilder(builder: (ctx, box) {
                        return Stack(
                          children: [
                            Container(
                              height: 10,
                              decoration: BoxDecoration(
                                color: cs.border,
                                borderRadius: BorderRadius.circular(5),
                              ),
                            ),
                            Container(
                              height: 10,
                              width: box.maxWidth * pct,
                              decoration: BoxDecoration(
                                color: slotColor,
                                borderRadius: BorderRadius.circular(5),
                              ),
                            ),
                          ],
                        );
                      }),
                      const SizedBox(height: 5),
                      // Value
                      Text(
                        '${val.round()} $unit',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: val == maxVal && maxVal > 0
                              ? color
                              : cs.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ],
    );
  }
}
