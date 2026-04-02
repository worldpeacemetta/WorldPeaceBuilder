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
  late MacroGoals _goals;
  late final TextEditingController _kcalCtrl;
  late final TextEditingController _proteinCtrl;
  late final TextEditingController _carbsCtrl;
  late final TextEditingController _fatCtrl;

  @override
  void initState() {
    super.initState();
    _goals = widget.settings.activeGoals;
    _kcalCtrl    = TextEditingController(text: _goals.kcal.round().toString());
    _proteinCtrl = TextEditingController(text: _goals.protein.round().toString());
    _carbsCtrl   = TextEditingController(text: _goals.carbs.round().toString());
    _fatCtrl     = TextEditingController(text: _goals.fat.round().toString());
  }

  @override
  void didUpdateWidget(_GoalsEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldS = oldWidget.settings;
    final newS = widget.settings;
    final profileChanged = oldS.setupMode != newS.setupMode ||
        oldS.dualProfile != newS.dualProfile;
    if (profileChanged) {
      _goals = newS.activeGoals;
      _kcalCtrl.text    = _goals.kcal.round().toString();
      _proteinCtrl.text = _goals.protein.round().toString();
      _carbsCtrl.text   = _goals.carbs.round().toString();
      _fatCtrl.text     = _goals.fat.round().toString();
    }
  }

  @override
  void dispose() {
    _kcalCtrl.dispose();
    _proteinCtrl.dispose();
    _carbsCtrl.dispose();
    _fatCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final updated = MacroGoals(
      kcal:    double.tryParse(_kcalCtrl.text)    ?? _goals.kcal,
      protein: double.tryParse(_proteinCtrl.text) ?? _goals.protein,
      carbs:   double.tryParse(_carbsCtrl.text)   ?? _goals.carbs,
      fat:     double.tryParse(_fatCtrl.text)      ?? _goals.fat,
    );
    final s = widget.settings;
    AppSettings newSettings;
    switch (s.setupMode) {
      case 'dual':
        newSettings = s.dualProfile == 'train'
            ? s.copyWith(dualTrainGoals: updated)
            : s.copyWith(dualRestGoals: updated);
      case 'bulking':
        newSettings = s.copyWith(bulkingGoals: updated);
      case 'cutting':
        newSettings = s.copyWith(cuttingGoals: updated);
      default:
        newSettings = s.copyWith(maintenanceGoals: updated);
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
            _goalField('Calories (kcal)', _kcalCtrl, AppColors.kcal),
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
