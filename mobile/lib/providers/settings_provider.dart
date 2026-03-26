import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/food.dart';

const _kSettings = 'mt_settings_mobile';

// ---------------------------------------------------------------------------
// MacroGoals — goals for a single day type.
// ---------------------------------------------------------------------------
class MacroGoals {
  final double kcal;
  final double protein;
  final double carbs;
  final double fat;

  const MacroGoals({
    this.kcal = 2000,
    this.protein = 150,
    this.carbs = 200,
    this.fat = 70,
  });

  factory MacroGoals.fromJson(Map<String, dynamic> j) => MacroGoals(
    kcal: (j['kcal'] as num?)?.toDouble() ?? 2000,
    protein: (j['protein'] as num?)?.toDouble() ?? 150,
    carbs: (j['carbs'] as num?)?.toDouble() ?? 200,
    fat: (j['fat'] as num?)?.toDouble() ?? 70,
  );

  Map<String, dynamic> toJson() => {
    'kcal': kcal, 'protein': protein, 'carbs': carbs, 'fat': fat,
  };

  MacroValues toMacroValues() =>
      MacroValues(kcal: kcal, protein: protein, carbs: carbs, fat: fat);
}

// ---------------------------------------------------------------------------
// BodyStats
// ---------------------------------------------------------------------------
class BodyStats {
  final int? age;
  final String sex;           // male | female | other
  final double? heightCm;
  final double? weightKg;
  final double? bodyFatPct;
  final String activity;      // sedentary | light | moderate | active | very_active

  const BodyStats({
    this.age,
    this.sex = 'other',
    this.heightCm,
    this.weightKg,
    this.bodyFatPct,
    this.activity = 'moderate',
  });

  factory BodyStats.fromJson(Map<String, dynamic> j) => BodyStats(
    age:        (j['age'] as num?)?.toInt(),
    sex:        (j['sex'] as String?) ?? 'other',
    heightCm:   (j['heightCm'] as num?)?.toDouble(),
    weightKg:   (j['weightKg'] as num?)?.toDouble(),
    bodyFatPct: (j['bodyFatPct'] as num?)?.toDouble(),
    activity:   (j['activity'] as String?) ?? 'moderate',
  );

  Map<String, dynamic> toJson() => {
    'age': age, 'sex': sex, 'heightCm': heightCm,
    'weightKg': weightKg, 'bodyFatPct': bodyFatPct, 'activity': activity,
  };

  BodyStats copyWith({
    int? age, String? sex, double? heightCm,
    double? weightKg, double? bodyFatPct, String? activity,
  }) => BodyStats(
    age: age ?? this.age, sex: sex ?? this.sex,
    heightCm: heightCm ?? this.heightCm, weightKg: weightKg ?? this.weightKg,
    bodyFatPct: bodyFatPct ?? this.bodyFatPct, activity: activity ?? this.activity,
  );
}

// ---------------------------------------------------------------------------
// WeightEntry — one entry in the weight history log.
// ---------------------------------------------------------------------------
class WeightEntry {
  final String date;    // YYYY-MM-DD
  final double weight;
  final double? bodyFat;

  const WeightEntry({required this.date, required this.weight, this.bodyFat});

  factory WeightEntry.fromJson(Map<String, dynamic> j) => WeightEntry(
    date:    j['date'] as String,
    weight:  (j['weight'] as num).toDouble(),
    bodyFat: (j['bodyFat'] as num?)?.toDouble(),
  );

  Map<String, dynamic> toJson() =>
      {'date': date, 'weight': weight, 'bodyFat': bodyFat};
}

// ---------------------------------------------------------------------------
// Settings model
// ---------------------------------------------------------------------------
class AppSettings {
  final String setupMode;         // dual | bulking | cutting | maintenance
  final String dualProfile;       // train | rest (only relevant when setupMode==dual)
  final MacroGoals dualTrainGoals;
  final MacroGoals dualRestGoals;
  final MacroGoals bulkingGoals;
  final MacroGoals cuttingGoals;
  final MacroGoals maintenanceGoals;
  final String theme;             // system | light | dark
  final String language;          // en | fr | es | de | pt | it | nl | ja | zh
  final BodyStats bodyStats;
  final List<WeightEntry> weightHistory;
  // Per-date goal overrides — mirrors web app's daily_macro_goals.byDate
  // Key: ISO date string, Value: {setup, profile}
  final Map<String, Map<String, String>> goalSchedule;

