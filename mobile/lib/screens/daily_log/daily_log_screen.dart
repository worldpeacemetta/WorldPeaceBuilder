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
import '../../widgets/mode_pill.dart';

class DailyLogScreen extends ConsumerWidget {
  const DailyLogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logDate = ref.watch(logDateProvider);
    final entriesAsync = ref.watch(logEntriesProvider);
    final byMeal = ref.watch(logEntriesByMealProvider);
    final totals = ref.watch(macroTotalsProvider(logDate));
    final goals = ref.watch(settingsProvider).goalsForDate(logDate);
    final isToday = logDate == todayISO();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Daily Log'),
            Row(
              children: [
                Text(
                  formatDateFull(logDate),
                  style: const TextStyle(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w400),
                ),
                const SizedBox(width: 8),
                ModePill(date: logDate),
              ],
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
        onTap: () => _showEditEntrySheet(context, ref, entry, date),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Edit entry bottom sheet — change qty and/or meal
// ---------------------------------------------------------------------------
void _showEditEntrySheet(
    BuildContext context, WidgetRef ref, Entry entry, String date) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => ProviderScope(
      parent: ProviderScope.containerOf(context),
      child: _EditEntrySheet(entry: entry, date: date),
    ),
  );
}

class _EditEntrySheet extends ConsumerStatefulWidget {
  const _EditEntrySheet({required this.entry, required this.date});
  final Entry entry;
  final String date;

  @override
  ConsumerState<_EditEntrySheet> createState() => _EditEntrySheetState();
}

class _EditEntrySheetState extends ConsumerState<_EditEntrySheet> {
  late final TextEditingController _qtyCtrl;
  late String _meal;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _qtyCtrl = TextEditingController(
      text: widget.entry.qty.toStringAsFixed(
          widget.entry.food?.unit == 'per100g' ? 0 : 1),
    );
    _meal = widget.entry.meal;
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    super.dispose();
  }

  MacroValues get _preview {
    final food = widget.entry.food;
    if (food == null) return const MacroValues();
    final qty = double.tryParse(_qtyCtrl.text) ?? 0;
    return food.scaledMacros(qty);
  }

  Future<void> _save() async {
    final qty = double.tryParse(_qtyCtrl.text) ?? 0;
    if (qty <= 0) return;
    setState(() => _saving = true);
    final ok = await ref.read(entriesProvider(widget.date).notifier).updateEntry(
      widget.entry.id,
      qty: qty,
      meal: _meal,
    );
    if (mounted) {
      Navigator.pop(context);
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update entry')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final food = widget.entry.food;
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            food?.displayName ?? widget.entry.foodId,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              SizedBox(
                width: 120,
                child: TextField(
                  controller: _qtyCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: food?.unit == 'per100g' ? 'Grams' : 'Servings',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _meal,
                  decoration: const InputDecoration(labelText: 'Meal'),
                  items: mealOrder.map((m) => DropdownMenuItem(
                    value: m,
                    child: Text(mealLabels[m] ?? m,
                        style: const TextStyle(fontSize: 14)),
                  )).toList(),
                  onChanged: (v) => setState(() => _meal = v!),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.bg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _MacroPreview('Kcal', _preview.kcal, AppColors.kcal),
                _MacroPreview('Protein', _preview.protein, AppColors.protein),
                _MacroPreview('Carbs', _preview.carbs, AppColors.carbs),
                _MacroPreview('Fat', _preview.fat, AppColors.fat),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(height: 20, width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save Changes'),
          ),
        ],
      ),
    );
  }
}

class _MacroPreview extends StatelessWidget {
  const _MacroPreview(this.label, this.value, this.color);
  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value.round().toString(),
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: color),
        ),
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
      ],
    );
  }
}
