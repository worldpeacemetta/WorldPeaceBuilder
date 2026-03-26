import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils.dart';
import '../../models/entry.dart';
import '../../models/food.dart';
import '../../providers/date_provider.dart';
import '../../providers/entries_provider.dart';
import '../../providers/settings_provider.dart';
import '../../theme.dart';
import '../../widgets/add_entry_sheet.dart';
import '../../widgets/macro_summary_bar.dart';

class DailyLogScreen extends ConsumerWidget {
  const DailyLogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logDate = ref.watch(logDateProvider);
    final entriesAsync = ref.watch(logEntriesProvider);
    final byMeal = ref.watch(logEntriesByMealProvider);
    final totals = ref.watch(macroTotalsProvider(logDate));
    final goals = ref.watch(settingsProvider).activeGoals;
    final isToday = logDate == todayISO();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Daily Log'),
            Text(
              formatDateFull(logDate),
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w400),
            ),
          ],
        ),
        actions: [
          // Date prev
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () {
              final dt = DateTime.parse(logDate).subtract(const Duration(days: 1));
              ref.read(logDateProvider.notifier).state =
                  '${dt.year.toString().padLeft(4,'0')}-${dt.month.toString().padLeft(2,'0')}-${dt.day.toString().padLeft(2,'0')}';
            },
          ),
          // Today button
          if (!isToday)
            TextButton(
              onPressed: () => setAllDates(ref, todayISO()),
              child: const Text('Today', style: TextStyle(fontSize: 12)),
            ),
          // Date next (no future)
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: logDate == todayISO()
                ? null
                : () {
                    final dt = DateTime.parse(logDate).add(const Duration(days: 1));
                    ref.read(logDateProvider.notifier).state =
                        '${dt.year.toString().padLeft(4,'0')}-${dt.month.toString().padLeft(2,'0')}-${dt.day.toString().padLeft(2,'0')}';
                  },
          ),
        ],
      ),
      body: Column(
        children: [
          // Macro summary bar
          MacroSummaryBar(totals: totals, goals: goals),

          // Entries list
          Expanded(
            child: entriesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text('Error: $e', style: const TextStyle(color: AppColors.danger)),
              ),
              data: (_) {
                if (byMeal.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.restaurant_outlined, size: 48, color: AppColors.textMuted),
                        const SizedBox(height: 12),
                        const Text('No food logged yet',
                            style: TextStyle(color: AppColors.textMuted, fontSize: 15)),
                        const SizedBox(height: 6),
                        Text(
                          isToday ? 'Tap + to add your first meal' : 'Nothing logged on this day',
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 88),
                  itemCount: mealOrder.where(byMeal.containsKey).length,
                  itemBuilder: (ctx, i) {
                    final meal = mealOrder.where(byMeal.containsKey).elementAt(i);
                    final items = byMeal[meal]!;
                    return _MealSection(meal: meal, entries: items, date: logDate);
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showAddEntrySheet(context, ref, logDate),
        icon: const Icon(Icons.add),
        label: const Text('Add Food'),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Meal section with header + entry tiles
// ---------------------------------------------------------------------------
class _MealSection extends ConsumerWidget {
  const _MealSection({
    required this.meal,
    required this.entries,
    required this.date,
  });

  final String meal;
  final List<Entry> entries;
  final String date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mealTotals = entries.fold<MacroValues>(
      const MacroValues(),
      (acc, e) => acc + e.macros,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Meal header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
          child: Row(
            children: [
              Text(
                mealLabels[meal] ?? meal,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: AppColors.textMuted,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              Text(
                '${mealTotals.kcal.round()} kcal',
                style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
        // Entry tiles
        ...entries.map((entry) => _EntryTile(entry: entry, date: date)),
        const Divider(height: 1),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Single entry tile with swipe-to-delete
// ---------------------------------------------------------------------------
class _EntryTile extends ConsumerWidget {
  const _EntryTile({required this.entry, required this.date});
  final Entry entry;
  final String date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final macros = entry.macros;
    final food = entry.food;

    return Dismissible(
      key: Key(entry.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: AppColors.danger.withValues(alpha: 0.15),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline, color: AppColors.danger),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete entry?'),
            content: Text('Remove ${food?.name ?? 'this entry'} from log?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Delete', style: TextStyle(color: AppColors.danger)),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) {
        ref.read(entriesProvider(date).notifier).deleteEntry(entry.id);
      },
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: Text(
          food?.displayName ?? entry.foodId,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${entry.qty.toStringAsFixed(food?.unit == 'per100g' ? 0 : 1)} '
          '${food?.unit == 'per100g' ? 'g' : 'srv'}'
          '  ·  P ${macros.protein.round()}g  C ${macros.carbs.round()}g  F ${macros.fat.round()}g',
          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
        ),
        trailing: Text(
          '${macros.kcal.round()}\nkcal',
          textAlign: TextAlign.right,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.kcal,
            height: 1.3,
          ),
        ),
      ),
    );
  }
}