  const AppSettings({
    this.setupMode = 'maintenance',
    this.dualProfile = 'train',
    this.dualTrainGoals = const MacroGoals(kcal: 2500, protein: 180, carbs: 250, fat: 80),
    this.dualRestGoals  = const MacroGoals(kcal: 2000, protein: 160, carbs: 200, fat: 65),
    this.bulkingGoals   = const MacroGoals(kcal: 3000, protein: 200, carbs: 320, fat: 90),
    this.cuttingGoals   = const MacroGoals(kcal: 1600, protein: 180, carbs: 130, fat: 55),
    this.maintenanceGoals = const MacroGoals(),
    this.theme = 'dark',
    this.language = 'en',
    this.bodyStats = const BodyStats(),
    this.weightHistory = const [],
    this.goalSchedule = const {},
  });

  MacroGoals get activeGoals {
    switch (setupMode) {
      case 'dual':
        return dualProfile == 'rest' ? dualRestGoals : dualTrainGoals;
      case 'bulking':      return bulkingGoals;
      case 'cutting':      return cuttingGoals;
      default:             return maintenanceGoals;
    }
  }

  /// Returns the correct goals for a specific date, honouring per-date
  /// overrides stored in goalSchedule (mirrors web app's resolveModeEntry).
  MacroGoals goalsForDate(String isoDate) {
    // 1. Direct override for this exact date.
    var entry = goalSchedule[isoDate];
    // 2. Most-recent override on or before this date.
    if (entry == null && goalSchedule.isNotEmpty) {
      final sorted = goalSchedule.keys.toList()..sort();
      for (int i = sorted.length - 1; i >= 0; i--) {
        if (sorted[i].compareTo(isoDate) <= 0) {
          entry = goalSchedule[sorted[i]];
          break;
        }
      }
    }
    if (entry == null) return activeGoals;
    final setup   = entry['setup']   ?? setupMode;
    final profile = entry['profile'] ?? dualProfile;
    switch (setup) {
      case 'dual':
        return profile == 'rest' ? dualRestGoals : dualTrainGoals;
      case 'bulking':   return bulkingGoals;
      case 'cutting':   return cuttingGoals;
      default:          return maintenanceGoals;
    }
  }

  factory AppSettings.fromJson(Map<String, dynamic> j) => AppSettings(
    setupMode: (j['setupMode'] as String?) ?? 'maintenance',
    dualProfile: (j['dualProfile'] as String?) ?? 'train',
    dualTrainGoals: MacroGoals.fromJson((j['dualTrainGoals'] as Map?)?.cast() ?? {}),
    dualRestGoals : MacroGoals.fromJson((j['dualRestGoals']  as Map?)?.cast() ?? {}),
    bulkingGoals  : MacroGoals.fromJson((j['bulkingGoals']   as Map?)?.cast() ?? {}),
    cuttingGoals  : MacroGoals.fromJson((j['cuttingGoals']   as Map?)?.cast() ?? {}),
    maintenanceGoals: MacroGoals.fromJson((j['maintenanceGoals'] as Map?)?.cast() ?? {}),
    theme   : (j['theme'] as String?) ?? 'dark',
    language: (j['language'] as String?) ?? 'en',
    bodyStats: j['bodyStats'] != null
        ? BodyStats.fromJson((j['bodyStats'] as Map).cast())
        : const BodyStats(),
    weightHistory: (j['weightHistory'] as List?)
        ?.map((e) => WeightEntry.fromJson((e as Map).cast()))
        .toList() ?? [],
    goalSchedule: (j['goalSchedule'] as Map?)?.map(
      (k, v) => MapEntry(k as String, (v as Map).cast<String, String>()),
    ) ?? {},
  );

