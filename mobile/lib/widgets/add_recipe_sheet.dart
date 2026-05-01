import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/recipe_utils.dart';
import '../models/food.dart';
import '../providers/foods_provider.dart';
import '../theme.dart';

// ---------------------------------------------------------------------------
// Public entry point
// ---------------------------------------------------------------------------
class AddRecipeForm extends ConsumerStatefulWidget {
  const AddRecipeForm({super.key, required this.onSaved, this.existing});
  final void Function(Food food) onSaved;
  final Food? existing;

  @override
  ConsumerState<AddRecipeForm> createState() => _AddRecipeFormState();
}

// ---------------------------------------------------------------------------
// Internal ingredient row — holds selected food + qty controller.
// ---------------------------------------------------------------------------
class _IngRow {
  Food? food;
  final TextEditingController qtyCtrl = TextEditingController();

  // For perServing foods the user enters servings; convert to grams so
  // computeRecipeTotals always receives grams.
  double get grams {
    final qty = double.tryParse(qtyCtrl.text) ?? 0;
    if (food?.unit == 'perServing') {
      return qty * (food?.servingSize ?? 1.0);
    }
    return qty;
  }

  void dispose() => qtyCtrl.dispose();
}

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------
class _AddRecipeFormState extends ConsumerState<AddRecipeForm> {
  final _nameCtrl         = TextEditingController();
  final _sizeCtrl         = TextEditingController();   // total size (g) — per100g only
  final _instructionsCtrl = TextEditingController();
  String _unit            = 'perServing';
  bool   _saving          = false;
  final  _rows            = <_IngRow>[_IngRow()];      // at least one row

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing == null) return;
    _nameCtrl.text = existing.name;
    _unit = existing.unit;
    if (existing.unit == 'per100g' && existing.servingSize != null) {
      _sizeCtrl.text = existing.servingSize!.toString();
    }
    if (existing.instructions != null) {
      _instructionsCtrl.text = existing.instructions!;
    }
    if (existing.components.isNotEmpty) {
      final foods = ref.read(foodListProvider);
      for (final r in _rows) r.dispose();
      _rows.clear();
      for (final ing in existing.components) {
        final row = _IngRow();
        final food = foods.where((f) => f.id == ing.foodId).firstOrNull;
        row.food = food;
        if (food != null && food.unit == 'perServing') {
          final servingSize = food.servingSize ?? 1.0;
          final servings = ing.quantity / servingSize;
          row.qtyCtrl.text = servings == servings.roundToDouble()
              ? servings.toInt().toString()
              : servings.toStringAsFixed(1);
        } else {
          row.qtyCtrl.text = ing.quantity == ing.quantity.roundToDouble()
              ? ing.quantity.toInt().toString()
              : ing.quantity.toStringAsFixed(1);
        }
        _rows.add(row);
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _sizeCtrl.dispose();
    _instructionsCtrl.dispose();
    for (final r in _rows) r.dispose();
    super.dispose();
  }

  // ── Derived macros ──────────────────────────────────────────────────────────
  MacroValues get _preview {
    final foods = ref.read(foodListProvider);
    return computeRecipeTotals(
      ingredients: _rows
          .where((r) => r.food != null && r.grams > 0)
          .map((r) => (foodId: r.food!.id, grams: r.grams))
          .toList(),
      foods: foods,
      unit: _unit,
      totalSize: double.tryParse(_sizeCtrl.text),
    );
  }

  // ── Validation ──────────────────────────────────────────────────────────────
  String? get _validationError {
    if (_nameCtrl.text.trim().isEmpty) return 'Recipe name is required.';
    final hasIngredient = _rows.any((r) => r.food != null && r.grams > 0);
    if (!hasIngredient) return 'Add at least one ingredient with a quantity.';
    if (_unit == 'per100g') {
      final size = double.tryParse(_sizeCtrl.text) ?? 0;
      if (size <= 0) return 'Total size (g) is required for a per-100g recipe.';
    }
    return null;
  }

  // ── Save ────────────────────────────────────────────────────────────────────
  Future<void> _save() async {
    final err = _validationError;
    if (err != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    setState(() => _saving = true);

    final macros = _preview;
    final components = _rows
        .where((r) => r.food != null && r.grams > 0)
        .map((r) => Ingredient(foodId: r.food!.id, quantity: r.grams).toJson())
        .toList();

    final instructions = _instructionsCtrl.text.trim();
    final data = {
      'name':         _nameCtrl.text.trim(),
      'unit':         _unit,
      'serving_size': _unit == 'per100g'
          ? double.tryParse(_sizeCtrl.text)
          : null,
      'kcal':         double.parse(macros.kcal.toStringAsFixed(1)),
      'protein':      double.parse(macros.protein.toStringAsFixed(2)),
      'carbs':        double.parse(macros.carbs.toStringAsFixed(2)),
      'fat':          double.parse(macros.fat.toStringAsFixed(2)),
      'category':     'homeRecipe',
      'components':   components,
      if (instructions.isNotEmpty) 'instructions': instructions,
    };

    if (_isEdit) {
      final ok = await ref.read(foodsProvider.notifier).updateFood(
          widget.existing!.id, data);
      if (!mounted) return;
      setState(() => _saving = false);
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save recipe')),
        );
        return;
      }
      final updated = ref.read(foodListProvider)
          .where((f) => f.id == widget.existing!.id)
          .firstOrNull;
      if (updated != null) widget.onSaved(updated);
    } else {
      final newFood = await ref.read(foodsProvider.notifier).addFood(data);
      if (!mounted) return;
      setState(() => _saving = false);
      if (newFood == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save recipe')),
        );
      } else {
        widget.onSaved(newFood);
      }
    }
  }

  // ── Ingredient food picker ──────────────────────────────────────────────────
  Future<void> _pickFood(int rowIndex) async {
    final picked = await showModalBottomSheet<Food>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColorScheme.of(context).card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => ProviderScope(
        parent: ProviderScope.containerOf(context),
        child: const _FoodPickerSheet(),
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        final row = _rows[rowIndex];
        row.food = picked;
        if (row.qtyCtrl.text.isEmpty || row.qtyCtrl.text == '0') {
          row.qtyCtrl.text = picked.unit == 'perServing' ? '1' : '100';
        }
      });
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final cs = AppColorScheme.of(context);
    final preview = _preview;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Name
        TextField(
          controller: _nameCtrl,
          decoration: const InputDecoration(labelText: 'Recipe name *'),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 14),

        // Unit
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'perServing', label: Text('Per serving')),
            ButtonSegment(value: 'per100g',    label: Text('Per 100 g')),
          ],
          selected: {_unit},
          onSelectionChanged: (v) => setState(() => _unit = v.first),
        ),

        // Total size — only for per100g
        if (_unit == 'per100g') ...[
          const SizedBox(height: 12),
          TextField(
            controller: _sizeCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Total recipe size (g) *',
              helperText: 'Weight of the finished batch',
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],

        const SizedBox(height: 20),

        // Ingredients header
        Row(
          children: [
            Text('INGREDIENTS',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: cs.textMuted,
                    letterSpacing: 0.8)),
            const Spacer(),
            TextButton.icon(
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add', style: TextStyle(fontSize: 13)),
              onPressed: () => setState(() => _rows.add(_IngRow())),
            ),
          ],
        ),
        const SizedBox(height: 6),

        // Ingredient rows
        ..._rows.asMap().entries.map((e) {
          final i   = e.key;
          final row = e.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                // Food selector
                Expanded(
                  flex: 5,
                  child: GestureDetector(
                    onTap: () => _pickFood(i),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 13),
                      decoration: BoxDecoration(
                        border: Border.all(color: cs.border),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(children: [
                        Expanded(
                          child: Text(
                            row.food?.displayName ?? 'Select food…',
                            style: TextStyle(
                                fontSize: 13,
                                color: row.food != null
                                    ? cs.textPrimary
                                    : cs.textMuted),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Icon(Icons.search, size: 16, color: cs.textMuted),
                      ]),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Qty (grams)
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: row.qtyCtrl,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      labelText: row.food?.unit == 'perServing' ? 'serving' : 'g',
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 12),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                // Remove
                if (_rows.length > 1)
                  IconButton(
                    icon: Icon(Icons.close, size: 18, color: cs.textMuted),
                    onPressed: () {
                      _rows[i].dispose();
                      setState(() => _rows.removeAt(i));
                    },
                  )
                else
                  const SizedBox(width: 40),
              ],
            ),
          );
        }),

        const SizedBox(height: 20),

        // Instructions (optional)
        Text('INSTRUCTIONS (OPTIONAL)',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: cs.textMuted,
                letterSpacing: 0.8)),
        const SizedBox(height: 8),
        TextField(
          controller: _instructionsCtrl,
          maxLines: 5,
          minLines: 3,
          decoration: const InputDecoration(
            hintText: 'E.g. Mix all ingredients, cook on medium heat for 20 min…',
            alignLabelWithHint: true,
          ),
        ),

        const SizedBox(height: 16),
        Divider(color: cs.border),
        const SizedBox(height: 12),

        // Computed macro preview
        _MacroPreview(macros: preview, unit: _unit),

        const SizedBox(height: 20),

        // Save
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 20, width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Text(_isEdit ? 'Save Changes' : 'Save Recipe'),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Macro preview strip (read-only)
// ---------------------------------------------------------------------------
class _MacroPreview extends StatelessWidget {
  const _MacroPreview({required this.macros, required this.unit});
  final MacroValues macros;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final cs = AppColorScheme.of(context);
    final label = unit == 'per100g' ? 'per 100 g' : 'per serving';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Computed macros — $label',
            style: TextStyle(
                fontSize: 11,
                color: cs.textMuted,
                fontStyle: FontStyle.italic)),
        const SizedBox(height: 8),
        Row(children: [
          _M('Kcal', macros.kcal, 'kcal', AppColorScheme.of(context).kcalColor),
          const SizedBox(width: 10),
          _M('Protein', macros.protein, 'g', AppColors.protein),
          const SizedBox(width: 10),
          _M('Carbs', macros.carbs, 'g', AppColors.carbs),
          const SizedBox(width: 10),
          _M('Fat', macros.fat, 'g', AppColors.fat),
        ]),
      ],
    );
  }

  Widget _M(String label, double val, String unit, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(fontSize: 9, color: color.withValues(alpha: 0.8))),
            const SizedBox(height: 2),
            Text(
              val >= 10 ? val.round().toString() : val.toStringAsFixed(1),
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: color),
            ),
            Text(unit,
                style: TextStyle(fontSize: 9, color: color.withValues(alpha: 0.7))),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Food picker sheet — reuses the same search pattern as add_entry_sheet
