import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/settings_provider.dart';
import '../../theme.dart';

class BodyStatsScreen extends ConsumerStatefulWidget {
  const BodyStatsScreen({super.key});

  @override
  ConsumerState<BodyStatsScreen> createState() => _BodyStatsScreenState();
}

class _BodyStatsScreenState extends ConsumerState<BodyStatsScreen> {
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
    final b = ref.read(settingsProvider).bodyStats;
    _ageCtrl    = TextEditingController(text: b.age?.toString() ?? '');
    _heightCtrl = TextEditingController(text: b.heightCm?.toStringAsFixed(0) ?? '');
    _weightCtrl = TextEditingController(text: b.weightKg?.toStringAsFixed(1) ?? '');
    _bfCtrl     = TextEditingController(text: b.bodyFatPct?.toStringAsFixed(1) ?? '');
    _sex      = b.sex;
    _activity = b.activity;
  }

  @override
  void dispose() {
    _ageCtrl.dispose();
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    _bfCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final settings = ref.read(settingsProvider);
    final updated = settings.bodyStats.copyWith(
      age:        int.tryParse(_ageCtrl.text),
      heightCm:   double.tryParse(_heightCtrl.text),
      weightKg:   double.tryParse(_weightCtrl.text),
      bodyFatPct: double.tryParse(_bfCtrl.text),
      sex:        _sex,
      activity:   _activity,
    );
    ref.read(settingsProvider.notifier).update(settings.copyWith(bodyStats: updated));
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Stats saved')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Body Stats'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        children: [
          _SectionLabel('Measurements'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: _numField('Age', _ageCtrl, 'yrs')),
                      const SizedBox(width: 12),
                      Expanded(child: _numField('Height', _heightCtrl, 'cm')),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _numField('Weight', _weightCtrl, 'kg')),
                      const SizedBox(width: 12),
                      Expanded(child: _numField('Body fat', _bfCtrl, '%')),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          _SectionLabel('Profile'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
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
                        .map((e) => DropdownMenuItem(
                              value: e.key,
                              child: Text(e.value),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _activity = v!),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _save,
              child: const Text('Save Stats'),
            ),
          ),

          const SizedBox(height: 32),
        ],
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
