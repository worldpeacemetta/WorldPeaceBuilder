import 'package:flutter/material.dart';
import '../theme.dart';

// ---------------------------------------------------------------------------
// Food categories — keys match web app's FOOD_CATEGORIES value strings
// ---------------------------------------------------------------------------
const foodCategories = [
  'fruit',
  'vegetable',
  'meat',
  'eggProducts',
  'fish',
  'plantProtein',
  'supplement',
  'breadBakery',
  'cereals',
  'grains',
  'nutsSeeds',
  'milk',
  'yogurt',
  'cheese',
  'creamsButters',
  'cookingOil',
  'dressing',
  'homeRecipe',
  'outsideMeal',
  'sweet',
  'other',
];

const categoryLabels = {
  'fruit'        : 'Fruit',
  'vegetable'    : 'Vegetable',
  'meat'         : 'Meat',
  'eggProducts'  : 'Egg & Egg Products',
  'fish'         : 'Fish & Seafood',
  'plantProtein' : 'Plant Protein',
  'supplement'   : 'Supplements',
  'breadBakery'  : 'Bread & Bakery',
  'cereals'      : 'Cereals',
  'grains'       : 'Grains',
  'nutsSeeds'    : 'Nuts & Seeds',
  'milk'         : 'Milk',
  'yogurt'       : 'Yogurt',
  'cheese'       : 'Cheese',
  'creamsButters': 'Creams & Butters',
  'cookingOil'   : 'Cooking Oil',
  'dressing'     : 'Dressing',
  'homeRecipe'   : 'Home Recipe',
  'outsideMeal'  : 'Outside Meal',
  'sweet'        : 'Sweet',
  'other'        : 'Other',
};

const categoryEmojis = {
  'fruit'        : '🍎',
  'vegetable'    : '🥦',
  'meat'         : '🥩',
  'eggProducts'  : '🥚',
  'fish'         : '🐟',
  'plantProtein' : '🌱',
  'supplement'   : '🧪',
  'breadBakery'  : '🥖',
  'cereals'      : '🥣',
  'grains'       : '🌾',
  'nutsSeeds'    : '🥜',
  'milk'         : '🥛',
  'yogurt'       : '🍶',
  'cheese'       : '🧀',
  'creamsButters': '🧈',
  'cookingOil'   : '🛢️',
  'dressing'     : '🥫',
  'homeRecipe'   : '🏠',
  'outsideMeal'  : '🍽️',
  'sweet'        : '🍬',
  'other'        : '⚪️',
};

// ---------------------------------------------------------------------------
// Goal / setup modes
// ---------------------------------------------------------------------------
const setupModes = ['dual', 'bulking', 'cutting', 'maintenance'];

const setupModeLabels = {
  'dual'        : 'Train / Rest Days',
  'bulking'     : 'Bulking',
  'cutting'     : 'Cutting',
  'maintenance' : 'Maintenance',
};

// ---------------------------------------------------------------------------
// Macro colours (also available via AppColors for use in charts etc.)
// ---------------------------------------------------------------------------
const macroColors = {
  'kcal'   : AppColors.kcal,
  'protein': AppColors.protein,
  'carbs'  : AppColors.carbs,
  'fat'    : AppColors.fat,
};

const macroLabels = {
  'kcal'   : 'Calories',
  'protein': 'Protein',
  'carbs'  : 'Carbs',
  'fat'    : 'Fat',
};

const macroUnits = {
  'kcal'   : 'kcal',
  'protein': 'g',
  'carbs'  : 'g',
  'fat'    : 'g',
};
