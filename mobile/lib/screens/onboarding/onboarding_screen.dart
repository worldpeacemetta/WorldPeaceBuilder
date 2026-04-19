import 'dart:math' show max;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/default_foods.dart';
import '../../providers/foods_provider.dart';
import '../../providers/settings_provider.dart';
import '../../theme.dart';

// ---------------------------------------------------------------------------
// Formula helpers (ported from web OnboardingQuestionnaire.tsx)
// ---------------------------------------------------------------------------

const _activityMultipliers = {
  'sedentary': 1.2,
  'light':     1.375,
  'moderate':  1.55,
  'active':    1.725,
  'athlete':   1.9,
};

double? _computeBMR(String sex, double? age, double? heightCm,
    double? weightKg, double? bodyFatPct) {
  if (age == null || heightCm == null || weightKg == null) return null;
  if (bodyFatPct != null && bodyFatPct > 0) {
    // Katch-McArdle
    final lbm = weightKg * (1 - bodyFatPct / 100);
    return 370 + 21.6 * lbm;
  }
  // Mifflin-St Jeor
  final base = 10 * weightKg + 6.25 * heightCm - 5 * age;
  return sex == 'female' ? base - 161 : base + 5;
}

Map<String, int?>? _computeSingleMacros(String sex, double? age,
    double? heightCm, double? weightKg, double? bodyFatPct,
    String activity, String goal, String aggressiveness) {
  final bmr = _computeBMR(sex, age, heightCm, weightKg, bodyFatPct);
  if (bmr == null) return null;

  final tdee = (bmr * (_activityMultipliers[activity] ?? 1.55)).round();
  final delta = switch ('$goal-$aggressiveness') {
    'cutting-aggressive'  => -600,
    'cutting-moderate'    => -350,
    'bulking-aggressive'  =>  450,
    'bulking-moderate'    =>  250,
    _                     =>    0,
  };
  final kcal   = tdee + delta;
  final protein = ((weightKg ?? 70) * (goal == 'cutting' ? 2.2 : 1.8)).round();
  final fat     = max(30, ((kcal * 0.275) / 9).round());
  final carbs   = max(0, ((kcal - protein * 4 - fat * 9) / 4).round());
  return {'kcal': kcal, 'protein': protein, 'fat': fat, 'carbs': carbs, 'tdee': tdee};
}

Map<String, Map<String, int>>? _computeDualMacros(String sex, double? age,
    double? heightCm, double? weightKg, double? bodyFatPct,
    String activity, String aggressiveness) {
  final base = _computeSingleMacros(
      sex, age, heightCm, weightKg, bodyFatPct, activity, 'maintenance', aggressiveness);
  if (base == null) return null;

  const carbShift = 55;
  const fatShift  = 6;
  return {
    'train': {
      'kcal':    (base['kcal']! + carbShift * 4 - fatShift * 9).round(),
      'protein': base['protein']!,
      'carbs':   base['carbs']! + carbShift,
      'fat':     max(20, base['fat']! - fatShift),
    },
    'rest': {
      'kcal':    (base['kcal']! - carbShift * 4 + fatShift * 9).round(),
      'protein': base['protein']!,
      'carbs':   max(0, base['carbs']! - carbShift),
      'fat':     base['fat']! + fatShift,
    },
  };
}

// Unit helpers
double _ftInToCm(double ft, double inch) => (ft * 12 + inch) * 2.54;
double _lbToKg(double lb)  => lb / 2.20462;

// Lottie asset per step index (null = no animation for that step)
const _kLottie = <String?>[
  'assets/lottie/Businessman flies up with rocket.json', // 0: welcome
  'assets/lottie/Login.json',                            // 1: name
  'assets/lottie/Analytics Character Animation.json',    // 2: about you
  'assets/lottie/Isometric data analysis.json',          // 3: measurements
  'assets/lottie/Weightlifting competition.json',        // 4: activity
  null,                                                   // 5: goal
  'assets/lottie/Food Choice.json',                      // 6: macro targets
];

