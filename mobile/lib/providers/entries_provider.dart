import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/entry.dart';
import '../models/food.dart';
import 'date_provider.dart';

final _supabase = Supabase.instance.client;

// ---------------------------------------------------------------------------
// Entries for a specific date.
// ---------------------------------------------------------------------------
class EntriesNotifier extends StateNotifier<AsyncValue<List<Entry>>> {
  EntriesNotifier(this._date) : super(const AsyncValue.loading()) {
    fetch();
  }

  final String _date;

  Future<void> fetch() async {
    state = const AsyncValue.loading();
    try {
      final data = await _supabase
          .from('entries')
          .select('*, food:foods(*)')
          .eq('date', _date)
          .order('created_at');
      state = AsyncValue.data(
        (data as List).map((j) => Entry.fromJson(j as Map<String, dynamic>)).toList(),
      );
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<bool> addEntry({
    required String foodId,
    required double qty,
    required String meal,
  }) async {
    try {
      final row = await _supabase
          .from('entries')
          .insert({
            'date': _date,
            'food_id': foodId,
            'qty': qty,
            'meal': meal,
          })
          .select('*, food:foods(*)')
          .single();
      final entry = Entry.fromJson(row as Map<String, dynamic>);
      state = state.whenData((list) => [...list, entry]);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteEntry(String id) async {
    try {
      await _supabase.from('entries').delete().eq('id', id);
      state = state.whenData((list) => list.where((e) => e.id != id).toList());
      return true;
    } catch (_) {
      return false;
    }
  }
}

final entriesProvider = StateNotifierProvider.family<
    EntriesNotifier, AsyncValue<List<Entry>>, String>(
  (ref, date) => EntriesNotifier(date),
);

// ---------------------------------------------------------------------------
// Current log-date entries (uses logDateProvider).
// ---------------------------------------------------------------------------
final logEntriesProvider = Provider<AsyncValue<List<Entry>>>((ref) {
  final date = ref.watch(logDateProvider);
  return ref.watch(entriesProvider(date));
});

// ---------------------------------------------------------------------------
// Macro totals for a date.
// ---------------------------------------------------------------------------
final macroTotalsProvider = Provider.family<MacroValues, String>((ref, date) {
  final entries = ref.watch(entriesProvider(date)).valueOrNull ?? [];
  return MacroValues.sum(entries.map((e) => e.macros));
});

/// Entries for log date grouped by meal.
final logEntriesByMealProvider =
    Provider<Map<String, List<Entry>>>((ref) {
  final entries = ref.watch(logEntriesProvider).valueOrNull ?? [];
  final grouped = <String, List<Entry>>{};
  for (final meal in mealOrder) {
    final items = entries.where((e) => e.meal == meal).toList();
    if (items.isNotEmpty) grouped[meal] = items;
  }
  return grouped;
});
