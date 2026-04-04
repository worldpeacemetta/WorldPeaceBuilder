import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';
import '../models/food.dart';
import '../providers/foods_provider.dart';
import '../theme.dart';
import 'add_entry_sheet.dart';
import 'add_recipe_sheet.dart';
import 'barcode_scanner_sheet.dart';
import 'food_saved_sheet.dart';

void showAddFoodSheet(
  BuildContext context,
  WidgetRef ref, {
  Food? existing,
  Map<String, dynamic>? scannedData,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).extension<AppColorScheme>()!.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => ProviderScope(
      parent: ProviderScope.containerOf(context),
      child: _AddFoodSheet(
        existing: existing,
        scannedData: scannedData,
        parentContext: context,
        parentRef: ref,
      ),
    ),
  );
}

class _AddFoodSheet extends ConsumerStatefulWidget {
  const _AddFoodSheet({
    this.existing,
    this.scannedData,
    required this.parentContext,
    required this.parentRef,
  });
  final Food? existing;
  final Map<String, dynamic>? scannedData;
  final BuildContext parentContext;
  final WidgetRef parentRef;

  @override
  ConsumerState<_AddFoodSheet> createState() => _AddFoodSheetState();
}

class _AddFoodSheetState extends ConsumerState<_AddFoodSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _brandCtrl;
  late final TextEditingController _kcalCtrl;
  late final TextEditingController _proteinCtrl;
  late final TextEditingController _carbsCtrl;
  late final TextEditingController _fatCtrl;
  late final TextEditingController _servingCtrl;
  late String _unit;
  late String? _category;
  bool _saving = false;
  bool _scanned = false; // true after a successful barcode scan
  String _tab = 'food';  // 'food' | 'recipe'  (new-food mode only)

  @override
  void initState() {
    super.initState();
    final f = widget.existing;
    final s = widget.scannedData;
    _nameCtrl    = TextEditingController(text: f?.name    ?? (s?['name']    as String?) ?? '');
    _brandCtrl   = TextEditingController(text: f?.brand   ?? (s?['brand']   as String?) ?? '');
    _kcalCtrl    = TextEditingController(text: f != null ? f.kcal.round().toString()    : ((s?['kcal']    as num?)?.round().toString() ?? ''));
    _proteinCtrl = TextEditingController(text: f != null ? f.protein.round().toString() : ((s?['protein'] as num?)?.round().toString() ?? ''));
    _carbsCtrl   = TextEditingController(text: f != null ? f.carbs.round().toString()   : ((s?['carbs']   as num?)?.round().toString() ?? ''));
    _fatCtrl     = TextEditingController(text: f != null ? f.fat.round().toString()     : ((s?['fat']     as num?)?.round().toString() ?? ''));
    _servingCtrl = TextEditingController(text: f?.servingSize?.toString() ?? '');
    _unit     = f?.unit ?? 'per100g';
    final cat = f?.category;
    _category = (cat != null && foodCategories.contains(cat)) ? cat : null;
    if (s != null) _scanned = true;
  }

  @override
  void dispose() {
    for (final c in [_nameCtrl, _brandCtrl, _kcalCtrl, _proteinCtrl,
        _carbsCtrl, _fatCtrl, _servingCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);

    final data = {
      'name': _nameCtrl.text.trim(),
      'brand': _brandCtrl.text.trim().isEmpty ? null : _brandCtrl.text.trim(),
      'unit': _unit,
      'serving_size': double.tryParse(_servingCtrl.text),
      'kcal': double.tryParse(_kcalCtrl.text) ?? 0,
      'protein': double.tryParse(_proteinCtrl.text) ?? 0,
      'carbs': double.tryParse(_carbsCtrl.text) ?? 0,
      'fat': double.tryParse(_fatCtrl.text) ?? 0,
      'category': _category,
    };

    final parentCtx = widget.parentContext;
    final parentRef = widget.parentRef;

    if (widget.existing != null) {
      final ok = await ref.read(foodsProvider.notifier).updateFood(widget.existing!.id, data);
      if (mounted) {
        Navigator.pop(context);
        if (!ok) {
          ScaffoldMessenger.of(parentCtx).showSnackBar(
            const SnackBar(content: Text('Failed to save food')),
          );
        }
      }
    } else {
      final newFood = await ref.read(foodsProvider.notifier).addFood(data);
      if (mounted) {
        Navigator.pop(context);
        if (newFood == null) {
          ScaffoldMessenger.of(parentCtx).showSnackBar(
            const SnackBar(content: Text('Failed to save food')),
          );
        } else {
          // Show animated confirmation sheet with Log Now option
          final logNow = await showFoodSavedSheet(parentCtx, newFood);
          if (logNow) {
            final today = DateTime.now();
            final date =
                '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
            showAddEntrySheet(parentCtx, parentRef, date, preselectedFood: newFood);
          }
        }
      }
    }
  }

  Future<void> _scanBarcode() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const BarcodeScannerSheet(),
    );
    if (result == null || !mounted) return;
    setState(() {
      _nameCtrl.text    = result['name'] as String? ?? '';
      _brandCtrl.text   = result['brand'] as String? ?? '';
      _kcalCtrl.text    = (result['kcal'] as num?)?.round().toString() ?? '';
      _proteinCtrl.text = (result['protein'] as num?)?.round().toString() ?? '';
      _carbsCtrl.text   = (result['carbs'] as num?)?.round().toString() ?? '';
      _fatCtrl.text     = (result['fat'] as num?)?.round().toString() ?? '';
      _unit             = (result['unit'] as String?) ?? 'per100g';
      _scanned          = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = AppColorScheme.of(context);
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final isEdit = widget.existing != null;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        maxChildSize: 0.95,
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
              padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
              child: Row(
                children: [
                  Text(
                    isEdit ? 'Edit Food' : (_tab == 'recipe' ? 'New Recipe' : 'New Food'),
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
            // Tab toggle (new food mode only)
            if (!isEdit)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'food',   label: Text('New Food')),
                    ButtonSegment(value: 'recipe', label: Text('New Recipe')),
                  ],
                  selected: {_tab},
                  onSelectionChanged: (v) => setState(() => _tab = v.first),
                ),
              ),
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  // ── Recipe form ───────────────────────────────────────
                  if (!isEdit && _tab == 'recipe') ...[
                    AddRecipeForm(
                      onSaved: (food) async {
                        Navigator.of(context).pop();
                        final logNow = await showFoodSavedSheet(
                            widget.parentContext, food);
                        if (logNow) {
                          final today = DateTime.now();
                          final date =
                              '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
                          showAddEntrySheet(
                              widget.parentContext, widget.parentRef, date,
                              preselectedFood: food);
                        }
                      },
                    ),
                  ] else ...[
                  // ── Barcode hero (new food only) ──────────────────────
                  if (!isEdit) ...[
                    _BarcodeScanHero(
                      scanned: _scanned,
                      onTap: _scanBarcode,
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        const Expanded(child: Divider(endIndent: 12)),
                        Text(
                          _scanned ? 'Review & save' : 'or enter manually',
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.textMuted,
                          ),
                        ),
                        const Expanded(child: Divider(indent: 12)),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── Manual form ───────────────────────────────────────
                  _field('Name *', _nameCtrl),
                  const SizedBox(height: 12),
                  _field('Brand (optional)', _brandCtrl),
                  const SizedBox(height: 12),

                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'per100g',    label: Text('Per 100 g')),
                      ButtonSegment(value: 'perServing', label: Text('Per serving')),
                    ],
                    selected: {_unit},
                    onSelectionChanged: (v) => setState(() => _unit = v.first),
                  ),
                  if (_unit == 'perServing') ...[
                    const SizedBox(height: 12),
                    _field('Serving size (g)', _servingCtrl,
                        keyboardType: TextInputType.number),
                  ],
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(child: _macroField('Calories', _kcalCtrl, AppColors.kcal, 'kcal')),
                      const SizedBox(width: 10),
                      Expanded(child: _macroField('Protein', _proteinCtrl, AppColors.protein, 'g')),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _macroField('Carbs', _carbsCtrl, AppColors.carbs, 'g')),
                      const SizedBox(width: 10),
                      Expanded(child: _macroField('Fat', _fatCtrl, AppColors.fat, 'g')),
                    ],
                  ),
                  const SizedBox(height: 16),

                  DropdownButtonFormField<String?>(
                    value: _category,
                    decoration: const InputDecoration(labelText: 'Category (optional)'),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('— None —')),
                      ...foodCategories.map((c) => DropdownMenuItem<String?>(
                        value: c,
                        child: Text(
                          '${categoryEmojis[c] ?? ''} ${categoryLabels[c] ?? c}',
                          style: const TextStyle(fontSize: 13),
                        ),
                      )),
                    ],
                    onChanged: (v) => setState(() => _category = v),
                  ),
                  const SizedBox(height: 24),

                  ElevatedButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(height: 20, width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(isEdit ? 'Save Changes' : 'Save Food'),
                  ),
                  const SizedBox(height: 24),
                  ], // end else (food form)
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController ctrl, {
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      decoration: InputDecoration(labelText: label),
    );
  }

  Widget _macroField(String label, TextEditingController ctrl, Color color, String unit) {
    return TextField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: '$label ($unit)',
        labelStyle: TextStyle(color: color.withValues(alpha: 0.8)),
      ),
    );
  }
}

// ── Barcode hero button ────────────────────────────────────────────────────────

class _BarcodeScanHero extends StatelessWidget {
  const _BarcodeScanHero({required this.scanned, required this.onTap});
  final bool scanned;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = AppColorScheme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.protein.withValues(alpha: 0.18),
              AppColors.protein.withValues(alpha: 0.06),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: scanned
                ? AppColors.protein.withValues(alpha: 0.6)
                : AppColors.protein.withValues(alpha: 0.35),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                color: AppColors.protein.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                scanned ? Icons.check_circle_rounded : Icons.qr_code_scanner_rounded,
                color: AppColors.protein,
                size: 30,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    scanned ? 'Scanned successfully' : 'Scan Barcode',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: scanned ? AppColors.protein : cs.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    scanned
                        ? 'Review the details below, then save'
                        : 'Point your camera at a product barcode\nfor instant nutrition data',
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.textMuted,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            if (!scanned)
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.protein.withValues(alpha: 0.7),
                size: 22,
              ),
          ],
        ),
      ),
    );
  }
}
