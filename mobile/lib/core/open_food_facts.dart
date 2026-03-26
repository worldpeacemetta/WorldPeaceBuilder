import 'dart:convert';
import 'package:http/http.dart' as http;

/// Fetches nutrition data from Open Food Facts by barcode.
/// Returns a pre-filled food map on success, null if not found.
Future<Map<String, dynamic>?> fetchFoodByBarcode(String barcode) async {
  try {
    final uri = Uri.parse(
      'https://world.openfoodfacts.org/api/v0/product/$barcode.json',
    );
    final response = await http.get(uri, headers: {
      'User-Agent': 'MacroTracker-Mobile/1.0',
    }).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) return null;
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data['status'] != 1) return null;

    final product   = data['product'] as Map<String, dynamic>? ?? {};
    final nutriments = product['nutriments'] as Map<String, dynamic>? ?? {};

    double _n(String key) =>
        (nutriments[key] as num?)?.toDouble() ??
        (nutriments['${key}_100g'] as num?)?.toDouble() ??
        0.0;

    final name  = (product['product_name'] as String?)?.trim() ?? '';
    final brand = (product['brands'] as String?)?.trim() ?? '';
    if (name.isEmpty) return null;

    return {
      'name'   : name,
      'brand'  : brand.isEmpty ? null : brand,
      'unit'   : 'per100g',
      'kcal'   : _n('energy-kcal'),
      'protein': _n('proteins'),
      'carbs'  : _n('carbohydrates'),
      'fat'    : _n('fat'),
      'category': null,
    };
  } catch (_) {
    return null;
  }
}
