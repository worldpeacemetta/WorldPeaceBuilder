import '../models/food.dart';

// Gap-closing score: higher is better.
// Protein weighted 2×, kcal 1×, carbs + fat 0.8× each.
// Overshoot penalised at 50% of the excess ratio.
double gapScore(
  MacroValues combo, {
  required double remainKcal,
  required double remainProtein,
  required double remainCarbs,
  required double remainFat,
}) {
  double score = 0;
  double weight = 0;

  void add(double val, double remain, double w) {
    if (remain <= 0) return;
    final fill = (val / remain).clamp(0.0, 1.0);
    final over = val > remain ? (val - remain) / remain * 0.5 : 0.0;
    score += (fill - over) * w;
    weight += w;
  }

  add(combo.protein, remainProtein, 2.0);
  add(combo.kcal, remainKcal, 1.0);
  add(combo.carbs, remainCarbs, 0.8);
  add(combo.fat, remainFat, 0.8);

  return weight > 0 ? score / weight : 0.0;
}
