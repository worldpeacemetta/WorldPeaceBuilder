/// Default foods seeded into a new user's food database at the end of
/// onboarding. Mirrors DEFAULT_FOODS in the web app (src/App.tsx).
///
/// Each map contains the keys expected by the Supabase `foods` table:
///   name, unit ('per100g' | 'perServing'), category, kcal, fat, carbs,
///   protein, and optionally serving_size (for perServing foods).
const kDefaultFoods = <Map<String, Object>>[
  // Vegetables
  {'name': 'Tomato',               'unit': 'per100g',    'category': 'vegetable',    'kcal': 18.0,  'fat': 0.2,  'carbs': 3.9,  'protein': 0.9},
  {'name': 'Broccoli',             'unit': 'per100g',    'category': 'vegetable',    'kcal': 34.0,  'fat': 0.4,  'carbs': 6.6,  'protein': 2.8},
  {'name': 'Spinach',              'unit': 'per100g',    'category': 'vegetable',    'kcal': 23.0,  'fat': 0.4,  'carbs': 3.6,  'protein': 2.9},
  {'name': 'Carrot',               'unit': 'per100g',    'category': 'vegetable',    'kcal': 41.0,  'fat': 0.2,  'carbs': 9.6,  'protein': 0.9},
  {'name': 'Cucumber',             'unit': 'per100g',    'category': 'vegetable',    'kcal': 16.0,  'fat': 0.1,  'carbs': 3.6,  'protein': 0.7},
  {'name': 'Red Bell Pepper',      'unit': 'per100g',    'category': 'vegetable',    'kcal': 31.0,  'fat': 0.3,  'carbs': 6.0,  'protein': 1.0},
  {'name': 'Onion',                'unit': 'per100g',    'category': 'vegetable',    'kcal': 40.0,  'fat': 0.1,  'carbs': 9.3,  'protein': 1.1},
  {'name': 'Zucchini',             'unit': 'per100g',    'category': 'vegetable',    'kcal': 17.0,  'fat': 0.3,  'carbs': 3.1,  'protein': 1.2},
  {'name': 'Sweet Potato',         'unit': 'per100g',    'category': 'vegetable',    'kcal': 86.0,  'fat': 0.1,  'carbs': 20.1, 'protein': 1.6},
  {'name': 'Lettuce',              'unit': 'per100g',    'category': 'vegetable',    'kcal': 15.0,  'fat': 0.2,  'carbs': 2.9,  'protein': 1.4},
  // Fruits
  {'name': 'Apple',                'unit': 'per100g',    'category': 'fruit',        'kcal': 52.0,  'fat': 0.2,  'carbs': 13.8, 'protein': 0.3},
  {'name': 'Banana',               'unit': 'per100g',    'category': 'fruit',        'kcal': 89.0,  'fat': 0.3,  'carbs': 22.8, 'protein': 1.1},
  {'name': 'Orange',               'unit': 'per100g',    'category': 'fruit',        'kcal': 47.0,  'fat': 0.1,  'carbs': 11.8, 'protein': 0.9},
  {'name': 'Strawberry',           'unit': 'per100g',    'category': 'fruit',        'kcal': 32.0,  'fat': 0.3,  'carbs': 7.7,  'protein': 0.7},
  {'name': 'Blueberry',            'unit': 'per100g',    'category': 'fruit',        'kcal': 57.0,  'fat': 0.3,  'carbs': 14.5, 'protein': 0.7},
  {'name': 'Mango',                'unit': 'per100g',    'category': 'fruit',        'kcal': 60.0,  'fat': 0.4,  'carbs': 15.0, 'protein': 0.8},
  {'name': 'Grapes',               'unit': 'per100g',    'category': 'fruit',        'kcal': 69.0,  'fat': 0.2,  'carbs': 18.1, 'protein': 0.6},
  // Meat & Eggs
  {'name': 'Chicken Breast (cooked)', 'unit': 'per100g', 'category': 'meat',        'kcal': 165.0, 'fat': 3.6,  'carbs': 0.0,  'protein': 31.0},
  {'name': 'Egg',                  'unit': 'per100g',    'category': 'eggProducts',  'kcal': 155.0, 'fat': 11.0, 'carbs': 1.1,  'protein': 13.0},
  // Fish & Seafood
  {'name': 'Salmon',               'unit': 'per100g',    'category': 'fish',         'kcal': 208.0, 'fat': 13.0, 'carbs': 0.0,  'protein': 20.0},
  {'name': 'Tuna (canned)',        'unit': 'per100g',    'category': 'fish',         'kcal': 116.0, 'fat': 1.0,  'carbs': 0.0,  'protein': 26.0},
  // Grains
  {'name': 'White Rice (cooked)',  'unit': 'per100g',    'category': 'grains',       'kcal': 130.0, 'fat': 0.3,  'carbs': 28.2, 'protein': 2.7},
  {'name': 'Pasta (cooked)',       'unit': 'per100g',    'category': 'grains',       'kcal': 131.0, 'fat': 1.1,  'carbs': 25.0, 'protein': 5.0},
  // Cereals
  {'name': 'Oats',                 'unit': 'per100g',    'category': 'cereals',      'kcal': 389.0, 'fat': 6.9,  'carbs': 66.0, 'protein': 17.0},
  // Bread & Bakery
  {'name': 'Whole Wheat Bread',    'unit': 'per100g',    'category': 'breadBakery',  'kcal': 247.0, 'fat': 3.4,  'carbs': 41.0, 'protein': 13.0},
  // Dairy
  {'name': 'Greek Yogurt',         'unit': 'per100g',    'category': 'yogurt',       'kcal': 59.0,  'fat': 0.4,  'carbs': 3.6,  'protein': 10.0},
  {'name': 'Whole Milk',           'unit': 'per100g',    'category': 'milk',         'kcal': 61.0,  'fat': 3.3,  'carbs': 4.8,  'protein': 3.2},
  {'name': 'Cheddar Cheese',       'unit': 'per100g',    'category': 'cheese',       'kcal': 402.0, 'fat': 33.0, 'carbs': 1.3,  'protein': 25.0},
  // Plant Protein / Legumes
  {'name': 'Chickpeas (cooked)',   'unit': 'per100g',    'category': 'plantProtein', 'kcal': 164.0, 'fat': 2.6,  'carbs': 27.0, 'protein': 8.9},
  {'name': 'Lentils (cooked)',     'unit': 'per100g',    'category': 'plantProtein', 'kcal': 116.0, 'fat': 0.4,  'carbs': 20.0, 'protein': 9.0},
  {'name': 'Black Beans (cooked)', 'unit': 'per100g',    'category': 'plantProtein', 'kcal': 132.0, 'fat': 0.5,  'carbs': 24.0, 'protein': 8.9},
  // Cooking Oil & Supplement
  {'name': 'Olive Oil',            'unit': 'perServing', 'category': 'cookingOil',   'kcal': 88.0,  'fat': 10.0, 'carbs': 0.0,  'protein': 0.0,  'serving_size': 10.0},
  {'name': 'Whey Protein (1 scoop)', 'unit': 'perServing', 'category': 'supplement', 'kcal': 120.0, 'fat': 1.5,  'carbs': 3.0,  'protein': 24.0, 'serving_size': 30.0},
];
