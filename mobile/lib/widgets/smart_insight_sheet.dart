import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils.dart';
import '../models/entry.dart';
import '../models/food.dart';
import '../providers/date_provider.dart';
import '../providers/entries_provider.dart';
import '../providers/smart_insight_provider.dart';
import '../theme.dart';

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------

void showSmartInsightSheet(BuildContext context, WidgetRef ref) {
  final container = ProviderScope.containerOf(context);
  final cardColor  = Theme.of(context).extension<AppColorScheme>()!.card;
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: cardColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => ProviderScope(
      parent: container,
      child: const _SmartInsightSheet(),
    ),
  );
}

// ---------------------------------------------------------------------------
// Meal meta helpers
// ---------------------------------------------------------------------------

Color _mealColor(String meal) => switch (meal) {
  'breakfast' => AppColors.kcal,    // lavender
  'lunch'     => AppColors.carbs,   // rose
  'dinner'    => AppColors.protein, // teal mist
  'snack'     => AppColors.fat,     // peach
  _           => AppColors.textMuted,
};

IconData _mealIcon(String meal) => switch (meal) {
  'breakfast' => Icons.wb_sunny_rounded,
  'lunch'     => Icons.lunch_dining,
  'dinner'    => Icons.dinner_dining,
  'snack'     => Icons.local_cafe_rounded,
  _           => Icons.restaurant_rounded,
};

String _mealTagline(String meal) => switch (meal) {
  'breakfast' => 'Start your day right',
  'lunch'     => 'Fuel your afternoon',
  'dinner'    => 'Nourish your evening',
  'snack'     => 'Smart bites anytime',
  _           => '',
};

String _qtyLabel(String unit, double qty) {
  if (unit == 'perServing') {
    final n = qty.round();
    return '$n serving${n == 1 ? '' : 's'}';
  }
  return '${qty.round()}g';
}

// ---------------------------------------------------------------------------
// Main sheet
// ---------------------------------------------------------------------------