  Map<String, dynamic> toJson() => {
    'setupMode': setupMode,
    'dualProfile': dualProfile,
    'dualTrainGoals': dualTrainGoals.toJson(),
    'dualRestGoals' : dualRestGoals.toJson(),
    'bulkingGoals'  : bulkingGoals.toJson(),
    'cuttingGoals'  : cuttingGoals.toJson(),
    'maintenanceGoals': maintenanceGoals.toJson(),
    'theme'   : theme,
    'language': language,
    'bodyStats': bodyStats.toJson(),
    'weightHistory': weightHistory.map((e) => e.toJson()).toList(),
    'goalSchedule': goalSchedule,
  };

  AppSettings copyWith({
    String? setupMode,
    String? dualProfile,
    MacroGoals? dualTrainGoals,
    MacroGoals? dualRestGoals,
    MacroGoals? bulkingGoals,
    MacroGoals? cuttingGoals,
    MacroGoals? maintenanceGoals,
    String? theme,
    String? language,
    BodyStats? bodyStats,
    List<WeightEntry>? weightHistory,
    Map<String, Map<String, String>>? goalSchedule,
  }) => AppSettings(
    setupMode: setupMode ?? this.setupMode,
    dualProfile: dualProfile ?? this.dualProfile,
    dualTrainGoals: dualTrainGoals ?? this.dualTrainGoals,
    dualRestGoals : dualRestGoals  ?? this.dualRestGoals,
    bulkingGoals  : bulkingGoals   ?? this.bulkingGoals,
    cuttingGoals  : cuttingGoals   ?? this.cuttingGoals,
    maintenanceGoals: maintenanceGoals ?? this.maintenanceGoals,
    theme        : theme         ?? this.theme,
    language     : language      ?? this.language,
    bodyStats    : bodyStats     ?? this.bodyStats,
    weightHistory: weightHistory ?? this.weightHistory,
    goalSchedule : goalSchedule  ?? this.goalSchedule,
  );
}

