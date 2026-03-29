import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants.dart';
import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../../theme.dart';
import '../../widgets/badges_preview_card.dart';

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
          _SectionHeader(settings.setupMode == 'dual'
              ? 'Daily Goals — ${settings.dualProfile == 'train' ? 'Train Day' : 'Rest Day'}'
              : 'Daily Goals — ${setupModeLabels[settings.setupMode] ?? settings.setupMode}'),
          _GoalsEditor(settings: settings),
          const SizedBox(height: 16),

          // Body Stats
          _SectionHeader('Body Stats'),
          _BodyStatsEditor(settings: settings),
          const SizedBox(height: 16),

          // Achievements
          _SectionHeader('Achievements'),
          const BadgesPreviewCard(),
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
          const SizedBox(height: 16),

          // Language
          _SectionHeader('Language'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: DropdownButtonFormField<String>(
                value: settings.language,
                decoration: const InputDecoration(
                  labelText: 'App Language',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: const [
                  DropdownMenuItem(value: 'en', child: Text('🇬🇧  English')),
                  DropdownMenuItem(value: 'fr', child: Text('🇫🇷  Français')),
                  DropdownMenuItem(value: 'es', child: Text('🇪🇸  Español')),
                  DropdownMenuItem(value: 'de', child: Text('🇩🇪  Deutsch')),
                  DropdownMenuItem(value: 'pt', child: Text('🇵🇹  Português')),
                  DropdownMenuItem(value: 'it', child: Text('🇮🇹  Italiano')),
                  DropdownMenuItem(value: 'nl', child: Text('🇳🇱  Nederlands')),
                  DropdownMenuItem(value: 'ja', child: Text('🇯🇵  日本語')),
                  DropdownMenuItem(value: 'zh', child: Text('🇨🇳  中文')),
                ],
                onChanged: (v) => ref.read(settingsProvider.notifier)
                    .update(settings.copyWith(language: v)),
              ),
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
  void didUpdateWidget(_GoalsEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldS = oldWidget.settings;
    final newS = widget.settings;
    // Reload controllers when the active profile slot changed (mode switch or
    // train↔rest toggle) so the fields reflect the correct day's targets.
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
// Body stats editor
// ---------------------------------------------------------------------------
class _BodyStatsEditor extends ConsumerStatefulWidget {
  const _BodyStatsEditor({required this.settings});
  final AppSettings settings;

  @override
  ConsumerState<_BodyStatsEditor> createState() => _BodyStatsEditorState();
}

class _BodyStatsEditorState extends ConsumerState<_BodyStatsEditor> {
  late final TextEditingController _ageCtrl;
  late final TextEditingController _heightCtrl;
  late final TextEditingController _weightCtrl;
  late final TextEditingController _bfCtrl;
  late String _sex;
  late String _activity;

  static const _activities = {
    'sedentary'  : 'Sedentary (desk job)',
    'light'      : 'Light (1–3×/week)',
    'moderate'   : 'Moderate (3–5×/week)',
    'active'     : 'Active (6–7×/week)',
    'very_active': 'Very active (2×/day)',
  };

  @override
  void initState() {
    super.initState();
    final b = widget.settings.bodyStats;
    _ageCtrl    = TextEditingController(text: b.age?.toString() ?? '');
    _heightCtrl = TextEditingController(text: b.heightCm?.toStringAsFixed(0) ?? '');
    _weightCtrl = TextEditingController(text: b.weightKg?.toStringAsFixed(1) ?? '');
    _bfCtrl     = TextEditingController(text: b.bodyFatPct?.toStringAsFixed(1) ?? '');
    _sex      = b.sex;
    _activity = b.activity;
  }

  @override
  void dispose() {
    _ageCtrl.dispose(); _heightCtrl.dispose();
    _weightCtrl.dispose(); _bfCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final updated = widget.settings.bodyStats.copyWith(
      age:        int.tryParse(_ageCtrl.text),
      heightCm:   double.tryParse(_heightCtrl.text),
      weightKg:   double.tryParse(_weightCtrl.text),
      bodyFatPct: double.tryParse(_bfCtrl.text),
      sex:        _sex,
      activity:   _activity,
    );
    ref.read(settingsProvider.notifier)
        .update(widget.settings.copyWith(bodyStats: updated));
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Stats saved')));
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: _numField('Age (years)', _ageCtrl, 'yrs')),
                const SizedBox(width: 10),
                Expanded(child: _numField('Height', _heightCtrl, 'cm')),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _numField('Weight', _weightCtrl, 'kg')),
                const SizedBox(width: 10),
                Expanded(child: _numField('Body fat', _bfCtrl, '%')),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _sex,
              decoration: const InputDecoration(labelText: 'Sex'),
              items: const [
                DropdownMenuItem(value: 'male',   child: Text('Male')),
                DropdownMenuItem(value: 'female', child: Text('Female')),
                DropdownMenuItem(value: 'other',  child: Text('Other / prefer not to say')),
              ],
              onChanged: (v) => setState(() => _sex = v!),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _activity,
              decoration: const InputDecoration(labelText: 'Activity Level'),
              items: _activities.entries
                  .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                  .toList(),
              onChanged: (v) => setState(() => _activity = v!),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(onPressed: _save, child: const Text('Save Stats')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _numField(String label, TextEditingController ctrl, String suffix) =>
      TextField(
        controller: ctrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: label, suffixText: suffix),
      );
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