class _SmartInsightSheet extends ConsumerWidget {
  const _SmartInsightSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs           = AppColorScheme.of(context);
    final insightAsync = ref.watch(smartInsightProvider);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.65,
      maxChildSize: 0.92,
      builder: (ctx, scrollCtrl) => Column(
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: cs.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Smart Insight',
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    if (insightAsync.valueOrNull?.loggedDays != null &&
                        insightAsync.valueOrNull!.loggedDays > 0)
                      Text(
                        'Based on ${insightAsync.value!.loggedDays} days of history',
                        style: TextStyle(fontSize: 12, color: cs.textMuted),
                      ),
                  ],
                ),
                const Spacer(),
                TextButton(
                  onPressed: Navigator.of(context).pop,
                  child: const Text('Done'),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: cs.border),
          // Content
          Expanded(
            child: insightAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              error: (_, __) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    'Unable to load insights',
                    style: TextStyle(color: cs.textMuted),
                  ),
                ),
              ),
              data: (result) {
                final cards = kSmartInsightMealSlots
                    .where((m) => result.suggestions[m] != null)
                    .map((m) => result.suggestions[m]!)
                    .toList();

                if (!result.available || cards.isEmpty) {
                  return _EmptyState(loggedDays: result.loggedDays);
                }

                return ListView.separated(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  itemCount: cards.length + 1, // +1 for info row
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (ctx, i) {
                    if (i == cards.length) return const _InfoRow();
                    final insight = cards[i];
                    return _MealCard(
                      insight: insight,
                      onTap: () => _showMealDetailSheet(context, ref, insight),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Meal card
// ---------------------------------------------------------------------------

class _MealCard extends StatelessWidget {
  const _MealCard({required this.insight, required this.onTap});
  final MealInsight insight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs    = AppColorScheme.of(context);
    final color = _mealColor(insight.meal);
    final m     = insight.totalMacros;

    // Food preview — first 3 food names
    final names    = insight.items.take(3).map((i) => i.food.name).join(', ');
    final overflow = insight.items.length > 3
        ? ' +${insight.items.length - 3} more'
        : '';
    final preview = names + overflow;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: cs.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.35), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Main content row
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon box
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(_mealIcon(insight.meal), color: color, size: 24),
                  ),
                  const SizedBox(width: 12),
                  // Text column
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          mealLabels[insight.meal] ?? insight.meal,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: cs.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _mealTagline(insight.meal),
                          style: TextStyle(fontSize: 12, color: cs.textMuted),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          preview,
                          style: TextStyle(fontSize: 12, color: cs.textMuted),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded,
                      color: color.withValues(alpha: 0.7), size: 20),
                ],
              ),
            ),
            // Macro strip
            Container(
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(15)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                children: [
                  _MacroPill('P', '${m.protein.round()}g', AppColors.protein),
                  const SizedBox(width: 10),
                  _MacroPill('C', '${m.carbs.round()}g', AppColors.carbs),
                  const SizedBox(width: 10),
                  _MacroPill('F', '${m.fat.round()}g', AppColors.fat),
                  const Spacer(),
                  Text(
                    '${m.kcal.round()} kcal',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColorScheme.of(context).kcalColor,
                    ),
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

class _MacroPill extends StatelessWidget {
  const _MacroPill(this.label, this.value, this.color);
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
        const SizedBox(width: 3),
        Text(value,
            style: TextStyle(
                fontSize: 12, color: AppColorScheme.of(context).textPrimary,
                fontWeight: FontWeight.w500)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.loggedDays});
  final int loggedDays;

  @override
  Widget build(BuildContext context) {
    final cs = AppColorScheme.of(context);
    final remaining = (14 - loggedDays).clamp(0, 14);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome_rounded, size: 48,
                color: AppColors.kcal.withValues(alpha: 0.6)),
            const SizedBox(height: 16),
            Text(
              loggedDays < 14
                  ? 'Almost there'
                  : 'All meals logged today',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: cs.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              loggedDays < 14
                  ? 'Log $remaining more day${remaining == 1 ? '' : 's'} to unlock Smart Insight'
                  : 'Come back tomorrow for your next suggestions',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: cs.textMuted, height: 1.4),
            ),
            if (loggedDays < 14) ...[
              const SizedBox(height: 20),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: loggedDays / 14,
                  minHeight: 6,
                  backgroundColor: cs.border,
                  color: AppColors.kcal,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '$loggedDays / 14 days',
                style: TextStyle(fontSize: 11, color: cs.textMuted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Info row (tutorial placeholder)
// ---------------------------------------------------------------------------

class _InfoRow extends StatelessWidget {
  const _InfoRow();

  @override
  Widget build(BuildContext context) {
    final cs = AppColorScheme.of(context);
    return GestureDetector(
      onTap: () => showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('What is Smart Insight?'),
          content: const Text(
            'Smart Insight analyses your past meals and suggests the best '
            'food combinations to close your remaining macro targets for today. '
            'It learns from your actual eating habits — the more you log, '
            'the smarter it gets.',
          ),
          actions: [
            TextButton(
              onPressed: Navigator.of(context).pop,
              child: const Text('Got it'),
            ),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.info_outline_rounded, size: 14, color: cs.textMuted),
            const SizedBox(width: 6),
            Text(
              'What is Smart Insight?',
              style: TextStyle(fontSize: 12, color: cs.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Meal detail sheet
// ---------------------------------------------------------------------------

void _showMealDetailSheet(
  BuildContext context,
  WidgetRef ref,
  MealInsight insight,
) {
  final container = ProviderScope.containerOf(context);
  final cardColor  = Theme.of(context).extension<AppColorScheme>()!.card;
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: cardColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => ProviderScope(
      parent: container,
      child: _MealDetailSheet(insight: insight, parentContext: context),
    ),
  );
}

class _MealDetailSheet extends ConsumerStatefulWidget {
  const _MealDetailSheet({
    required this.insight,
    required this.parentContext,
  });
  final MealInsight insight;
  final BuildContext parentContext;

  @override
  ConsumerState<_MealDetailSheet> createState() => _MealDetailSheetState();
}

class _MealDetailSheetState extends ConsumerState<_MealDetailSheet> {
  bool _logging = false;

  Future<void> _logAll() async {
    setState(() => _logging = true);
    final today    = todayISO();
    final notifier = ref.read(entriesProvider(today).notifier);
    bool allOk = true;

    for (final item in widget.insight.items) {
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
        messenger.showSnackBar(
          const SnackBar(content: Text('Some items failed to log')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs    = AppColorScheme.of(context);
    final color = _mealColor(widget.insight.meal);
    final m     = widget.insight.totalMacros;

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
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: cs.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
            child: Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(_mealIcon(widget.insight.meal), color: color, size: 18),
                ),
                const SizedBox(width: 10),
                Text(
                  mealLabels[widget.insight.meal] ?? widget.insight.meal,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                TextButton(
                  onPressed: Navigator.of(context).pop,
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: cs.border),
          // Food list
          Expanded(
            child: ListView.separated(
              controller: scrollCtrl,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              itemCount: widget.insight.items.length + 1, // +1 for macro summary
              separatorBuilder: (_, i) =>
                  i < widget.insight.items.length - 1
                      ? Divider(height: 24, color: cs.border)
                      : const SizedBox(height: 16),
              itemBuilder: (ctx, i) {
                if (i == widget.insight.items.length) {
                  return _MacroSummaryRow(macros: m, color: color);
                }
                final item = widget.insight.items[i];
                final im   = item.macros;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.food.name,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: cs.textPrimary,
                            ),
                          ),
                          if (item.food.brand != null)
                            Text(
                              item.food.brand!,
                              style: TextStyle(fontSize: 12, color: cs.textMuted),
                            ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              _SmallMacroPill(
                                  'P ${im.protein.round()}g', AppColors.protein),
                              const SizedBox(width: 6),
                              _SmallMacroPill(
                                  'C ${im.carbs.round()}g', AppColors.carbs),
                              const SizedBox(width: 6),
                              _SmallMacroPill(
                                  'F ${im.fat.round()}g', AppColors.fat),
                            ],
                          ),
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
                            color: cs.textPrimary,
                          ),
                        ),
                        Text(
                          '${im.kcal.round()} kcal',
                          style: TextStyle(fontSize: 12, color: cs.kcalColor),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
          // Log button
          Padding(
            padding: EdgeInsets.fromLTRB(
                16, 8, 16, MediaQuery.of(context).padding.bottom + 16),
            child: ElevatedButton(
              onPressed: _logging ? null : _logAll,
              child: _logging
                  ? const SizedBox(
                      height: 20, width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(
                      'Log ${mealLabels[widget.insight.meal] ?? widget.insight.meal}'),
            ),
          ),
        ],
      ),
    );
  }
}

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
          _SummaryMacro('Protein', '${macros.protein.round()}g', AppColors.protein),
          _SummaryMacro('Carbs',   '${macros.carbs.round()}g',   AppColors.carbs),
          _SummaryMacro('Fat',     '${macros.fat.round()}g',     AppColors.fat),
          _SummaryMacro('Calories','${macros.kcal.round()}',     cs.kcalColor),
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
  Widget build(BuildContext context) {
    final cs = AppColorScheme.of(context);
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w700, color: color)),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(fontSize: 10, color: cs.textMuted)),
      ],
    );
  }
}

class _SmallMacroPill extends StatelessWidget {
  const _SmallMacroPill(this.text, this.color);
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      );
}
