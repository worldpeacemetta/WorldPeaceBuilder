import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  const AppSettings({
    this.setupMode = 'maintenance',
    this.dualProfile = 'train',
    this.dualTrainGoals = const MacroGoals(kcal: 2500, protein: 180, carbs: 250, fat: 80),
    this.dualRestGoals  = const MacroGoals(kcal: 2000, protein: 160, carbs: 200, fat: 65),
    this.bulkingGoals   = const MacroGoals(kcal: 3000, protein: 200, carbs: 320, fat: 90),
    this.cuttingGoals   = const MacroGoals(kcal: 1600, protein: 180, carbs: 130, fat: 55),
    this.maintenanceGoals = const MacroGoals(),
    this.theme = 'dark',
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

  factory AppSettings.fromJson(Map<String, dynamic> j) => AppSettings(
    setupMode: (j['setupMode'] as String?) ?? 'maintenance',
    dualProfile: (j['dualProfile'] as String?) ?? 'train',
    dualTrainGoals: MacroGoals.fromJson((j['dualTrainGoals'] as Map?)?.cast() ?? {}),
    dualRestGoals : MacroGoals.fromJson((j['dualRestGoals']  as Map?)?.cast() ?? {}),
    bulkingGoals  : MacroGoals.fromJson((j['bulkingGoals']   as Map?)?.cast() ?? {}),
    cuttingGoals  : MacroGoals.fromJson((j['cuttingGoals']   as Map?)?.cast() ?? {}),
    maintenanceGoals: MacroGoals.fromJson((j['maintenanceGoals'] as Map?)?.cast() ?? {}),
    theme: (j['theme'] as String?) ?? 'dark',
  );

  Map<String, dynamic> toJson() => {
    'setupMode': setupMode,
    'dualProfile': dualProfile,
    'dualTrainGoals': dualTrainGoals.toJson(),
    'dualRestGoals' : dualRestGoals.toJson(),
    'bulkingGoals'  : bulkingGoals.toJson(),
    'cuttingGoals'  : cuttingGoals.toJson(),
    'maintenanceGoals': maintenanceGoals.toJson(),
    'theme': theme,
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
  }) => AppSettings(
    setupMode: setupMode ?? this.setupMode,
    dualProfile: dualProfile ?? this.dualProfile,
    dualTrainGoals: dualTrainGoals ?? this.dualTrainGoals,
    dualRestGoals : dualRestGoals  ?? this.dualRestGoals,
    bulkingGoals  : bulkingGoals   ?? this.bulkingGoals,
    cuttingGoals  : cuttingGoals   ?? this.cuttingGoals,
    maintenanceGoals: maintenanceGoals ?? this.maintenanceGoals,
    theme: theme ?? this.theme,
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
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kSettings);
    if (raw != null) {
      try {
        state = AppSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {}
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSettings, jsonEncode(state.toJson()));
  }

  Future<void> update(AppSettings updated) async {
    state = updated;
    await _save();
  }
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