// ---------------------------------------------------------------------------
// OnboardingScreen
// ---------------------------------------------------------------------------

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const _totalSteps = 7; // 0=welcome, 1=name, 2=about, 3=measurements, 4=activity, 5=goal, 6=macros
  int _step = 0;
  bool _saving = false;

  // Step 0 — Username
  late final TextEditingController _nameCtrl;

  // Step 1 — Age & Sex
  final _ageCtrl = TextEditingController();
  String _sex = '';

  // Step 2 — Height / Weight / Body fat
  String _unit = 'metric';
  final _heightCmCtrl  = TextEditingController();
  final _heightFtCtrl  = TextEditingController();
  final _heightInCtrl  = TextEditingController();
  final _weightKgCtrl  = TextEditingController();
  final _weightLbCtrl  = TextEditingController();
  final _bodyFatCtrl   = TextEditingController();

  // Step 3 — Activity
  String _activity = 'moderate';

  // Step 4 — Goal mode
  String _goalMode       = 'maintenance';
  String _aggressiveness = 'moderate';

  // Step 5 — Macros (editable)
  // single mode
  final _kcalCtrl   = TextEditingController();
  final _proteinCtrl = TextEditingController();
  final _carbsCtrl  = TextEditingController();
  final _fatCtrl    = TextEditingController();
  // dual mode
  final _tKcalCtrl    = TextEditingController();
  final _tProteinCtrl = TextEditingController();
  final _tCarbsCtrl   = TextEditingController();
  final _tFatCtrl     = TextEditingController();
  final _rKcalCtrl    = TextEditingController();
  final _rProteinCtrl = TextEditingController();
  final _rCarbsCtrl   = TextEditingController();
  final _rFatCtrl     = TextEditingController();
  int? _tdee;

  @override
  void initState() {
    super.initState();
    final email = Supabase.instance.client.auth.currentUser?.email ?? '';
    final prefix = email.split('@').first;
    _nameCtrl = TextEditingController(text: prefix);
  }

  @override
  void dispose() {
    for (final c in [
      _nameCtrl, _ageCtrl, _heightCmCtrl, _heightFtCtrl, _heightInCtrl,
      _weightKgCtrl, _weightLbCtrl, _bodyFatCtrl,
      _kcalCtrl, _proteinCtrl, _carbsCtrl, _fatCtrl,
      _tKcalCtrl, _tProteinCtrl, _tCarbsCtrl, _tFatCtrl,
      _rKcalCtrl, _rProteinCtrl, _rCarbsCtrl, _rFatCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Navigation ─────────────────────────────────────────────────────────────

  void _next() {
    if (_step == 5) _computeAndFillMacros();
    setState(() => _step = (_step + 1).clamp(0, _totalSteps - 1));
  }

  void _back() => setState(() => _step = (_step - 1).clamp(0, _totalSteps - 1));

  void _skip() => setState(() => _step = (_step + 1).clamp(0, _totalSteps - 1));

  // ── Macro computation ───────────────────────────────────────────────────────

  void _computeAndFillMacros() {
    final heightCm = _unit == 'metric'
        ? double.tryParse(_heightCmCtrl.text)
        : (_heightFtCtrl.text.isNotEmpty || _heightInCtrl.text.isNotEmpty)
            ? _ftInToCm(double.tryParse(_heightFtCtrl.text) ?? 0,
                        double.tryParse(_heightInCtrl.text) ?? 0)
            : null;
    final weightKg = _unit == 'metric'
        ? double.tryParse(_weightKgCtrl.text)
        : (double.tryParse(_weightLbCtrl.text) != null
            ? _lbToKg(double.parse(_weightLbCtrl.text))
            : null);
    final age      = double.tryParse(_ageCtrl.text);
    final bf       = double.tryParse(_bodyFatCtrl.text);
    final sex      = _sex.isEmpty ? 'male' : _sex;

    if (_goalMode == 'dual') {
      final dual = _computeDualMacros(sex, age, heightCm, weightKg, bf, _activity, _aggressiveness)
          ?? {'train': {'kcal': 2200, 'protein': 160, 'carbs': 250, 'fat': 60},
              'rest':  {'kcal': 1800, 'protein': 160, 'carbs': 140, 'fat': 67}};
      _tKcalCtrl.text    = '${dual['train']!['kcal']}';
      _tProteinCtrl.text = '${dual['train']!['protein']}';
      _tCarbsCtrl.text   = '${dual['train']!['carbs']}';
      _tFatCtrl.text     = '${dual['train']!['fat']}';
      _rKcalCtrl.text    = '${dual['rest']!['kcal']}';
      _rProteinCtrl.text = '${dual['rest']!['protein']}';
      _rCarbsCtrl.text   = '${dual['rest']!['carbs']}';
      _rFatCtrl.text     = '${dual['rest']!['fat']}';
      _tdee = null;
    } else {
      final m = _computeSingleMacros(sex, age, heightCm, weightKg, bf,
              _activity, _goalMode, _aggressiveness)
          ?? <String, int?>{'kcal': 2000, 'protein': 150, 'carbs': 200, 'fat': 65, 'tdee': null};
      _kcalCtrl.text    = '${m['kcal']}';
      _proteinCtrl.text = '${m['protein']}';
      _carbsCtrl.text   = '${m['carbs']}';
      _fatCtrl.text     = '${m['fat']}';
      _tdee = m['tdee'];
    }
  }

  // ── Default food seeding ─────────────────────────────────────────────────────

  /// Inserts the 34 default foods for a brand-new user.
  /// Checks for existing foods first so this is a no-op for any user who
  /// already has foods in their database (existing accounts are unaffected).
  Future<void> _seedDefaultFoods(String userId) async {
    try {
      final existing = await Supabase.instance.client
          .from('foods')
          .select('id')
          .eq('user_id', userId)
          .limit(1);
      if ((existing as List).isNotEmpty) return;

      final payload = kDefaultFoods.map((f) => {
        'user_id':  userId,
        'name':     f['name'],
        'unit':     f['unit'],
        'category': f['category'],
        'kcal':     f['kcal'],
        'fat':      f['fat'],
        'carbs':    f['carbs'],
        'protein':  f['protein'],
        if (f.containsKey('serving_size')) 'serving_size': f['serving_size'],
      }).toList();

      final inserted = await Supabase.instance.client
          .from('foods')
          .insert(payload)
          .select('id');

      // Persist the seeded IDs so badge computation can exclude them from
      // user-added food counts (mirrors web app's defaultFoodIds).
      final ids = (inserted as List).map((r) => r['id'] as String).toList();
      if (ids.isNotEmpty) {
        await ref.read(settingsProvider.notifier).update(
          ref.read(settingsProvider).copyWith(defaultFoodIds: ids),
        );
      }
    } catch (_) {
      // Non-fatal — the user can still add foods manually.
    }
  }

  // ── Save ────────────────────────────────────────────────────────────────────

  Future<void> _handleComplete() async {
    setState(() => _saving = true);
    try {
      final user = Supabase.instance.client.auth.currentUser!;

      // 1. Update display_username in Supabase auth metadata
      final name = _nameCtrl.text.trim();
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(data: {
          'display_username': name,
          'username': name.toLowerCase(),
          'onboarding_done': true,
        }),
      );

      // 2. Build goals + body stats and save via settings provider
      final heightCm = _unit == 'metric'
          ? double.tryParse(_heightCmCtrl.text) ?? 0
          : _ftInToCm(double.tryParse(_heightFtCtrl.text) ?? 0,
                      double.tryParse(_heightInCtrl.text) ?? 0);
      final weightKg = _unit == 'metric'
          ? double.tryParse(_weightKgCtrl.text) ?? 0
          : _lbToKg(double.tryParse(_weightLbCtrl.text) ?? 0);
      final bodyStats = BodyStats(
        age:        _ageCtrl.text.isNotEmpty ? int.tryParse(_ageCtrl.text) : null,
        sex:        _sex.isNotEmpty ? _sex : 'other',
        heightCm:   heightCm > 0 ? heightCm : null,
        weightKg:   weightKg > 0 ? weightKg : null,
        bodyFatPct: _bodyFatCtrl.text.isNotEmpty
            ? double.tryParse(_bodyFatCtrl.text)
            : null,
        activity:   _activity,
      );
      // Seed an initial weight-history entry if the user supplied their weight.
      final weightHistory = weightKg > 0
          ? [WeightEntry(date: DateTime.now().toIso8601String().substring(0, 10), weight: weightKg)]
          : <WeightEntry>[];

      final AppSettings updated;
      if (_goalMode == 'dual') {
        updated = ref.read(settingsProvider).copyWith(
          setupMode: 'dual',
          dualTrainGoals: MacroGoals(
            kcal:    double.tryParse(_tKcalCtrl.text)    ?? 2200,
            protein: double.tryParse(_tProteinCtrl.text) ?? 160,
            carbs:   double.tryParse(_tCarbsCtrl.text)   ?? 250,
            fat:     double.tryParse(_tFatCtrl.text)     ?? 60,
          ),
          dualRestGoals: MacroGoals(
            kcal:    double.tryParse(_rKcalCtrl.text)    ?? 1800,
            protein: double.tryParse(_rProteinCtrl.text) ?? 160,
            carbs:   double.tryParse(_rCarbsCtrl.text)   ?? 140,
            fat:     double.tryParse(_rFatCtrl.text)     ?? 67,
          ),
          bodyStats: bodyStats,
          weightHistory: weightHistory.isNotEmpty ? weightHistory : null,
        );
      } else {
        final goals = MacroGoals(
          kcal:    double.tryParse(_kcalCtrl.text)    ?? 2000,
          protein: double.tryParse(_proteinCtrl.text) ?? 150,
          carbs:   double.tryParse(_carbsCtrl.text)   ?? 200,
          fat:     double.tryParse(_fatCtrl.text)     ?? 65,
        );
        updated = ref.read(settingsProvider).copyWith(
          setupMode: _goalMode,
          maintenanceGoals: _goalMode == 'maintenance' ? goals : null,
          bulkingGoals:     _goalMode == 'bulking'     ? goals : null,
          cuttingGoals:     _goalMode == 'cutting'     ? goals : null,
          bodyStats: bodyStats,
          weightHistory: weightHistory.isNotEmpty ? weightHistory : null,
        );
      }
      // update() persists everything (goals + body stats) to user_profile via
      // _saveToSupabase, which uses the correct table and column names.
      await ref.read(settingsProvider.notifier).update(updated);

      // 3. Seed the default food library (skipped if foods already exist so
      //    existing users are never affected).
      await _seedDefaultFoods(user.id);

      if (mounted) {
        ref.invalidate(settingsProvider);
        ref.invalidate(foodsProvider);
        context.go('/log');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_step == 0) return _buildWelcomeScreen();

    final cs = AppColorScheme.of(context);
    final lottie = _kLottie[_step];

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Column(
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 32,
                    child: GestureDetector(
                      onTap: _back,
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 18,
                        color: cs.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: _ProgressBar(step: _step - 1, total: 6)),
                  const SizedBox(width: 40),
                ],
              ),
              const SizedBox(height: 12),
              if (lottie != null)
                SizedBox(
                  height: 180,
                  child: Lottie.asset(lottie, fit: BoxFit.contain, key: ValueKey(_step)),
                )
              else
                const SizedBox(height: 8),
              const SizedBox(height: 8),
              Expanded(
                child: SingleChildScrollView(
                  child: _buildStep(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeScreen() {
    final cs = AppColorScheme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 32, 28, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 5,
                child: Center(
                  child: Lottie.asset(_kLottie[0]!, fit: BoxFit.contain),
                ),
              ),
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _AnimatedWords(
                      key: const ValueKey('welcome_title'),
                      text: 'Your nutrition, your way.',
                      style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, height: 1.2),
                    ),
                    const SizedBox(height: 12),
                    _AnimatedWords(
                      key: const ValueKey('welcome_body'),
                      delayMs: 350,
                      text: 'MacroTracker puts you in full control. Build a food library from your own grocery supplies, scan barcodes, create recipes from scratch, and set goals that actually fit your lifestyle — not a generic template.',
                      style: TextStyle(fontSize: 15, height: 1.55, color: cs.textMuted),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: _next,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.protein,
                        foregroundColor: Colors.black87,
                        minimumSize: const Size(double.infinity, 52),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Get started', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep() {
    return switch (_step) {
      1 => _buildName(),
      2 => _buildAgeSex(),
      3 => _buildMeasurements(),
      4 => _buildActivity(),
      5 => _buildGoal(),
      6 => _buildMacroReview(),
      _ => const SizedBox.shrink(),
    };
  }

  Widget _buildName() {
    return _StepWrapper(
      title: 'First things first — what\'s your name?',
      subtitle: 'This is how you\'ll appear in the app. You can always change it later.',
      nextDisabled: _nameCtrl.text.trim().isEmpty,
      onNext: _next,
      child: TextField(
        controller: _nameCtrl,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(
          labelText: 'Display name',
          hintText: 'e.g. David',
        ),
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) { if (_nameCtrl.text.trim().isNotEmpty) _next(); },
      ),
    );
  }

  // ── Step 1: Age & Sex ───────────────────────────────────────────────────────

  Widget _buildAgeSex() {
    return _StepWrapper(
      title: 'Tell us a bit about yourself.',
      subtitle: 'Your age and biological sex help us calculate the right starting point for your macros.',
      onNext: _next,
      onSkip: _skip,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _ageCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Age', hintText: '30'),
          ),
          const SizedBox(height: 20),
          const Text('Biological sex',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final opt in [
                ('male', 'Male'), ('female', 'Female'), ('other', 'Other')
              ]) ...[
                Expanded(
                  child: _ChoiceChip(
                    label: opt.$2,
                    selected: _sex == opt.$1,
                    onTap: () => setState(() => _sex = opt.$1),
                  ),
                ),
                if (opt.$1 != 'other') const SizedBox(width: 8),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ── Step 2: Height / Weight / Body fat ─────────────────────────────────────

  Widget _buildMeasurements() {
    return _StepWrapper(
      title: 'Now let\'s get the numbers right.',
      subtitle: 'Height and weight help us estimate how much fuel your body actually needs each day.',
      onNext: _next,
      onSkip: _skip,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Unit toggle
          Row(
            children: [
              for (final u in [('metric', 'kg / cm'), ('imperial', 'lb / ft')])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(u.$2),
                    selected: _unit == u.$1,
                    onSelected: (_) => _switchUnit(u.$1),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (_unit == 'metric') ...[
            Row(children: [
              Expanded(child: TextField(controller: _heightCmCtrl, keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Height (cm)', hintText: '175'))),
              const SizedBox(width: 12),
              Expanded(child: TextField(controller: _weightKgCtrl, keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Weight (kg)', hintText: '75'))),
            ]),
          ] else ...[
            Row(children: [
              Expanded(child: TextField(controller: _heightFtCtrl, keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Height (ft)', hintText: '5'))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: _heightInCtrl, keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'in', hintText: '9'))),
              const SizedBox(width: 12),
              Expanded(child: TextField(controller: _weightLbCtrl, keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Weight (lb)', hintText: '165'))),
            ]),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _bodyFatCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Body fat % (optional)',
              hintText: 'e.g. 18',
              helperText: 'Enables more accurate Katch-McArdle formula',
            ),
          ),
        ],
      ),
    );
  }

  void _switchUnit(String newUnit) {
    if (newUnit == _unit) return;
    if (newUnit == 'imperial') {
      final cm = double.tryParse(_heightCmCtrl.text);
      if (cm != null) {
        final totalIn = cm / 2.54;
        _heightFtCtrl.text = totalIn ~/ 12 == 0 ? '' : '${totalIn ~/ 12}';
        _heightInCtrl.text = '${(totalIn % 12).round()}';
      }
      final kg = double.tryParse(_weightKgCtrl.text);
      if (kg != null) _weightLbCtrl.text = '${(kg * 2.20462).round()}';
    } else {
      final ft = double.tryParse(_heightFtCtrl.text) ?? 0;
      final inch = double.tryParse(_heightInCtrl.text) ?? 0;
      if (ft > 0 || inch > 0) _heightCmCtrl.text = '${_ftInToCm(ft, inch).round()}';
      final lb = double.tryParse(_weightLbCtrl.text);
      if (lb != null) _weightKgCtrl.text = '${(_lbToKg(lb) * 10).round() / 10}';
    }
    setState(() => _unit = newUnit);
  }

  // ── Step 3: Activity ────────────────────────────────────────────────────────

  Widget _buildActivity() {
    const options = [
      ('sedentary', 'Sedentary',    'Little or no exercise'),
      ('light',     'Lightly active','1–3 days/week'),
      ('moderate',  'Moderately active', '3–5 days/week'),
      ('active',    'Very active',  '6–7 days/week'),
      ('athlete',   'Athlete',      '2× per day or physical job'),
    ];
    return _StepWrapper(
      title: 'How does a typical week look for you?',
      subtitle: 'Be honest — there are no wrong answers. This shapes your daily calorie target.',
      onNext: _next,
      onSkip: _skip,
      child: Column(
        children: options.map((o) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _SelectCard(
            label: o.$2,
            description: o.$3,
            selected: _activity == o.$1,
            onTap: () => setState(() => _activity = o.$1),
          ),
        )).toList(),
      ),
    );
  }

  // ── Step 4: Goal ────────────────────────────────────────────────────────────

  Widget _buildGoal() {
    const goals = [
      ('maintenance', '⚖️', 'Maintain weight',  'Keep your current weight stable'),
      ('cutting',     '🔥', 'Lose weight',       'Caloric deficit to shed fat'),
      ('bulking',     '💪', 'Gain muscle',       'Caloric surplus for muscle growth'),
      ('dual',        '📆', 'Train / Rest days', 'Different goals for training vs rest'),
    ];
    return _StepWrapper(
      title: 'What are you working towards?',
      subtitle: 'We\'ll use your answer to dial in your calorie and macro targets.',
      onNext: _next,
      onSkip: _skip,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...goals.map((g) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _GoalCard(
              icon: g.$2, label: g.$3, description: g.$4,
              selected: _goalMode == g.$1,
              onTap: () => setState(() => _goalMode = g.$1),
            ),
          )),
          if (_goalMode == 'cutting' || _goalMode == 'bulking') ...[
            const SizedBox(height: 8),
            const Text('How aggressive?',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _ChoiceChip(
                label: _goalMode == 'cutting' ? '−350 kcal' : '+250 kcal',
                sublabel: 'Moderate',
                selected: _aggressiveness == 'moderate',
                onTap: () => setState(() => _aggressiveness = 'moderate'),
              )),
              const SizedBox(width: 8),
              Expanded(child: _ChoiceChip(
                label: _goalMode == 'cutting' ? '−600 kcal' : '+450 kcal',
                sublabel: 'Aggressive',
                selected: _aggressiveness == 'aggressive',
                onTap: () => setState(() => _aggressiveness = 'aggressive'),
              )),
            ]),
          ],
        ],
      ),
    );
  }

  // ── Step 5: Macro review ────────────────────────────────────────────────────

  Widget _buildMacroReview() {
    final tdeeText = _tdee != null
        ? 'Your estimated TDEE is $_tdee kcal/day. Adjust anything — you\'re in full control.'
        : 'Calculated from everything you just told us. Adjust anything — you\'re in full control.';

    return _StepWrapper(
      title: 'Here\'s your starting point.',
      subtitle: tdeeText,
      nextLabel: _saving ? 'Saving…' : 'Get started',
      nextDisabled: _saving,
      onNext: _handleComplete,
      child: _goalMode == 'dual'
          ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _sectionLabel('Training days'),
              const SizedBox(height: 8),
              _macroGrid([
                ('Calories', _tKcalCtrl, 'kcal', AppColorScheme.of(context).kcalColor),
                ('Protein',  _tProteinCtrl, 'g', AppColors.protein),
                ('Carbs',    _tCarbsCtrl, 'g',   AppColors.carbs),
                ('Fat',      _tFatCtrl, 'g',     AppColors.fat),
              ]),
              const SizedBox(height: 16),
              _sectionLabel('Rest days'),
              const SizedBox(height: 8),
              _macroGrid([
                ('Calories', _rKcalCtrl, 'kcal', AppColorScheme.of(context).kcalColor),
                ('Protein',  _rProteinCtrl, 'g', AppColors.protein),
                ('Carbs',    _rCarbsCtrl, 'g',   AppColors.carbs),
                ('Fat',      _rFatCtrl, 'g',     AppColors.fat),
              ]),
            ])
          : _macroGrid([
              ('Calories', _kcalCtrl, 'kcal', AppColorScheme.of(context).kcalColor),
              ('Protein',  _proteinCtrl, 'g', AppColors.protein),
              ('Carbs',    _carbsCtrl, 'g',   AppColors.carbs),
              ('Fat',      _fatCtrl, 'g',     AppColors.fat),
            ]),
    );
  }

  Widget _sectionLabel(String text) => Text(text,
      style: const TextStyle(
          fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8));

  Widget _macroGrid(List<(String, TextEditingController, String, Color)> items) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.6,
      children: items.map((it) => _MacroBox(
        label: it.$1, ctrl: it.$2, unit: it.$3, color: it.$4,
      )).toList(),
    );
  }
}

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// _AnimatedWords — progressive word-by-word fade-in
// ---------------------------------------------------------------------------

class _AnimatedWords extends StatefulWidget {
  const _AnimatedWords({
    super.key,
    required this.text,
    required this.style,
    this.delayMs = 0,
  });
  final String text;
  final TextStyle style;
  final int delayMs;

  @override
  State<_AnimatedWords> createState() => _AnimatedWordsState();
}

class _AnimatedWordsState extends State<_AnimatedWords>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final List<Animation<double>> _anims;

  @override
  void initState() {
    super.initState();
    final words = widget.text.split(RegExp(r'\s+'));
    final count = words.length;
    _ctrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 400 + count * 60),
    );
    _anims = List.generate(count, (i) {
      final start = count == 1 ? 0.0 : (i / count * 0.65).clamp(0.0, 1.0);
      final end = (start + 0.35).clamp(0.0, 1.0);
      return CurvedAnimation(
        parent: _ctrl,
        curve: Interval(start, end, curve: Curves.easeOut),
      );
    });
    if (widget.delayMs > 0) {
      Future.delayed(Duration(milliseconds: widget.delayMs), () {
        if (mounted) _ctrl.forward();
      });
    } else {
      _ctrl.forward();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final words = widget.text.split(RegExp(r'\s+'));
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Wrap(
        children: [
          for (int i = 0; i < words.length; i++)
            Opacity(
              opacity: _anims[i].value,
              child: Text('${words[i]} ', style: widget.style),
            ),
        ],
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.step, required this.total});
  final int step, total;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(total, (i) {
        final Color c;
        if (i < step)       c = AppColors.protein;
        else if (i == step) c = AppColors.protein.withValues(alpha: 0.5);
        else                c = AppColorScheme.of(context).border;
        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            height: 4,
            decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2)),
          ),
        );
      }),
    );
  }
}

