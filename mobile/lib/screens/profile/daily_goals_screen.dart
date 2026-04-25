import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../providers/settings_provider.dart';
import '../../theme.dart';

class DailyGoalsScreen extends ConsumerWidget {
  const DailyGoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Goals'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        children: [
          // ── Setup mode ────────────────────────────────────────────────────
          _SectionLabel('Goal Mode'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    value: settings.setupMode,
                    decoration: const InputDecoration(labelText: 'Setup Mode'),
                    items: setupModes
                        .map((m) => DropdownMenuItem(
                              value: m,
                              child: Text(setupModeLabels[m] ?? m),
                            ))
                        .toList(),
                    onChanged: (v) => ref
                        .read(settingsProvider.notifier)
                        .update(settings.copyWith(setupMode: v)),
                  ),
                  if (settings.setupMode == 'dual') ...[
                    const SizedBox(height: 14),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'train', label: Text('Train Day')),
                        ButtonSegment(value: 'rest', label: Text('Rest Day')),
                      ],
                      selected: {settings.dualProfile},
                      onSelectionChanged: (v) => ref
                          .read(settingsProvider.notifier)
                          .update(settings.copyWith(dualProfile: v.first)),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // ── Goals editor ──────────────────────────────────────────────────
          _SectionLabel(
            settings.setupMode == 'dual'
                ? 'Targets — ${settings.dualProfile == 'train' ? 'Train Day' : 'Rest Day'}'
                : 'Targets — ${setupModeLabels[settings.setupMode] ?? settings.setupMode}',
          ),
          _GoalsEditor(settings: settings),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ── Goals editor ───────────────────────────────────────────────────────────────

class _GoalsEditor extends ConsumerStatefulWidget {
  const _GoalsEditor({required this.settings});
  final AppSettings settings;

  @override
  ConsumerState<_GoalsEditor> createState() => _GoalsEditorState();
}

class _GoalsEditorState extends ConsumerState<_GoalsEditor> {
  // Active-profile controllers (always used)
  late final TextEditingController _kcalCtrl;
  late final TextEditingController _proteinCtrl;
  late final TextEditingController _carbsCtrl;
  late final TextEditingController _fatCtrl;

  // Second-profile controllers (dual mode only — holds the other tab's values)
  late final TextEditingController _kcalCtrl2;
  late final TextEditingController _proteinCtrl2;
  late final TextEditingController _carbsCtrl2;
  late final TextEditingController _fatCtrl2;

  @override
  void initState() {
    super.initState();
    _kcalCtrl    = TextEditingController();
    _proteinCtrl = TextEditingController();
    _carbsCtrl   = TextEditingController();
    _fatCtrl     = TextEditingController();
    _kcalCtrl2    = TextEditingController();
    _proteinCtrl2 = TextEditingController();
    _carbsCtrl2   = TextEditingController();
    _fatCtrl2     = TextEditingController();
    _loadAll(widget.settings);
  }

  /// Populate all controllers from [s] without losing edits.
  void _loadAll(AppSettings s) {
    _fillCtrl(s.activeGoals, _kcalCtrl, _proteinCtrl, _carbsCtrl, _fatCtrl);
    if (s.setupMode == 'dual') {
      final other = s.dualProfile == 'train' ? s.dualRestGoals : s.dualTrainGoals;
      _fillCtrl(other, _kcalCtrl2, _proteinCtrl2, _carbsCtrl2, _fatCtrl2);
    }
  }

  void _fillCtrl(MacroGoals g,
      TextEditingController k, TextEditingController p,
      TextEditingController c, TextEditingController f) {
    k.text = g.kcal.round().toString();
    p.text = g.protein.round().toString();
    c.text = g.carbs.round().toString();
    f.text = g.fat.round().toString();
  }

  MacroGoals _parse(TextEditingController k, TextEditingController p,
      TextEditingController c, TextEditingController f, MacroGoals fallback) {
    return MacroGoals(
      kcal:    double.tryParse(k.text) ?? fallback.kcal,
      protein: double.tryParse(p.text) ?? fallback.protein,
      carbs:   double.tryParse(c.text) ?? fallback.carbs,
      fat:     double.tryParse(f.text) ?? fallback.fat,
    );
  }

  @override
  void didUpdateWidget(_GoalsEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldS = oldWidget.settings;
    final newS = widget.settings;

    if (oldS.setupMode != newS.setupMode) {
      // Mode changed entirely — reload everything
      _loadAll(newS);
    } else if (oldS.dualProfile != newS.dualProfile) {
      // Tab switched — swap active ↔ secondary controllers WITHOUT overwriting
      // active controllers (user's unsaved edits are preserved in ctrl2)
      final tmp = [_kcalCtrl.text, _proteinCtrl.text, _carbsCtrl.text, _fatCtrl.text];
      _kcalCtrl.text    = _kcalCtrl2.text;
      _proteinCtrl.text = _proteinCtrl2.text;
      _carbsCtrl.text   = _carbsCtrl2.text;
      _fatCtrl.text     = _fatCtrl2.text;
      _kcalCtrl2.text    = tmp[0];
      _proteinCtrl2.text = tmp[1];
      _carbsCtrl2.text   = tmp[2];
      _fatCtrl2.text     = tmp[3];
    }
  }

  @override
  void dispose() {
    _kcalCtrl.dispose();   _proteinCtrl.dispose();
    _carbsCtrl.dispose();  _fatCtrl.dispose();
    _kcalCtrl2.dispose();  _proteinCtrl2.dispose();
    _carbsCtrl2.dispose(); _fatCtrl2.dispose();
    super.dispose();
  }

  void _save() {
    final s = widget.settings;
    final active  = _parse(_kcalCtrl,  _proteinCtrl,  _carbsCtrl,  _fatCtrl,  s.activeGoals);
    AppSettings newSettings;
    switch (s.setupMode) {
      case 'dual':
        // Always save both profiles so neither tab's edits are lost
        final other = _parse(_kcalCtrl2, _proteinCtrl2, _carbsCtrl2, _fatCtrl2,
            s.dualProfile == 'train' ? s.dualRestGoals : s.dualTrainGoals);
        newSettings = s.dualProfile == 'train'
            ? s.copyWith(dualTrainGoals: active, dualRestGoals: other)
            : s.copyWith(dualRestGoals: active, dualTrainGoals: other);
      case 'bulking':
        newSettings = s.copyWith(bulkingGoals: active);
      case 'cutting':
        newSettings = s.copyWith(cuttingGoals: active);
      default:
        newSettings = s.copyWith(maintenanceGoals: active);
    }
    ref.read(settingsProvider.notifier).update(newSettings);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Goals saved')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _goalField('Calories (kcal)', _kcalCtrl, AppColorScheme.of(context).kcalColor),
            const SizedBox(height: 12),
            _goalField('Protein (g)', _proteinCtrl, AppColors.protein),
            const SizedBox(height: 12),
            _goalField('Carbs (g)', _carbsCtrl, AppColors.carbs),
            const SizedBox(height: 12),
            _goalField('Fat (g)', _fatCtrl, AppColors.fat),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _save,
                child: const Text('Save Goals'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _goalField(
      String label, TextEditingController ctrl, Color color) {
    return TextField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Padding(
          padding: const EdgeInsets.all(14),
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        ),
      ),
    );
  }
}

// ── Section label ──────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColorScheme.of(context).textMuted,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
