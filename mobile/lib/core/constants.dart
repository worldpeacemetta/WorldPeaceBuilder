import 'package:flutter/material.dart';
import '../theme.dart';

// ---------------------------------------------------------------------------
// Food categories (matches web app)
// ---------------------------------------------------------------------------
const foodCategories = [
  'Meat & Poultry',
  'Fish & Seafood',
  'Dairy & Eggs',
  'Grains & Pasta',
  'Bread & Bakery',
  'Fruits',
  'Vegetables',
  'Legumes & Beans',
  'Nuts & Seeds',
  'Fats & Oils',
  'Sauces & Condiments',
  'Snacks',
  'Sweets & Desserts',
  'Beverages',
  'Fast Food',
  'Ready Meals',
  'Supplements',
  'Alcohol',
  'Spices & Herbs',
  'Frozen Foods',
  'Other',
];

const categoryEmojis = {
  'Meat & Poultry'    : '🥩',
  'Fish & Seafood'    : '🐟',
  'Dairy & Eggs'      : '🧀',
  'Grains & Pasta'    : '🌾',
  'Bread & Bakery'    : '🍞',
  'Fruits'            : '🍎',
  'Vegetables'        : '🥦',
  'Legumes & Beans'   : '🫘',
  'Nuts & Seeds'      : '🥜',
  'Fats & Oils'       : '🫒',
  'Sauces & Condiments': '🧂',
  'Snacks'            : '🍿',
  'Sweets & Desserts' : '🍰',
  'Beverages'         : '☕',
  'Fast Food'         : '🍔',
  'Ready Meals'       : '📦',
  'Supplements'       : '💊',
  'Alcohol'           : '🍺',
  'Spices & Herbs'    : '🌿',
  'Frozen Foods'      : '🧊',
  'Other'             : '🍽️',
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