class _StepWrapper extends StatelessWidget {
  const _StepWrapper({
    required this.title,
    required this.child,
    required this.onNext,
    this.subtitle,
    this.onSkip,
    this.nextLabel,
    this.nextDisabled = false,
  });
  final String title;
  final String? subtitle;
  final Widget child;
  final VoidCallback onNext;
  final VoidCallback? onSkip;
  final String? nextLabel;
  final bool nextDisabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AnimatedWords(
          text: title,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, height: 1.25),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          _AnimatedWords(
            delayMs: 250,
            text: subtitle!,
            style: TextStyle(fontSize: 14, color: AppColorScheme.of(context).textMuted, height: 1.4),
          ),
        ],
        const SizedBox(height: 24),
        child,
        const SizedBox(height: 28),
        Row(children: [
          Expanded(
            child: FilledButton(
              onPressed: nextDisabled ? null : onNext,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.protein,
                foregroundColor: Colors.black87,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(nextLabel ?? 'Continue',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
          if (onSkip != null) ...[
            const SizedBox(width: 12),
            TextButton(
              onPressed: onSkip,
              child: Text('Skip',
                  style: TextStyle(
                      color: AppColorScheme.of(context).textMuted)),
            ),
          ],
        ]),
      ],
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  const _ChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.sublabel,
  });
  final String label;
  final String? sublabel;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = AppColorScheme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.protein.withValues(alpha: 0.15) : cs.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.protein : cs.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: selected ? AppColors.protein : cs.textPrimary)),
            if (sublabel != null)
              Text(sublabel!,
                  style: TextStyle(fontSize: 11, color: cs.textMuted)),
          ],
        ),
      ),
    );
  }
}

