import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';
import '../models/food.dart';
import '../providers/foods_provider.dart';
import '../theme.dart';
import 'barcode_scanner_sheet.dart';

void showAddFoodSheet(BuildContext context, WidgetRef ref, {Food? existing}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => ProviderScope(
      parent: ProviderScope.containerOf(context),
      child: _AddFoodSheet(existing: existing),
    ),
  );
}

class _AddFoodSheet extends ConsumerStatefulWidget {
  const _AddFoodSheet({this.existing});
  final Food? existing;

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

  @override
  void initState() {
    super.initState();
    final f = widget.existing;
    _nameCtrl    = TextEditingController(text: f?.name ?? '');
    _brandCtrl   = TextEditingController(text: f?.brand ?? '');
    _kcalCtrl    = TextEditingController(text: f != null ? f.kcal.round().toString() : '');
    _proteinCtrl = TextEditingController(text: f != null ? f.protein.round().toString() : '');
    _carbsCtrl   = TextEditingController(text: f != null ? f.carbs.round().toString() : '');
    _fatCtrl     = TextEditingController(text: f != null ? f.fat.round().toString() : '');
    _servingCtrl = TextEditingController(text: f?.servingSize?.toString() ?? '');
    _unit     = f?.unit ?? 'per100g';
    _category = f?.category;
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

    bool ok;
    if (widget.existing != null) {
      ok = await ref.read(foodsProvider.notifier).updateFood(widget.existing!.id, data);
    } else {
      ok = await ref.read(foodsProvider.notifier).addFood(data) != null;
    }

    if (mounted) {
      Navigator.pop(context);
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save food')),
        );
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
    });
  }

  @override
  Widget build(BuildContext context) {
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
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Text(
                    isEdit ? 'Edit Food' : 'New Food',
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  if (!isEdit)
                    IconButton(
                      tooltip: 'Scan barcode',
                      icon: const Icon(Icons.qr_code_scanner, color: AppColors.protein),
                      onPressed: _scanBarcode,
                    ),
                  TextButton(onPressed: Navigator.of(context).pop, child: const Text('Cancel')),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _field('Name *', _nameCtrl, autofocus: !isEdit),
                  const SizedBox(height: 12),
                  _field('Brand (optional)', _brandCtrl),
                  const SizedBox(height: 12),

                  // Unit toggle
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
                    _field('Serving size (g)', _servingCtrl, keyboardType: TextInputType.number),
                  ],
                  const SizedBox(height: 16),

                  // Macros row
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

                  // Category dropdown
                  DropdownButtonFormField<String>(
                    value: _category,
                    decoration: const InputDecoration(labelText: 'Category (optional)'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('— None —')),
                      ...foodCategories.map((c) => DropdownMenuItem(
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
                        : Text(isEdit ? 'Save Changes' : 'Add Food'),
                  ),
                  const SizedBox(height: 24),
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
    bool autofocus = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: ctrl,
      autofocus: autofocus,
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