// ---------------------------------------------------------------------------
// SettingsNotifier
// ---------------------------------------------------------------------------
class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier() : super(const AppSettings()) {
    _load();
  }

  Future<void> _load() async {
    // 1. Load from local cache first (instant, offline-safe).
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kSettings);
    if (raw != null) {
      try {
        state = AppSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {}
    }
    // 2. Then pull from Supabase (overrides local if present).
    await _loadFromSupabase();
  }

  /// Fetch all synced fields from the user_profile table.
  /// Web app uses user_profile (not profiles) for goals + body stats.
  Future<void> _loadFromSupabase() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      final row = await Supabase.instance.client
          .from('user_profile')
          .select('daily_macro_goals, age, sex, height, weight, body_fat, activity_level, profile_history')
          .eq('id', user.id)
          .maybeSingle();
      if (row == null) return;

      // Preserve language (mobile-only, not stored in web app).
      final currentLanguage = state.language;
      final currentTheme    = state.theme;

      // Goals + mode from daily_macro_goals JSONB.
      AppSettings updated = state;
      final goalsJson = row['daily_macro_goals'];
      if (goalsJson != null) {
        updated = _settingsFromSupabase(goalsJson as Map<String, dynamic>)
            .copyWith(language: currentLanguage, theme: currentTheme);
      }

      // Body stats from individual columns.
      updated = updated.copyWith(
        bodyStats: BodyStats(
          age:        (row['age']          as num?)?.toInt(),
          sex:        (row['sex']          as String?) ?? updated.bodyStats.sex,
          heightCm:   (row['height']       as num?)?.toDouble(),
          weightKg:   (row['weight']       as num?)?.toDouble(),
          bodyFatPct: (row['body_fat']     as num?)?.toDouble(),
          activity:   (row['activity_level'] as String?) ?? updated.bodyStats.activity,
        ),
      );

      // Weight history from profile_history JSONB array.
      final historyJson = row['profile_history'];
      if (historyJson is List && historyJson.isNotEmpty) {
        try {
          updated = updated.copyWith(
            weightHistory: historyJson
                .map((e) => WeightEntry.fromJson((e as Map).cast()))
                .toList(),
          );
        } catch (_) {}
      }

      state = updated;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kSettings, jsonEncode(state.toJson()));
    } catch (_) {}
  }

  /// Call after sign-in to pull everything from the server.
  Future<void> syncFromSupabase() => _loadFromSupabase();

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSettings, jsonEncode(state.toJson()));
  }

  Future<void> _saveToSupabase() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      final b = state.bodyStats;
      final history = state.weightHistory.map((e) => e.toJson()).toList();
      await Supabase.instance.client.from('user_profile').upsert({
        'id':               user.id,
        'daily_macro_goals': _settingsToSupabase(state),
        'age':              b.age,
        'sex':              b.sex,
        'height':           b.heightCm,
        'weight':           b.weightKg,
        'body_fat':         b.bodyFatPct,
        'activity_level':   b.activity,
        'profile_history':  history,
        'updated_at':       DateTime.now().toIso8601String(),
      });
    } catch (_) {}
  }

  Future<void> update(AppSettings updated) async {
    state = updated;
    await _save();
    await _saveToSupabase();
  }

  // -------------------------------------------------------------------------
  // Mapping between mobile AppSettings ↔ web app daily_macro_goals schema.
  // Web schema: { setup, dual: { train, rest, active }, bulking, cutting, maintenance }
  // -------------------------------------------------------------------------
  static MacroGoals _goalsFromJson(dynamic json) {
    if (json is! Map) return const MacroGoals();
    final m = json.cast<String, dynamic>();
    return MacroGoals(
      kcal:    (m['kcal']    as num?)?.toDouble() ?? 2000,
      protein: (m['protein'] as num?)?.toDouble() ?? 150,
      carbs:   (m['carbs']   as num?)?.toDouble() ?? 200,
      fat:     (m['fat']     as num?)?.toDouble() ?? 70,
    );
  }

  static AppSettings _settingsFromSupabase(Map<String, dynamic> g) {
    final dual = g['dual'] as Map?;
    // Parse byDate overrides: { "2026-03-20": { setup: "dual", profile: "rest" } }
    final byDate = g['byDate'] as Map?;
    final goalSchedule = <String, Map<String, String>>{};
    if (byDate != null) {
      byDate.forEach((k, v) {
        if (v is Map) {
          goalSchedule[k as String] = (v).map(
            (ek, ev) => MapEntry(ek.toString(), ev.toString()),
          );
        }
      });
    }
    return AppSettings(
      setupMode:        (g['setup'] as String?) ?? 'maintenance',
      dualProfile:      (dual?['active'] as String?) ?? 'train',
      dualTrainGoals:   _goalsFromJson(dual?['train']),
      dualRestGoals:    _goalsFromJson(dual?['rest'] ?? dual?['train']),
      bulkingGoals:     _goalsFromJson(g['bulking']),
      cuttingGoals:     _goalsFromJson(g['cutting']),
      maintenanceGoals: _goalsFromJson(g['maintenance']),
      goalSchedule:     goalSchedule,
    );
  }

  static Map<String, dynamic> _settingsToSupabase(AppSettings s) => {
    'setup': s.setupMode,
    'dual': {
      'train':  s.dualTrainGoals.toJson(),
      'rest':   s.dualRestGoals.toJson(),
      'active': s.dualProfile,
    },
    'bulking':      s.bulkingGoals.toJson(),
    'cutting':      s.cuttingGoals.toJson(),
    'maintenance':  s.maintenanceGoals.toJson(),
  };
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>(
  (_) => SettingsNotifier(),
);

// ---------------------------------------------------------------------------
// ThemeMode derived from settings.
// ---------------------------------------------------------------------------
final themeModeProvider = Provider<ThemeMode>((ref) {
  final theme = ref.watch(settingsProvider).theme;
  switch (theme) {
    case 'light': return ThemeMode.light;
    case 'dark' : return ThemeMode.dark;
    default     : return ThemeMode.system;
  }
});
