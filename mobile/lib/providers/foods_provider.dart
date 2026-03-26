import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/food.dart';

final _supabase = Supabase.instance.client;

// ---------------------------------------------------------------------------
// Foods list notifier — loads all user foods, supports CRUD.
// ---------------------------------------------------------------------------
class FoodsNotifier extends StateNotifier<AsyncValue<List<Food>>> {
  FoodsNotifier() : super(const AsyncValue.loading()) {
    fetch();
  }

  Future<void> fetch() async {
    state = const AsyncValue.loading();
    try {
      final data = await _supabase
          .from('foods')
          .select()
          .order('name');
      state = AsyncValue.data(
        (data as List).map((j) => Food.fromJson(j as Map<String, dynamic>)).toList(),
      );
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<Food?> addFood(Map<String, dynamic> insertData) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return null;
    try {
      final row = await _supabase
          .from('foods')
          .insert({...insertData, 'user_id': userId})
          .select()
          .single();
      final food = Food.fromJson(row as Map<String, dynamic>);
      state = state.whenData((list) => [...list, food]
        ..sort((a, b) => a.name.compareTo(b.name)));
      return food;
    } catch (_) {
      return null;
    }
  }

  Future<bool> updateFood(String id, Map<String, dynamic> updates) async {
    try {
      final row = await _supabase
          .from('foods')
          .update(updates)
          .eq('id', id)
          .select()
          .single();
      final updated = Food.fromJson(row as Map<String, dynamic>);
      state = state.whenData(
        (list) => list.map((f) => f.id == id ? updated : f).toList(),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteFood(String id) async {
    try {
      await _supabase.from('foods').delete().eq('id', id);
      state = state.whenData((list) => list.where((f) => f.id != id).toList());
      return true;
    } catch (_) {
      return false;
    }
  }
}

final foodsProvider =
    StateNotifierProvider<FoodsNotifier, AsyncValue<List<Food>>>(
  (_) => FoodsNotifier(),
);

/// Convenience: foods as a flat list (empty while loading).
final foodListProvider = Provider<List<Food>>((ref) {
  return ref.watch(foodsProvider).valueOrNull ?? [];
});

/// Lookup food by id.
final foodByIdProvider = Provider.family<Food?, String>((ref, id) {
  return ref.watch(foodListProvider).where((f) => f.id == id).firstOrNull;
});
