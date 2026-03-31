import 'dart:convert';
import 'package:http/http.dart' as http;

class FoodSearchResult {
  final String name;
  final int caloriesPer100g;
  final double proteinPer100g;
  final double fatPer100g;
  final double carbsPer100g;

  FoodSearchResult({
    required this.name,
    required this.caloriesPer100g,
    required this.proteinPer100g,
    required this.fatPer100g,
    required this.carbsPer100g,
  });
}

class FoodSearchService {
  Future<List<FoodSearchResult>> search(String query) async {
    if (query.trim().isEmpty) return [];

    final uri = Uri.parse(
      'https://world.openfoodfacts.org/cgi/search.pl'
      '?search_terms=${Uri.encodeComponent(query)}'
      '&json=1'
      '&fields=product_name,nutriments'
      '&page_size=10',
    );

    final response =
        await http.get(uri).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) return [];

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final products = data['products'] as List<dynamic>? ?? [];

    final results = <FoodSearchResult>[];
    for (final product in products) {
      final name = product['product_name'] as String? ?? '';
      if (name.isEmpty) continue;

      final n = product['nutriments'] as Map<String, dynamic>? ?? {};
      final cal =
          (n['energy-kcal_100g'] ?? n['energy-kcal'] ?? 0).toDouble();
      final protein = (n['proteins_100g'] ?? 0).toDouble();
      final fat = (n['fat_100g'] ?? 0).toDouble();
      final carbs = (n['carbohydrates_100g'] ?? 0).toDouble();

      results.add(FoodSearchResult(
        name: name,
        caloriesPer100g: cal.round(),
        proteinPer100g: protein,
        fatPer100g: fat,
        carbsPer100g: carbs,
      ));
    }

    return results;
  }
}