class _SelectCard extends StatelessWidget {
  const _SelectCard({
    required this.label,
    required this.description,
    required this.selected,
    required this.onTap,
  });
  final String label, description;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = AppColorScheme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.protein.withValues(alpha: 0.1) : cs.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.protein : cs.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(children: [
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: selected ? AppColors.protein : cs.textPrimary)),
              Text(description,
                  style: TextStyle(fontSize: 12, color: cs.textMuted)),
            ],
          )),
          Container(
            width: 18, height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected ? AppColors.protein : Colors.transparent,
              border: Border.all(
                  color: selected ? AppColors.protein : cs.border, width: 2),
            ),
            child: selected
                ? const Icon(Icons.check, size: 12, color: Colors.white)
                : null,
          ),
        ]),
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({
    required this.icon,
    required this.label,
    required this.description,
    required this.selected,
    required this.onTap,
  });
  final String icon, label, description;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = AppColorScheme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? AppColors.protein.withValues(alpha: 0.1) : cs.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.protein : cs.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(children: [
          Text(icon, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: selected ? AppColors.protein : cs.textPrimary)),
              Text(description,
                  style: TextStyle(fontSize: 12, color: cs.textMuted)),
            ],
          )),
          Container(
            width: 18, height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected ? AppColors.protein : Colors.transparent,
              border: Border.all(
                  color: selected ? AppColors.protein : cs.border, width: 2),
            ),
            child: selected
                ? const Icon(Icons.check, size: 12, color: Colors.white)
                : null,
          ),
        ]),
      ),
    );
  }
}

class _MacroBox extends StatelessWidget {
  const _MacroBox({
    required this.label,
    required this.ctrl,
    required this.unit,
    required this.color,
  });
  final String label, unit;
  final TextEditingController ctrl;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label.toUpperCase(),
              style: TextStyle(
                  fontSize: 9, fontWeight: FontWeight.w700,
                  letterSpacing: 0.8, color: color)),
          TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.zero,
              border: InputBorder.none,
              suffixText: unit,
              suffixStyle: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.7)),
            ),
          ),
        ],
      ),
    );
  }
}
