import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants.dart';
import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../../theme.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile & Settings')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // User info card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.protein.withValues(alpha: 0.2),
                    child: Text(
                      (user?.email?.substring(0, 1) ?? '?').toUpperCase(),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.protein,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.userMetadata?['display_username'] as String? ??
                              user?.email ?? 'User',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                        ),
                        Text(
                          user?.email ?? '',
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Goal mode
          _SectionHeader('Goal Mode'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    value: settings.setupMode,
                    decoration: const InputDecoration(labelText: 'Setup Mode'),
                    items: setupModes.map((m) => DropdownMenuItem(
                      value: m,
                      child: Text(setupModeLabels[m] ?? m),
                    )).toList(),
                    onChanged: (v) => ref.read(settingsProvider.notifier)
                        .update(settings.copyWith(setupMode: v)),
                  ),
                  if (settings.setupMode == 'dual') ...[
                    const SizedBox(height: 12),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'train', label: Text('Train Day')),
                        ButtonSegment(value: 'rest',  label: Text('Rest Day')),
                      ],
                      selected: {settings.dualProfile},
                      onSelectionChanged: (v) => ref.read(settingsProvider.notifier)
                          .update(settings.copyWith(dualProfile: v.first)),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Active goals editor
          _SectionHeader('Daily Goals — ${setupModeLabels[settings.setupMode] ?? settings.setupMode}'),
          _GoalsEditor(settings: settings),
          const SizedBox(height: 16),

          // Appearance
          _SectionHeader('Appearance'),
          Card(
            child: Column(
              children: [
                RadioListTile<String>(
                  value: 'system',
                  groupValue: settings.theme,
                  title: const Text('System default'),
                  onChanged: (v) => ref.read(settingsProvider.notifier)
                      .update(settings.copyWith(theme: v)),
                ),
                RadioListTile<String>(
                  value: 'dark',
                  groupValue: settings.theme,
                  title: const Text('Dark'),
                  onChanged: (v) => ref.read(settingsProvider.notifier)
                      .update(settings.copyWith(theme: v)),
                ),
                RadioListTile<String>(
                  value: 'light',
                  groupValue: settings.theme,
                  title: const Text('Light'),
                  onChanged: (v) => ref.read(settingsProvider.notifier)
                      .update(settings.copyWith(theme: v)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Sign out
          OutlinedButton.icon(
            onPressed: () => _confirmSignOut(context),
            icon: const Icon(Icons.logout, color: AppColors.danger),
            label: const Text('Sign Out', style: TextStyle(color: AppColors.danger)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.danger),
              minimumSize: const Size.fromHeight(48),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign Out', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (ok == true) await signOut();
  }
}

// ---------------------------------------------------------------------------
// Goals editor for the active mode
// ---------------------------------------------------------------------------
class _GoalsEditor extends ConsumerStatefulWidget {
  const _GoalsEditor({required this.settings});
  final AppSettings settings;

  @override
  ConsumerState<_GoalsEditor> createState() => _GoalsEditorState();
}

class _GoalsEditorState extends ConsumerState<_GoalsEditor> {
  late MacroGoals _goals;
  late final TextEditingController _kcalCtrl, _proteinCtrl, _carbsCtrl, _fatCtrl;

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
  void dispose() {
    _kcalCtrl.dispose(); _proteinCtrl.dispose();
    _carbsCtrl.dispose(); _fatCtrl.dispose();
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
      case 'bulking':      newSettings = s.copyWith(bulkingGoals: updated);
      case 'cutting':      newSettings = s.copyWith(cuttingGoals: updated);
      default:             newSettings = s.copyWith(maintenanceGoals: updated);
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
            const SizedBox(height: 16),
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

  Widget _goalField(String label, TextEditingController ctrl, Color color) {
    return TextField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Padding(
          padding: const EdgeInsets.all(12),
          child: Container(
            width: 10, height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section header
// ---------------------------------------------------------------------------
class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.textMuted,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
