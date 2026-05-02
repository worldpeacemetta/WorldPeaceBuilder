import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/utils.dart';
import '../../models/entry.dart';
import '../../models/food.dart';
import '../../providers/date_provider.dart';
import '../../providers/entries_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/smart_insight_provider.dart';
import '../../theme.dart';
import 'macro_donut.dart';

// ---------------------------------------------------------------------------
// Meal meta helpers (local copies — kept private, same logic as main sheet)
// ---------------------------------------------------------------------------

Color _mealColor(String meal) => switch (meal) {
      'breakfast' => AppColors.kcal,
      'lunch' => AppColors.carbs,
      'dinner' => AppColors.protein,
      'snack' => AppColors.fat,
      _ => AppColors.textMuted,
    };

IconData _mealIcon(String meal) => switch (meal) {
      'breakfast' => Icons.wb_sunny_rounded,
      'lunch' => Icons.lunch_dining,
      'dinner' => Icons.dinner_dining,
      'snack' => Icons.local_cafe_rounded,
      _ => Icons.restaurant_rounded,
    };

String _qtyLabel(String unit, double qty) {
  if (unit == 'perServing') {
    final n = qty.round();
    return '$n serving${n == 1 ? '' : 's'}';
  }
  return '${qty.round()}g';
}

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------

void showMealDetailSheet(
  BuildContext context,
  WidgetRef ref,
  MealInsight insight,
  int optionNumber,
) {
  final container = ProviderScope.containerOf(context);
  final cardColor = Theme.of(context).extension<AppColorScheme>()!.card;
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: cardColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => ProviderScope(
      parent: container,
      child: _MealDetailSheet(
          insight: insight,
          parentContext: context,
          optionNumber: optionNumber),
    ),
  );
}

// ---------------------------------------------------------------------------
// Detail sheet
// ---------------------------------------------------------------------------

class _MealDetailSheet extends ConsumerStatefulWidget {
  const _MealDetailSheet({
    required this.insight,
    required this.parentContext,
    required this.optionNumber,
  });
  final MealInsight insight;
  final BuildContext parentContext;
  final int optionNumber;

  @override
  ConsumerState<_MealDetailSheet> createState() => _MealDetailSheetState();
}

class _MealDetailSheetState extends ConsumerState<_MealDetailSheet> {
  bool _logging = false;
  late Set<int> _selectedIndices;

  @override
  void initState() {
    super.initState();
    _selectedIndices =
        Set<int>.from(Iterable.generate(widget.insight.items.length));
  }

  MacroValues get _selectedMacros => MacroValues.sum(
      _selectedIndices.map((i) => widget.insight.items[i].macros));

