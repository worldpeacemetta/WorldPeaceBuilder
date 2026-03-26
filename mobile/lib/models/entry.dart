import 'food.dart';

class Entry {
  final String id;
  final String date;    // 'YYYY-MM-DD'
  final String foodId;
  final double qty;
  final String meal;    // breakfast | lunch | dinner | snack | other
  final Food? food;     // joined via select('*, food:foods(*)')

  const Entry({
    required this.id,
    required this.date,
    required this.foodId,
    required this.qty,
    required this.meal,
    this.food,
  });

  factory Entry.fromJson(Map<String, dynamic> json) {
    final foodJson = json['food'] as Map<String, dynamic>?;
    return Entry(
      id: json['id'] as String,
      date: (json['date'] as String).substring(0, 10),
      foodId: json['food_id'] as String,
      qty: (json['qty'] as num).toDouble(),
      meal: (json['meal'] as String?) ?? 'other',
      food: foodJson != null ? Food.fromJson(foodJson) : null,
    );
  }

  MacroValues get macros => food?.scaledMacros(qty) ?? const MacroValues();
}

/// Ordered meal keys (matches web app).
const mealOrder = ['breakfast', 'lunch', 'dinner', 'snack', 'other'];

const mealLabels = {
  'breakfast': 'Breakfast',
  'lunch': 'Lunch',
  'dinner': 'Dinner',
  'snack': 'Snack',
  'other': 'Other',
};
