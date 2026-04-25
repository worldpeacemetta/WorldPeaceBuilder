import '../models/food.dart';

// ---------------------------------------------------------------------------
// computeRecipeTotals — mirrors web app logic exactly.
//
// Ingredient quantities are always in GRAMS on mobile (unlike the web where
// perServing foods are entered in servings).
//
// perServing recipe:
//   returned macros = sum of each ingredient's macros scaled by grams
//   → represents the macros for the entire batch (1 serving)
//
// per100g recipe:
//   returned macros = batch total normalised to per-100g
//   → requires totalSize (total batch weight in grams)
//   → returns MacroValues.zero when totalSize is null / <= 0
// ---------------------------------------------------------------------------
MacroValues computeRecipeTotals({
  required List<({String foodId, double grams})> ingredients,
  required List<Food> foods,
  required String unit,   // 'per100g' | 'perServing'
  double? totalSize,      // required when unit == 'per100g'
}) {
  if (ingredients.isEmpty) return const MacroValues();

  var batch = const MacroValues();
  for (final ing in ingredients) {
    if (ing.grams <= 0) continue;
    final food = foods.where((f) => f.id == ing.foodId).firstOrNull;
    if (food == null) continue;

    // Convert grams → scaling factor relative to the food's stored unit.
    final factor = food.unit == 'per100g'
        ? ing.grams / 100.0
        : ing.grams / (food.servingSize ?? 100.0);

    batch = batch + MacroValues(
      kcal: food.kcal * factor,
      protein: food.protein * factor,
      carbs: food.carbs * factor,
      fat: food.fat * factor,
    );
  }

  if (unit == 'perServing') return batch;

  // per100g: normalise batch to per-100g.
  if (totalSize == null || totalSize <= 0) return const MacroValues();
  final scale = 100.0 / totalSize;
  return MacroValues(
    kcal:    batch.kcal    * scale,
    protein: batch.protein * scale,
    carbs:   batch.carbs   * scale,
    fat:     batch.fat     * scale,
  );
}
