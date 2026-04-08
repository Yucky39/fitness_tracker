import 'micronutrients.dart';

class FoodSearchResult {
  final String name;
  final int caloriesPer100g;
  final double proteinPer100g;
  final double fatPer100g;
  final double carbsPer100g;

  /// 表示用（例: 日本食品標準成分表（八訂）・文部科学省 食品成分データベース）
  final String? dataSourceLabel;

  /// 取得できた場合のみ（検索ソースによる）
  final Micronutrients? micronutrients;

  FoodSearchResult({
    required this.name,
    required this.caloriesPer100g,
    required this.proteinPer100g,
    required this.fatPer100g,
    required this.carbsPer100g,
    this.dataSourceLabel,
    this.micronutrients,
  });
}
