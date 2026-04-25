import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/utils.dart';
import '../models/entry.dart';
import '../models/food.dart';
import 'entries_provider.dart';
import 'settings_provider.dart';

const _kMinLoggedDays = 14;
const _kHistoryDays   = 90;
const _kMaxSuggestions = 3;
const kSmartInsightMealSlots = ['breakfast', 'lunch', 'dinner', 'snack'];

// ---------------------------------------------------------------------------
// Data types
// ---------------------------------------------------------------------------

class InsightItem {
  final Food food;
  final double qty;
  const InsightItem({required this.food, required this.qty});
  MacroValues get macros => food.scaledMacros(qty);
}

class MealInsight {
  final String meal;
  final List<InsightItem> items;
  final MacroValues totalMacros;
  final double score;
  const MealInsight({
    required this.meal,
    required this.items,
    required this.totalMacros,
    required this.score,
  });
}

class SmartInsightResult {
  final bool available;
  final int loggedDays;
  /// Up to 3 suggestions per meal slot, sorted best-first.
  /// Empty list means meal is already logged today or has no history.
  final Map<String, List<MealInsight>> suggestions;

  const SmartInsightResult({
    required this.available,
    required this.loggedDays,
    required this.suggestions,
  });

  static const empty = SmartInsightResult(
    available: false,
    loggedDays: 0,
    suggestions: {},
  );
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final smartInsightProvider = FutureProvider.autoDispose<SmartInsightResult>((ref) async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return SmartInsightResult.empty;

  final today    = todayISO();
  final cutoff   = DateTime.now().subtract(const Duration(days: _kHistoryDays));
  final startISO = _isoDate(cutoff);

  final history = await ref.watch(entriesInRangeProvider(startISO).future);

  // Count distinct logged days, excluding today
  final loggedDays = history
      .where((e) => e.date != today)
      .map((e) => e.date)
      .toSet()
      .length;

  if (loggedDays < _kMinLoggedDays) {
    return SmartInsightResult(
      available: false,
      loggedDays: loggedDays,
      suggestions: const {},
    );
  }

  // Today's already-logged entries (reactive — recomputes when user logs)
  final todayEntries     = ref.watch(entriesProvider(today)).valueOrNull ?? [];
  final loggedMealsToday = todayEntries.map((e) => e.meal).toSet();

  // Remaining macro targets for today
  final settings      = ref.read(settingsProvider);
  final goals         = settings.goalsForDate(today);
  final totals        = MacroValues.sum(todayEntries.map((e) => e.macros));
  final remainKcal    = (goals.kcal    - totals.kcal).clamp(0.0, double.infinity);
  final remainProtein = (goals.protein - totals.protein).clamp(0.0, double.infinity);
  final remainCarbs   = (goals.carbs   - totals.carbs).clamp(0.0, double.infinity);
  final remainFat     = (goals.fat     - totals.fat).clamp(0.0, double.infinity);

  // Build historical combo index: date → meal → entries (exclude today)
  final index = <String, Map<String, List<Entry>>>{};
  for (final e in history.where((e) => e.date != today && e.food != null)) {
    (index[e.date] ??= {})[e.meal] ??= [];
    index[e.date]![e.meal]!.add(e);
  }

  // Find top-3 unique combos per meal slot
  final suggestions = <String, List<MealInsight>>{};

  for (final meal in kSmartInsightMealSlots) {
    if (loggedMealsToday.contains(meal)) {
      suggestions[meal] = const [];
      continue;
    }

    // Score every historical combo
    final scored = <({String key, double score, MealInsight insight})>[];
    for (final dateMap in index.values) {
      final entries = dateMap[meal];
      if (entries == null || entries.isEmpty) continue;

      final items = entries
          .where((e) => e.food != null)
          .map((e) => InsightItem(food: e.food!, qty: e.qty))
          .toList();
      if (items.isEmpty) continue;

      final combo = MacroValues.sum(items.map((i) => i.macros));
      final score = _gapScore(
        combo,
        remainKcal: remainKcal,
        remainProtein: remainProtein,
        remainCarbs: remainCarbs,
        remainFat: remainFat,
      );
      // Dedup key: sorted food IDs (same food set = same combo, regardless of qty)
      final key = (items.map((i) => i.food.id).toList()..sort()).join('|');
      scored.add((key: key, score: score,
          insight: MealInsight(meal: meal, items: items,
              totalMacros: combo, score: score)));
    }

    // Sort descending, keep top-3 unique food sets
    scored.sort((a, b) => b.score.compareTo(a.score));
    final seen  = <String>{};
    final top3  = <MealInsight>[];
    for (final s in scored) {
      if (seen.add(s.key)) {
        top3.add(s.insight);
        if (top3.length >= _kMaxSuggestions) break;
      }
    }
    suggestions[meal] = top3;
  }

  final hasAnySuggestion = suggestions.values.any((v) => v.isNotEmpty);
  return SmartInsightResult(
    available: hasAnySuggestion,
    loggedDays: loggedDays,
    suggestions: suggestions,
  );
});

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

String _isoDate(DateTime dt) =>
    '${dt.year.toString().padLeft(4, '0')}-'
    '${dt.month.toString().padLeft(2, '0')}-'
    '${dt.day.toString().padLeft(2, '0')}';

// Gap-closing score: higher is better.
// Protein weighted 2×, kcal 1×, carbs + fat 0.8× each.
// Overshoot penalised at 50% of the excess ratio.
double _gapScore(
  MacroValues combo, {
  required double remainKcal,
  required double remainProtein,
  required double remainCarbs,
  required double remainFat,
}) {
  double score  = 0;
  double weight = 0;

  void add(double val, double remain, double w) {
    if (remain <= 0) return;
    final fill = (val / remain).clamp(0.0, 1.0);
    final over = val > remain ? (val - remain) / remain * 0.5 : 0.0;
    score  += (fill - over) * w;
    weight += w;
  }

  add(combo.protein, remainProtein, 2.0);
  add(combo.kcal,    remainKcal,    1.0);
  add(combo.carbs,   remainCarbs,   0.8);
  add(combo.fat,     remainFat,     0.8);

  return weight > 0 ? score / weight : 0.0;
}
