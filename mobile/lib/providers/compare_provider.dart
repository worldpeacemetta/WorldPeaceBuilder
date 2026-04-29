import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/food.dart';

class CompareNotifier extends StateNotifier<List<Food>> {
  CompareNotifier() : super([]);

  static const maxFoods = 3;

  bool contains(String foodId) => state.any((f) => f.id == foodId);

  void toggle(Food food) {
    if (contains(food.id)) {
      state = state.where((f) => f.id != food.id).toList();
    } else if (state.length < maxFoods) {
      state = [...state, food];
    }
  }

  void remove(String foodId) {
    state = state.where((f) => f.id != foodId).toList();
  }

  void clear() => state = [];
}

final compareProvider =
    StateNotifierProvider<CompareNotifier, List<Food>>(
  (ref) => CompareNotifier(),
);