  Future<void> _logAll() async {
    setState(() => _logging = true);
    final today = todayISO();
    final notifier = ref.read(entriesProvider(today).notifier);
    bool allOk = true;
    final indices = _selectedIndices.toList()..sort();
    for (final i in indices) {
      final item = widget.insight.items[i];
      final ok = await notifier.addEntry(
        foodId: item.food.id,
        qty: item.qty,
        meal: widget.insight.meal,
      );
      if (!ok) allOk = false;
    }
    if (mounted) {
      final messenger = ScaffoldMessenger.of(widget.parentContext);
      setAllDates(ref, today);
      Navigator.pop(context);
      if (!allOk) {
        messenger
            .showSnackBar(const SnackBar(content: Text('Some items failed to log')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = AppColorScheme.of(context);
    final color = _mealColor(widget.insight.meal);
    final n = widget.insight.items.length;
    final sel = _selectedIndices.length;

    final String buttonLabel;
    if (_logging) {
      buttonLabel = '';
    } else if (sel == 0) {
      buttonLabel = 'Select items to log';
    } else if (sel == n) {
      buttonLabel =
          'Log ${mealLabels[widget.insight.meal] ?? widget.insight.meal}';
    } else {
      buttonLabel = 'Log $sel item${sel == 1 ? '' : 's'}';
    }

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.92,
      builder: (ctx, scrollCtrl) => Column(
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: cs.border, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(_mealIcon(widget.insight.meal),
                      color: color, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        mealLabels[widget.insight.meal] ?? widget.insight.meal,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Option ${widget.optionNumber}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: color,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: Navigator.of(context).pop,
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: cs.border),
          // Food items, macro impact, and preference buttons all scroll together
          Expanded(
            child: CustomScrollView(
              controller: scrollCtrl,
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) {
                        if (i.isOdd) return Divider(height: 24, color: cs.border);
                        final idx = i ~/ 2;
                        final item = widget.insight.items[idx];
                        final im = item.macros;
                        final selected = _selectedIndices.contains(idx);
                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => setState(() {
                            if (selected) {
                              _selectedIndices.remove(idx);
                            } else {
                              _selectedIndices.add(idx);
                            }
                          }),
                          child: AnimatedOpacity(
                            opacity: selected ? 1.0 : 0.38,
                            duration: const Duration(milliseconds: 180),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(right: 10),
                                  child: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 180),
                                    child: Icon(
                                      selected
                                          ? Icons.check_circle_rounded
                                          : Icons.radio_button_unchecked_rounded,
                                      key: ValueKey(selected),
                                      size: 20,
                                      color: selected ? color : cs.border,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(right: 10),
                                  child: Text(
                                    categoryEmojis[item.food.category] ?? '🍽️',
                                    style: const TextStyle(fontSize: 22),
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(item.food.name,
                                          style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: cs.textPrimary)),
                                      if (item.food.brand != null)
                                        Text(item.food.brand!,
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: cs.textMuted)),
                                      const SizedBox(height: 4),
                                      Row(children: [
                                        _SmallPill('P ${im.protein.round()}g',
                                            AppColors.protein),
                                        const SizedBox(width: 6),
                                        _SmallPill('C ${im.carbs.round()}g',
                                            AppColors.carbs),
                                        const SizedBox(width: 6),
                                        _SmallPill('F ${im.fat.round()}g',
                                            AppColors.fat),
                                      ]),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      _qtyLabel(item.food.unit, item.qty),
                                      style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: cs.textPrimary),
                                    ),
                                    Text('${im.kcal.round()} kcal',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: cs.kcalColor)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      childCount: n > 0 ? n * 2 - 1 : 0,
                    ),
                  ),
                ),
                // Macro impact — driven by selected items only
                SliverToBoxAdapter(
                  child: _DonutImpactSection(suggestion: _selectedMacros),
                ),
                // Suggestion preference buttons
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _logging
                                ? null
                                : () {
                                    ref
                                        .read(settingsProvider.notifier)
                                        .setComboReduced(widget.insight.meal,
                                            widget.insight.comboKey);
                                    Navigator.pop(context);
                                  },
                            icon: const Icon(Icons.trending_down_rounded,
                                size: 14),
                            label: const Text('Suggest less often'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: cs.textMuted,
                              side: BorderSide(color: cs.border),
                              textStyle: const TextStyle(fontSize: 12),
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _logging
                                ? null
                                : () {
                                    ref
                                        .read(settingsProvider.notifier)
                                        .setComboBlocked(widget.insight.meal,
                                            widget.insight.comboKey);
                                    Navigator.pop(context);
                                  },
                            icon: const Icon(Icons.block_rounded, size: 14),
                            label: const Text('Remove from suggestions'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor:
                                  AppColors.danger.withValues(alpha: 0.7),
                              side: BorderSide(
                                  color: AppColors.danger
                                      .withValues(alpha: 0.3)),
                              textStyle: const TextStyle(fontSize: 12),
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Log button — pinned at bottom
          Padding(
            padding: EdgeInsets.fromLTRB(
                16, 8, 16, MediaQuery.of(context).padding.bottom + 16),
            child: ElevatedButton(
              onPressed: (_logging || sel == 0) ? null : _logAll,
              child: _logging
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(buttonLabel),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Macro impact section — donut view, matches carousel card style
// ---------------------------------------------------------------------------

class _DonutImpactSection extends ConsumerWidget {
  const _DonutImpactSection({required this.suggestion});
  final MacroValues suggestion;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = AppColorScheme.of(context);
    final today = todayISO();
    final current = ref.watch(macroTotalsProvider(today));
    final goals = ref.read(settingsProvider).goalsForDate(today);
    final m = suggestion;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(height: 24, color: cs.border),
          Text(
            'Macro impact',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: cs.textMuted,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              MacroDonut(
                label: 'Protein',
                addition: m.protein,
                current: current.protein,
                goal: goals.protein,
                color: AppColors.protein,
                unit: 'g',
                size: 76.0,
              ),
              MacroDonut(
                label: 'Carbs',
                addition: m.carbs,
                current: current.carbs,
                goal: goals.carbs,
                color: AppColors.carbs,
                unit: 'g',
                size: 76.0,
              ),
              MacroDonut(
                label: 'Fat',
                addition: m.fat,
                current: current.fat,
                goal: goals.fat,
                color: AppColors.fat,
                unit: 'g',
                size: 76.0,
              ),
              MacroDonut(
                label: 'Kcal',
                addition: m.kcal,
                current: current.kcal,
                goal: goals.kcal,
                color: AppColorScheme.of(context).kcalColor,
                unit: '',
                size: 76.0,
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Macro summary row
// ---------------------------------------------------------------------------

class _MacroSummaryRow extends StatelessWidget {
  const _MacroSummaryRow({required this.macros, required this.color});
  final MacroValues macros;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final cs = AppColorScheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _SummaryMacro('Protein', '${macros.protein.round()}g',
              AppColors.protein),
          _SummaryMacro('Carbs', '${macros.carbs.round()}g', AppColors.carbs),
          _SummaryMacro('Fat', '${macros.fat.round()}g', AppColors.fat),
          _SummaryMacro('Calories', '${macros.kcal.round()}', cs.kcalColor),
        ],
      ),
    );
  }
}

class _SummaryMacro extends StatelessWidget {
  const _SummaryMacro(this.label, this.value, this.color);
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700, color: color)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  color: AppColorScheme.of(context).textMuted)),
        ],
      );
}

class _SmallPill extends StatelessWidget {
  const _SmallPill(this.text, this.color);
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Text(text,
      style: TextStyle(
          fontSize: 11, color: color, fontWeight: FontWeight.w500));
}
