import 'dart:convert';
import 'package:http/http.dart' as http;

class BarcodeResult {
  final String name;
  final double caloriesPer100g;
  final double proteinPer100g;
  final double fatPer100g;
  final double carbsPer100g;
  final double sugarPer100g;
  final double fiberPer100g;
  final double sodiumMgPer100g;
  final double? defaultServingGrams;

  const BarcodeResult({
    required this.name,
    required this.caloriesPer100g,
    required this.proteinPer100g,
    required this.fatPer100g,
    required this.carbsPer100g,
    required this.sugarPer100g,
    required this.fiberPer100g,
    required this.sodiumMgPer100g,
    this.defaultServingGrams,
  });

  /// Returns nutrients scaled to [grams] amount.
  Map<String, num> forGrams(double grams) {
    final r = grams / 100;
    return {
      'calories': (caloriesPer100g * r).round(),
      'protein': double.parse((proteinPer100g * r).toStringAsFixed(1)),
      'fat': double.parse((fatPer100g * r).toStringAsFixed(1)),
      'carbs': double.parse((carbsPer100g * r).toStringAsFixed(1)),
      'sugar': double.parse((sugarPer100g * r).toStringAsFixed(1)),
      'fiber': double.parse((fiberPer100g * r).toStringAsFixed(1)),
      'sodium': double.parse((sodiumMgPer100g * r).toStringAsFixed(0)),
    };
  }
}

class BarcodeLookupService {
  static const _baseUrl = 'https://world.openfoodfacts.org/api/v0/product';

  Future<BarcodeResult?> lookup(String barcode) async {
    try {
      final res = await http
          .get(Uri.parse('$_baseUrl/$barcode.json'))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return null;

      final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      if (data['status'] != 1) return null;

      final product = data['product'] as Map<String, dynamic>;
      final nutriments = (product['nutriments'] as Map<String, dynamic>?) ?? {};

      // Best available Japanese/English name
      final name = ((product['product_name_ja'] as String?)?.trim().isNotEmpty == true
              ? product['product_name_ja'] as String
              : null) ??
          ((product['product_name'] as String?)?.trim().isNotEmpty == true
              ? product['product_name'] as String
              : null) ??
          ((product['product_name_en'] as String?)?.trim().isNotEmpty == true
              ? product['product_name_en'] as String
              : null) ??
          barcode;

      double get100g(String key) =>
          (nutriments['${key}_100g'] as num?)?.toDouble() ?? 0.0;

      // Open Food Facts sodium is in grams per 100g → convert to mg
      final sodiumMg = get100g('sodium') * 1000;

      double? servingGrams;
      final servingQty = product['serving_quantity'];
      if (servingQty != null) {
        servingGrams = (servingQty as num).toDouble();
      }

      return BarcodeResult(
        name: name,
        caloriesPer100g: get100g('energy-kcal'),
        proteinPer100g: get100g('proteins'),
        fatPer100g: get100g('fat'),
        carbsPer100g: get100g('carbohydrates'),
        sugarPer100g: get100g('sugars'),
        fiberPer100g: get100g('fiber'),
        sodiumMgPer100g: sodiumMg,
        defaultServingGrams: servingGrams,
      );
    } catch (_) {
      return null;
    }
  }
}
