import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/entry.dart';
import '../models/food.dart';
import '../providers/entries_provider.dart';
import '../providers/foods_provider.dart';
import '../theme.dart';

/// Returns the most appropriate meal based on current time of day.
String _suggestMeal() {
  final h = DateTime.now().hour;
  if (h < 10) return 'breakfast';
  if (h < 13) return 'lunch';
  if (h < 17) return 'snack';
  if (h < 21) return 'dinner';
  return 'snack';
}

void showAddEntrySheet(BuildContext context, WidgetRef ref, String date) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => ProviderScope(
      parent: ProviderScope.containerOf(context),
      child: _AddEntrySheet(date: date),
    ),
  );
}

class _AddEntrySheet extends ConsumerStatefulWidget {
  const _AddEntrySheet({required this.date});
  final String date;

  @override
  ConsumerState<_AddEntrySheet> createState() => _AddEntrySheetState();
}

class _AddEntrySheetState extends ConsumerState<_AddEntrySheet> {
  Food? _selectedFood;
  String _meal = _suggestMeal();
  final _qtyCtrl = TextEditingController(text: '100');
  final _searchCtrl = TextEditingController();
  String _search = '';
  bool _saving = false;

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  MacroValues get _preview {
    if (_selectedFood == null) return const MacroValues();
    final qty = double.tryParse(_qtyCtrl.text) ?? 0;
    return _selectedFood!.scaledMacros(qty);
  }

  Future<void> _save() async {
    if (_selectedFood == null) return;
    final qty = double.tryParse(_qtyCtrl.text) ?? 0;
    if (qty <= 0) return;

    setState(() => _saving = true);
    final ok = await ref.read(entriesProvider(widget.date).notifier).addEntry(
      foodId: _selectedFood!.id,
      qty: qty,
      meal: _meal,
    );
    if (mounted) {
      Navigator.pop(context);
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to add entry')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final foods = ref.watch(foodListProvider);
    final filtered = _search.isEmpty
        ? foods
        : foods.where((f) =>
            f.name.toLowerCase().contains(_search.toLowerCase()) ||
            (f.brand?.toLowerCase().contains(_search.toLowerCase()) ?? false)).toList();
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Add Food',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),

          // Food search / selection
          if (_selectedFood == null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search foods…',
                  prefixIcon: Icon(Icons.search, size: 18),
                ),
                onChanged: (v) => setState(() => _search = v),
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 260),
              child: filtered.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(
                        child: Text('No foods found',
                            style: TextStyle(color: AppColors.textMuted)),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, indent: 16),
                      itemBuilder: (ctx, i) {
                        final f = filtered[i];
                        return ListTile(
                          dense: true,
                          title: Text(f.displayName, style: const TextStyle(fontSize: 14)),
                          subtitle: Text(
                            '${f.kcal.round()} kcal · P ${f.protein.round()}g',
                            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                          ),
                          onTap: () {
                            setState(() {
                              _selectedFood = f;
                              // Default qty: 100 for per100g, 1 for perServing
                              _qtyCtrl.text = f.unit == 'per100g' ? '100' : '1';
                            });
                          },
                        );
                      },
                    ),
            ),
          ] else ...[
            // Selected food details + qty
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _selectedFood!.displayName,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => setState(() => _selectedFood = null),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 120,
                    child: TextField(
                      controller: _qtyCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: _selectedFood!.unit == 'per100g' ? 'Grams' : 'Servings',
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
                        child: Text(mealLabels[m] ?? m, style: const TextStyle(fontSize: 14)),
                      )).toList(),
                      onChanged: (v) => setState(() => _meal = v!),
                    ),
                  ),
                ],
              ),
            ),
            // Macro preview
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.bg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _PreviewMacro('Kcal', _preview.kcal, AppColors.kcal),
                    _PreviewMacro('Protein', _preview.protein, AppColors.protein),
                    _PreviewMacro('Carbs', _preview.carbs, AppColors.carbs),
                    _PreviewMacro('Fat', _preview.fat, AppColors.fat),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(height: 20, width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Add to Log'),
              ),
            ),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _PreviewMacro extends StatelessWidget {
  const _PreviewMacro(this.label, this.value, this.color);
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
