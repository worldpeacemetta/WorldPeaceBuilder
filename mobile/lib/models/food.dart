class Food {
  final String id;
  final String userId;
  final String name;
  final String? brand;
  final String unit; // 'per100g' | 'perServing'
  final double? servingSize;
  final double kcal;
  final double fat;
  final double carbs;
  final double protein;
  final String? category;

  const Food({
    required this.id,
    required this.userId,
    required this.name,
    this.brand,
    required this.unit,
    this.servingSize,
    required this.kcal,
    required this.fat,
    required this.carbs,
    required this.protein,
    this.category,
  });

  factory Food.fromJson(Map<String, dynamic> json) => Food(
    id: json['id'] as String,
    userId: json['user_id'] as String,
    name: json['name'] as String,
    brand: json['brand'] as String?,
    unit: (json['unit'] as String?) ?? 'per100g',
    servingSize: (json['serving_size'] as num?)?.toDouble(),
    kcal: (json['kcal'] as num?)?.toDouble() ?? 0,
    fat: (json['fat'] as num?)?.toDouble() ?? 0,
    carbs: (json['carbs'] as num?)?.toDouble() ?? 0,
    protein: (json['protein'] as num?)?.toDouble() ?? 0,
    category: json['category'] as String?,
  );

  Map<String, dynamic> toInsertJson() => {
    'name': name,
    'brand': brand,
    'unit': unit,
    'serving_size': servingSize,
    'kcal': kcal,
    'fat': fat,
    'carbs': carbs,
    'protein': protein,
    'category': category,
  };

  /// Scale macros by qty.
  /// per100g: factor = qty / 100
  /// perServing: factor = qty
  MacroValues scaledMacros(double qty) {
    final factor = unit == 'per100g' ? qty / 100.0 : qty;
    return MacroValues(
      kcal: kcal * factor,
      protein: protein * factor,
      carbs: carbs * factor,
      fat: fat * factor,
    );
  }

  /// Label shown in lists (name + brand if available).
  String get displayName => brand != null && brand!.isNotEmpty ? '$name · $brand' : name;

  Food copyWith({
    String? name,
    String? brand,
    String? unit,
    double? servingSize,
    double? kcal,
    double? fat,
    double? carbs,
    double? protein,
    String? category,
  }) => Food(
    id: id,
    userId: userId,
    name: name ?? this.name,
    brand: brand ?? this.brand,
    unit: unit ?? this.unit,
    servingSize: servingSize ?? this.servingSize,
    kcal: kcal ?? this.kcal,
    fat: fat ?? this.fat,
    carbs: carbs ?? this.carbs,
    protein: protein ?? this.protein,
    category: category ?? this.category,
  );
}

/// Aggregated macro totals.
class MacroValues {
  final double kcal;
  final double protein;
  final double carbs;
  final double fat;

  const MacroValues({
    this.kcal = 0,
    this.protein = 0,
    this.carbs = 0,
    this.fat = 0,
  });

  MacroValues operator +(MacroValues other) => MacroValues(
    kcal: kcal + other.kcal,
    protein: protein + other.protein,
    carbs: carbs + other.carbs,
    fat: fat + other.fat,
  );

  static MacroValues sum(Iterable<MacroValues> items) =>
      items.fold(const MacroValues(), (acc, v) => acc + v);
}
