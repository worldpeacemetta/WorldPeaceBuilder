import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// BadgeShape
// ---------------------------------------------------------------------------
enum BadgeShape { rounded, hexagon, circle, octagon, shield, star }

// ---------------------------------------------------------------------------
// BadgeDef
// ---------------------------------------------------------------------------
class BadgeDef {
  final int id;
  final String stringId;
  final String name;
  final String desc;
  final String category;
  final BadgeShape shape;
  final Color colorStart;
  final Color colorEnd;
  /// Icon key matching the web app's BadgeIcon component (AchievementBadges.tsx)
  final String icon;
  final Color accent;

  const BadgeDef({
    required this.id,
    required this.stringId,
    required this.name,
    required this.desc,
    required this.category,
    required this.shape,
    required this.colorStart,
    required this.colorEnd,
    required this.icon,
    required this.accent,
  });
}

// ---------------------------------------------------------------------------
// All badge definitions — mirrors web app BADGES array (AchievementBadges.tsx)
// ---------------------------------------------------------------------------
const kBadges = <BadgeDef>[
  // Logging Streaks
  BadgeDef(id: 1,  stringId: 'log_streak_7',   name: 'Week Logger',        desc: 'Log food 7 days in a row',              category: 'Logging Streaks',    shape: BadgeShape.rounded,  colorStart: Color(0xFFFF6B35), colorEnd: Color(0xFFFF9F1C), icon: 'calendar7',    accent: Color(0xFFFFF3E0)),
  BadgeDef(id: 2,  stringId: 'log_streak_14',  name: 'Fortnight Logger',   desc: 'Log food 14 days in a row',             category: 'Logging Streaks',    shape: BadgeShape.rounded,  colorStart: Color(0xFFE8553D), colorEnd: Color(0xFFFF6B35), icon: 'calendar14',   accent: Color(0xFFFFE0D0)),
  BadgeDef(id: 3,  stringId: 'log_streak_30',  name: 'Monthly Logger',     desc: 'Log food 30 days in a row',             category: 'Logging Streaks',    shape: BadgeShape.rounded,  colorStart: Color(0xFFC62828), colorEnd: Color(0xFFE53935), icon: 'calendar30',   accent: Color(0xFFFFCDD2)),
  BadgeDef(id: 4,  stringId: 'log_streak_90',  name: 'Quarterly Logger',   desc: 'Log food 90 days in a row',             category: 'Logging Streaks',    shape: BadgeShape.rounded,  colorStart: Color(0xFF880E4F), colorEnd: Color(0xFFC2185B), icon: 'calendar90',   accent: Color(0xFFF8BBD0)),
  // Protein Streaks
  BadgeDef(id: 5,  stringId: 'protein_streak_7',  name: 'Protein Week',      desc: 'Hit protein goal 7 days in a row',   category: 'Protein Streaks',    shape: BadgeShape.hexagon,  colorStart: Color(0xFF7B1FA2), colorEnd: Color(0xFFAB47BC), icon: 'muscle7',      accent: Color(0xFFE1BEE7)),
  BadgeDef(id: 6,  stringId: 'protein_streak_14', name: 'Protein Fortnight', desc: 'Hit protein goal 14 days in a row',  category: 'Protein Streaks',    shape: BadgeShape.hexagon,  colorStart: Color(0xFF6A1B9A), colorEnd: Color(0xFF8E24AA), icon: 'muscle14',     accent: Color(0xFFCE93D8)),
  BadgeDef(id: 7,  stringId: 'protein_streak_30', name: 'Protein Month',     desc: 'Hit protein goal 30 days in a row',  category: 'Protein Streaks',    shape: BadgeShape.hexagon,  colorStart: Color(0xFF4A148C), colorEnd: Color(0xFF7B1FA2), icon: 'muscle30',     accent: Color(0xFFBA68C8)),
  BadgeDef(id: 8,  stringId: 'protein_streak_90', name: 'Protein Quarter',   desc: 'Hit protein goal 90 days in a row',  category: 'Protein Streaks',    shape: BadgeShape.hexagon,  colorStart: Color(0xFF311B92), colorEnd: Color(0xFF5E35B1), icon: 'muscle90',     accent: Color(0xFF9575CD)),
  // Special
  BadgeDef(id: 10, stringId: 'veggie_streak_7',   name: 'Green Week',        desc: 'Log a veggie & fruit daily, 7 days', category: 'Special',            shape: BadgeShape.shield,   colorStart: Color(0xFF2E7D32), colorEnd: Color(0xFF43A047), icon: 'greenweek',    accent: Color(0xFFC8E6C9)),
  // Logging Milestones
  BadgeDef(id: 11, stringId: 'log_first',      name: 'First Step',        desc: 'Log your first food',                    category: 'Logging Milestones', shape: BadgeShape.circle,   colorStart: Color(0xFF00897B), colorEnd: Color(0xFF26A69A), icon: 'footprint',    accent: Color(0xFFB2DFDB)),
  BadgeDef(id: 12, stringId: 'log_days_10',    name: '10 Days Logged',    desc: 'Log food on 10 different days',          category: 'Logging Milestones', shape: BadgeShape.circle,   colorStart: Color(0xFF00796B), colorEnd: Color(0xFF00897B), icon: 'num10',        accent: Color(0xFFB2DFDB)),
  BadgeDef(id: 13, stringId: 'log_days_30',    name: '30 Days Logged',    desc: 'Log food on 30 different days',          category: 'Logging Milestones', shape: BadgeShape.circle,   colorStart: Color(0xFF00695C), colorEnd: Color(0xFF00796B), icon: 'num30',        accent: Color(0xFF80CBC4)),
  BadgeDef(id: 14, stringId: 'log_days_100',   name: '100 Days Logged',   desc: 'Log food on 100 different days',         category: 'Logging Milestones', shape: BadgeShape.circle,   colorStart: Color(0xFF004D40), colorEnd: Color(0xFF00695C), icon: 'num100',       accent: Color(0xFF4DB6AC)),
  // Protein Milestones
  BadgeDef(id: 15, stringId: 'protein_first',    name: 'Protein Hit',        desc: 'Reach protein goal for the first time', category: 'Protein Milestones', shape: BadgeShape.octagon, colorStart: Color(0xFF1565C0), colorEnd: Color(0xFF1E88E5), icon: 'proteinFirst', accent: Color(0xFFBBDEFB)),
  BadgeDef(id: 16, stringId: 'protein_hits_10',  name: '10 Protein Days',    desc: 'Hit protein goal on 10 days',          category: 'Protein Milestones', shape: BadgeShape.octagon, colorStart: Color(0xFF0D47A1), colorEnd: Color(0xFF1565C0), icon: 'protein10',    accent: Color(0xFF90CAF9)),
  BadgeDef(id: 17, stringId: 'protein_hits_20',  name: '20 Protein Days',    desc: 'Hit protein goal on 20 days',          category: 'Protein Milestones', shape: BadgeShape.octagon, colorStart: Color(0xFF0D47A1), colorEnd: Color(0xFF1565C0), icon: 'protein20',    accent: Color(0xFF90CAF9)),
  BadgeDef(id: 18, stringId: 'protein_hits_50',  name: '50 Protein Days',    desc: 'Hit protein goal on 50 days',          category: 'Protein Milestones', shape: BadgeShape.octagon, colorStart: Color(0xFF1A237E), colorEnd: Color(0xFF283593), icon: 'protein50',    accent: Color(0xFF7986CB)),
  BadgeDef(id: 19, stringId: 'protein_hits_100', name: '100 Protein Days',   desc: 'Hit protein goal on 100 days',         category: 'Protein Milestones', shape: BadgeShape.octagon, colorStart: Color(0xFF0D1B5E), colorEnd: Color(0xFF1A237E), icon: 'protein100',   accent: Color(0xFF5C6BC0)),
  // Perfect Days
  BadgeDef(id: 20, stringId: 'perfect_day_1',  name: 'Perfect Day',    desc: 'All macros in range on the same day', category: 'Perfect Days', shape: BadgeShape.star, colorStart: Color(0xFFF9A825), colorEnd: Color(0xFFFDD835), icon: 'perfectStar',  accent: Color(0xFFFFF9C4)),
  BadgeDef(id: 21, stringId: 'perfect_day_3',  name: 'Hat Trick',      desc: '3 perfect days',                      category: 'Perfect Days', shape: BadgeShape.star, colorStart: Color(0xFFF57F17), colorEnd: Color(0xFFF9A825), icon: 'hatTrick',     accent: Color(0xFFFFF176)),
  BadgeDef(id: 22, stringId: 'perfect_day_7',  name: 'Perfect Week',   desc: '7 perfect days',                      category: 'Perfect Days', shape: BadgeShape.star, colorStart: Color(0xFFE65100), colorEnd: Color(0xFFEF6C00), icon: 'perfectWeek',  accent: Color(0xFFFFE0B2)),
  BadgeDef(id: 23, stringId: 'perfect_day_30', name: 'Perfect Month',  desc: '30 perfect days',                     category: 'Perfect Days', shape: BadgeShape.star, colorStart: Color(0xFFBF360C), colorEnd: Color(0xFFD84315), icon: 'perfectMonth', accent: Color(0xFFFFCCBC)),
  // Special
  BadgeDef(id: 24, stringId: 'veggie_day_1',   name: 'Eat the Rainbow', desc: 'Log a vegetable or fruit',           category: 'Special',      shape: BadgeShape.rounded, colorStart: Color(0xFFE91E63), colorEnd: Color(0xFFFF5252), icon: 'rainbow',      accent: Color(0xFFFCE4EC)),
  // Food Database
  BadgeDef(id: 25, stringId: 'foods_added_10',  name: 'Food Collector',     desc: 'Add 10 foods to your database',   category: 'Food Database', shape: BadgeShape.rounded, colorStart: Color(0xFF0288D1), colorEnd: Color(0xFF03A9F4), icon: 'book10',       accent: Color(0xFFB3E5FC)),
  BadgeDef(id: 26, stringId: 'foods_added_25',  name: 'Food Enthusiast',    desc: 'Add 25 foods to your database',  category: 'Food Database', shape: BadgeShape.rounded, colorStart: Color(0xFF0277BD), colorEnd: Color(0xFF0288D1), icon: 'book25',       accent: Color(0xFF81D4FA)),
  BadgeDef(id: 27, stringId: 'foods_added_50',  name: 'Food Expert',        desc: 'Add 50 foods to your database',  category: 'Food Database', shape: BadgeShape.rounded, colorStart: Color(0xFF01579B), colorEnd: Color(0xFF0277BD), icon: 'book50',       accent: Color(0xFF4FC3F7)),
  BadgeDef(id: 28, stringId: 'foods_added_100', name: 'Food Nerd',          desc: 'Add 100 foods to your database', category: 'Food Database', shape: BadgeShape.rounded, colorStart: Color(0xFF004C8C), colorEnd: Color(0xFF01579B), icon: 'book100',      accent: Color(0xFF29B6F6)),
  BadgeDef(id: 29, stringId: 'foods_added_200', name: 'Food Encyclopaedia', desc: 'Add 200 foods to your database', category: 'Food Database', shape: BadgeShape.rounded, colorStart: Color(0xFF002F6C), colorEnd: Color(0xFF004C8C), icon: 'book200',      accent: Color(0xFF0288D1)),
  // Special
  BadgeDef(id: 30, stringId: 'recipe_first',   name: 'Home Chef',        desc: 'Create your first home recipe',    category: 'Special',       shape: BadgeShape.shield,  colorStart: Color(0xFFD84315), colorEnd: Color(0xFFFF5722), icon: 'chef',         accent: Color(0xFFFFCCBC)),
];