// ---------------------------------------------------------------------------
class _FoodPickerSheet extends ConsumerStatefulWidget {
  const _FoodPickerSheet();

  @override
  ConsumerState<_FoodPickerSheet> createState() => _FoodPickerSheetState();
}

class _FoodPickerSheetState extends ConsumerState<_FoodPickerSheet> {
  final _searchCtrl = TextEditingController();
  String _search = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = AppColorScheme.of(context);
    final allFoods = ref.watch(foodListProvider);
    final q = _search.toLowerCase();
    final filtered = q.isEmpty
        ? allFoods
        : allFoods
            .where((f) =>
                f.name.toLowerCase().contains(q) ||
                (f.brand?.toLowerCase().contains(q) ?? false))
            .toList();

    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (ctx, scrollCtrl) => Column(
          children: [
            // Handle
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: cs.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search foods…',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onChanged: (v) => setState(() => _search = v),
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text('No foods found',
                          style: TextStyle(color: cs.textMuted)))
                  : ListView.separated(
                      controller: scrollCtrl,
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) =>
                          Divider(height: 1, color: cs.border),
                      itemBuilder: (_, i) {
                        final f = filtered[i];
                        return ListTile(
                          title: Text(f.displayName,
                              style: const TextStyle(fontSize: 13)),
                          subtitle: Text(
                            f.unit == 'per100g'
                                ? '${f.kcal.round()} kcal · ${f.protein.round()}g P  /100g'
                                : '${f.kcal.round()} kcal · ${f.protein.round()}g P  /serving',
                            style: TextStyle(
                                fontSize: 11, color: cs.textMuted),
                          ),
                          trailing: f.isRecipe
                              ? Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.carbs
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text('Recipe',
                                      style: TextStyle(
                                          fontSize: 9,
                                          color: AppColors.carbs)),
                                )
                              : null,
                          onTap: () => Navigator.of(context).pop(f),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
