import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/utils.dart';
import '../models/entry.dart';
import '../models/food.dart';
import 'badges_provider.dart';
import 'date_provider.dart';
import 'log_history_provider.dart';

final _supabase = Supabase.instance.client;

// ---------------------------------------------------------------------------
// All entries from startDate (inclusive) to today.
// Used by the Avg per Meal dashboard KPI.
// ---------------------------------------------------------------------------
final entriesInRangeProvider =
    FutureProvider.autoDispose.family<List<Entry>, String>((ref, startDate) async {
  final user = _supabase.auth.currentUser;
  if (user == null) return [];
  final today = todayISO();
  final data = await _supabase
      .from('entries')
      .select('*, food:foods(*)')
      .gte('date', startDate)
      .lte('date', today)
      .order('date');
  return (data as List)
      .map((j) => Entry.fromJson(j as Map<String, dynamic>))
      .toList();
});

// ---------------------------------------------------------------------------
// Entries for a specific date.
// ---------------------------------------------------------------------------
class EntriesNotifier extends StateNotifier<AsyncValue<List<Entry>>> {
  EntriesNotifier(this._date, this._ref) : super(const AsyncValue.loading()) {
    fetch();
  }

  final String _date;
  final Ref _ref;

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
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return false;
    try {
      final row = await _supabase
          .from('entries')
          .insert({
            'user_id': userId,
            'date': _date,
            'food_id': foodId,
            'qty': qty,
            'meal': meal,
          })
          .select('*, food:foods(*)')
          .single();
      final entry = Entry.fromJson(row as Map<String, dynamic>);
      state = state.whenData((list) => [...list, entry]);
      _ref.invalidate(loggedDatesProvider);
      // Recompute badges so milestones like "First Step" trigger immediately.
      _ref.read(badgesProvider.notifier).recompute();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateEntry(String id, {double? qty, String? meal}) async {
    try {
      final updates = <String, dynamic>{};
      if (qty != null) updates['qty'] = qty;
      if (meal != null) updates['meal'] = meal;
      if (updates.isEmpty) return true;
      final row = await _supabase
          .from('entries')
          .update(updates)
          .eq('id', id)
          .select('*, food:foods(*)')
          .single();
      final updated = Entry.fromJson(row as Map<String, dynamic>);
      state = state.whenData(
        (list) => list.map((e) => e.id == id ? updated : e).toList(),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteEntry(String id) async {
    // Optimistic update: remove immediately so the tile cannot re-appear
    // during the async Supabase round-trip if something else triggers a rebuild.
    final prev = state;
    state = state.whenData((list) => list.where((e) => e.id != id).toList());
    _ref.invalidate(loggedDatesProvider);
    try {
      await _supabase.from('entries').delete().eq('id', id);
      _ref.read(badgesProvider.notifier).recompute();
      return true;
    } catch (_) {
      state = prev; // rollback on network failure
      return false;
    }
  }
}

final entriesProvider = StateNotifierProvider.family<
    EntriesNotifier, AsyncValue<List<Entry>>, String>(
  (ref, date) => EntriesNotifier(date, ref),
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