// ---------------------------------------------------------------------------
// Badge computation — ported from web app's computeEarnedBadgeIds()
// ---------------------------------------------------------------------------

/// Lightweight entry used only for badge computation.
class RawBadgeEntry {
  final String date;
  final String? foodCategory;
  final double kcal;
  final double protein;
  final double carbs;
  final double fat;

  const RawBadgeEntry({
    required this.date,
    this.foodCategory,
    required this.kcal,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  /// Build from a Supabase row: {date, qty, foods:{kcal,protein,carbs,fat,unit,category}}
  factory RawBadgeEntry.fromRow(Map<String, dynamic> row) {
    final qty = (row['qty'] as num?)?.toDouble() ?? 1.0;
    final food = row['foods'] as Map<String, dynamic>?;
    if (food == null) {
      return RawBadgeEntry(date: row['date'] as String, kcal: 0, protein: 0, carbs: 0, fat: 0);
    }
    final unit = food['unit'] as String? ?? 'per100g';
    final scale = unit == 'per100g' ? qty / 100.0 : qty;
    return RawBadgeEntry(
      date: row['date'] as String,
      foodCategory: food['category'] as String?,
      kcal:    ((food['kcal']    as num?)?.toDouble() ?? 0) * scale,
      protein: ((food['protein'] as num?)?.toDouble() ?? 0) * scale,
      carbs:   ((food['carbs']   as num?)?.toDouble() ?? 0) * scale,
      fat:     ((food['fat']     as num?)?.toDouble() ?? 0) * scale,
    );
  }
}

/// Compute the set of earned badge string-IDs from raw data.
Set<String> computeEarnedBadgeStringIds({
  required List<RawBadgeEntry> entries,
  required int userFoodsCount,
  required bool hasHomeRecipe,
  /// IDs of default foods seeded at onboarding — excluded from food-count
  /// badges so only foods the user added themselves count toward milestones.
  Set<String> defaultFoodIds = const {},
  /// Returns MacroGoals (kcal/protein/carbs/fat) for a given ISO date.
  required ({double kcal, double protein, double carbs, double fat}) Function(String date) goalsForDate,
}) {
  // Only count foods the user actually added themselves.
  final addedFoodsCount = (userFoodsCount - defaultFoodIds.length).clamp(0, userFoodsCount);

  final loggedDates = entries.map((e) => e.date).toSet().toList()..sort();
  if (loggedDates.isEmpty && addedFoodsCount == 0 && !hasHomeRecipe) return {};

  // Group entries by date
  final byDate = <String, List<RawBadgeEntry>>{};
  for (final e in entries) {
    byDate.putIfAbsent(e.date, () => []).add(e);
  }

  final proteinDates = <String>[];
  final perfectDates = <String>[];
  final veggieDates  = <String>[];

  for (final date in loggedDates) {
    final dayEntries = byDate[date]!;
    double kcal = 0, protein = 0, carbs = 0, fat = 0;
    bool hasVeg = false, hasFruit = false;

    for (final e in dayEntries) {
      kcal    += e.kcal;
      protein += e.protein;
      carbs   += e.carbs;
      fat     += e.fat;
      if (e.foodCategory == 'vegetable') hasVeg   = true;
      if (e.foodCategory == 'fruit')     hasFruit = true;
    }

    final g = goalsForDate(date);

    if (g.protein > 0 && protein >= g.protein) proteinDates.add(date);

    if (g.kcal > 0 && g.protein > 0 && g.carbs > 0 && g.fat > 0 &&
        kcal    >= g.kcal    * 0.95 && kcal    <= g.kcal    * 1.05 &&
        protein >= g.protein &&
        carbs   >= g.carbs   * 0.95 && carbs   <= g.carbs   * 1.05 &&
        fat     >= g.fat     * 0.95 && fat     <= g.fat     * 1.05) {
      perfectDates.add(date);
    }

    if (hasVeg && hasFruit) veggieDates.add(date);
  }

  final maxLog     = _maxStreak(loggedDates);
  final maxProtein = _maxStreak(proteinDates);
  final maxVeggie  = _maxStreak(veggieDates);

  return {
    // Log streaks
    if (maxLog >= 7)  'log_streak_7',
    if (maxLog >= 14) 'log_streak_14',
    if (maxLog >= 30) 'log_streak_30',
    if (maxLog >= 90) 'log_streak_90',
    // Protein streaks
    if (maxProtein >= 7)  'protein_streak_7',
    if (maxProtein >= 14) 'protein_streak_14',
    if (maxProtein >= 30) 'protein_streak_30',
    if (maxProtein >= 90) 'protein_streak_90',
    // Veggie streak
    if (maxVeggie >= 7) 'veggie_streak_7',
    // Log milestones
    if (loggedDates.length >= 1)   'log_first',
    if (loggedDates.length >= 10)  'log_days_10',
    if (loggedDates.length >= 30)  'log_days_30',
    if (loggedDates.length >= 100) 'log_days_100',
    // Protein milestones
    if (proteinDates.length >= 1)   'protein_first',
    if (proteinDates.length >= 10)  'protein_hits_10',
    if (proteinDates.length >= 20)  'protein_hits_20',
    if (proteinDates.length >= 50)  'protein_hits_50',
    if (proteinDates.length >= 100) 'protein_hits_100',
    // Perfect days
    if (perfectDates.length >= 1)  'perfect_day_1',
    if (perfectDates.length >= 3)  'perfect_day_3',
    if (perfectDates.length >= 7)  'perfect_day_7',
    if (perfectDates.length >= 30) 'perfect_day_30',
    // Veggie milestone
    if (veggieDates.isNotEmpty) 'veggie_day_1',
    // Food library — uses only user-added foods, not seeded defaults
    if (addedFoodsCount >= 10)  'foods_added_10',
    if (addedFoodsCount >= 25)  'foods_added_25',
    if (addedFoodsCount >= 50)  'foods_added_50',
    if (addedFoodsCount >= 100) 'foods_added_100',
    if (addedFoodsCount >= 200) 'foods_added_200',
    // Recipe
    if (hasHomeRecipe) 'recipe_first',
  };
}

int _maxStreak(List<String> sortedDates) {
  if (sortedDates.isEmpty) return 0;
  int max = 1, current = 1;
  for (int i = 1; i < sortedDates.length; i++) {
    final prev = DateTime.parse(sortedDates[i - 1]);
    final curr = DateTime.parse(sortedDates[i]);
    if (curr.difference(prev).inDays == 1) {
      current++;
      if (current > max) max = current;
    } else {
      current = 1;
    }
  }
  return max;
}
