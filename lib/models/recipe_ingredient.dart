import 'micronutrients.dart';

/// 分量の単位（内部ではグラムに換算して栄養計算する）
enum RecipeQuantityUnit {
  /// グラム
  gram('gram', 'g'),

  /// ミリリットル（水・スープ等は比重1.0とみなして g と同じ数値）
  milliliter('milliliter', 'ml'),

  /// 個（1個あたりの重量 g が必要）
  piece('piece', '個'),

  /// 大さじ（15ml、水相当で約15g）
  tablespoon('tablespoon', '大さじ'),

  /// 小さじ（5ml、水相当で約5g）
  teaspoon('teaspoon', '小さじ'),

  /// 計量カップ1杯（200ml、水相当で約200g）
  cup('cup', 'カップ(200ml)');

  const RecipeQuantityUnit(this.key, this.shortLabel);
  final String key;
  final String shortLabel;

  static RecipeQuantityUnit fromKey(String? key) => RecipeQuantityUnit.values.firstWhere(
        (e) => e.key == key,
        orElse: () => RecipeQuantityUnit.gram,
      );

  /// [amount] をグラムに換算。個数のときは [gramsPerPiece] が必須。
  /// 換算できない場合は null。
  static double? amountToGrams(
    RecipeQuantityUnit unit,
    double amount, {
    double? gramsPerPiece,
  }) {
    if (amount <= 0) return null;
    switch (unit) {
      case RecipeQuantityUnit.gram:
        return amount;
      case RecipeQuantityUnit.milliliter:
        return amount;
      case RecipeQuantityUnit.piece:
        if (gramsPerPiece == null || gramsPerPiece <= 0) return null;
        return amount * gramsPerPiece;
      case RecipeQuantityUnit.tablespoon:
        return amount * 15.0;
      case RecipeQuantityUnit.teaspoon:
        return amount * 5.0;
      case RecipeQuantityUnit.cup:
        return amount * 200.0;
    }
  }
}

/// 100gあたりの栄養（手入力・検索結果から設定）
class NutritionPer100g {
  final int calories;
  final double protein;
  final double fat;
  final double carbs;
  final double sugar;
  final double fiber;
  final double sodium;
  final Micronutrients micronutrients;

  const NutritionPer100g({
    required this.calories,
    required this.protein,
    required this.fat,
    required this.carbs,
    this.sugar = 0,
    this.fiber = 0,
    this.sodium = 0,
    this.micronutrients = Micronutrients.zero,
  });

  Map<String, dynamic> toMap() => {
        'calories': calories,
        'protein': protein,
        'fat': fat,
        'carbs': carbs,
        'sugar': sugar,
        'fiber': fiber,
        'sodium': sodium,
        'micronutrients': micronutrients.toMap(),
      };

  factory NutritionPer100g.fromMap(Map<String, dynamic> m) => NutritionPer100g(
        calories: (m['calories'] as num).toInt(),
        protein: (m['protein'] as num).toDouble(),
        fat: (m['fat'] as num).toDouble(),
        carbs: (m['carbs'] as num).toDouble(),
        sugar: (m['sugar'] as num?)?.toDouble() ?? 0,
        fiber: (m['fiber'] as num?)?.toDouble() ?? 0,
        sodium: (m['sodium'] as num?)?.toDouble() ?? 0,
        micronutrients: m['micronutrients'] != null
            ? Micronutrients.fromMap(
                Map<String, dynamic>.from(m['micronutrients'] as Map),
              )
            : Micronutrients.zero,
      );
}

/// 調理法による概算補正（油の付加・脂質の溶出など）。目安値です。
enum RecipeCookingMethod {
  raw('そのまま / 生', calorieFactor: 1.0, fatFactor: 1.0, extraOilPer100gFood: 0),
  microwave('電子レンジ', calorieFactor: 1.0, fatFactor: 1.0, extraOilPer100gFood: 0),
  steam('蒸す', calorieFactor: 1.0, fatFactor: 1.0, extraOilPer100gFood: 0),
  boil('ゆでる', calorieFactor: 1.0, fatFactor: 0.92, extraOilPer100gFood: 0),
  simmer('煮る', calorieFactor: 1.0, fatFactor: 0.95, extraOilPer100gFood: 0),
  grill('焼く', calorieFactor: 0.98, fatFactor: 0.85, extraOilPer100gFood: 0),
  stirFry('炒める', calorieFactor: 1.06, fatFactor: 1.12, extraOilPer100gFood: 3),
  deepFry('揚げる', calorieFactor: 1.2, fatFactor: 1.35, extraOilPer100gFood: 8);

  const RecipeCookingMethod(
    this.label, {
    required this.calorieFactor,
    required this.fatFactor,
    required this.extraOilPer100gFood,
  });

  final String label;
  final double calorieFactor;
  final double fatFactor;
  /// 食材100gあたりに加算する調理油（g）の目安
  final double extraOilPer100gFood;

  static RecipeCookingMethod fromKey(String? key) => RecipeCookingMethod.values.firstWhere(
        (e) => e.name == key,
        orElse: () => RecipeCookingMethod.raw,
      );
}

class RecipeIngredientLine {
  final String name;
  /// 栄養計算に使う換算後の質量（g）
  final double grams;
  /// 入力した分量の数値（例: 2.5 個、3 大さじ）
  final double amount;
  final RecipeQuantityUnit quantityUnit;
  /// 単位が「個」のとき 1 個あたりの g
  final double? gramsPerPiece;
  final NutritionPer100g per100g;
  final RecipeCookingMethod cookingMethod;

  const RecipeIngredientLine({
    required this.name,
    required this.grams,
    required this.amount,
    this.quantityUnit = RecipeQuantityUnit.gram,
    this.gramsPerPiece,
    required this.per100g,
    required this.cookingMethod,
  });

  Map<String, dynamic> toMap() => {
        'name': name,
        'grams': grams,
        'amount': amount,
        'quantity_unit': quantityUnit.key,
        'grams_per_piece': gramsPerPiece,
        'per100g': per100g.toMap(),
        'cooking_method': cookingMethod.name,
      };

  factory RecipeIngredientLine.fromMap(Map<String, dynamic> m) {
    final grams = (m['grams'] as num).toDouble();
    final unit = RecipeQuantityUnit.fromKey(m['quantity_unit'] as String?);
    final amount = (m['amount'] as num?)?.toDouble() ?? grams;
    final gpp = (m['grams_per_piece'] as num?)?.toDouble();
    return RecipeIngredientLine(
      name: m['name'] as String,
      grams: grams,
      amount: amount,
      quantityUnit: unit,
      gramsPerPiece: gpp,
      per100g: NutritionPer100g.fromMap(
        Map<String, dynamic>.from(m['per100g'] as Map),
      ),
      cookingMethod: RecipeCookingMethod.fromKey(m['cooking_method'] as String?),
    );
  }
}
