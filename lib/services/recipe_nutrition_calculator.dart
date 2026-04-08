import '../models/recipe_ingredient.dart';

/// 1行ぶんの計算結果
class LineNutritionTotals {
  final int calories;
  final double protein;
  final double fat;
  final double carbs;
  final double sugar;
  final double fiber;
  final double sodium;

  const LineNutritionTotals({
    required this.calories,
    required this.protein,
    required this.fat,
    required this.carbs,
    required this.sugar,
    required this.fiber,
    required this.sodium,
  });
}

/// レシピ全体の合計
class RecipeNutritionTotals {
  final int calories;
  final double protein;
  final double fat;
  final double carbs;
  final double sugar;
  final double fiber;
  final double sodium;

  const RecipeNutritionTotals({
    required this.calories,
    required this.protein,
    required this.fat,
    required this.carbs,
    required this.sugar,
    required this.fiber,
    required this.sodium,
  });

  static const zero = RecipeNutritionTotals(
    calories: 0,
    protein: 0,
    fat: 0,
    carbs: 0,
    sugar: 0,
    fiber: 0,
    sodium: 0,
  );
}

class RecipeNutritionCalculator {
  static const double _kcalPerFatGram = 9;

  /// [grams] g 分の栄養を100g基準から計算し、調理補正を適用する。
  static LineNutritionTotals computeLine(RecipeIngredientLine line) {
    if (line.grams <= 0) {
      return const LineNutritionTotals(
        calories: 0,
        protein: 0,
        fat: 0,
        carbs: 0,
        sugar: 0,
        fiber: 0,
        sodium: 0,
      );
    }

    final r = line.grams / 100.0;
    final p = line.per100g;
    final m = line.cookingMethod;

    var cal = p.calories * r;
    var protein = p.protein * r;
    var fat = p.fat * r;
    var carbs = p.carbs * r;
    var sugar = p.sugar * r;
    var fiber = p.fiber * r;
    var sodium = p.sodium * r;

    cal *= m.calorieFactor;
    fat *= m.fatFactor;
    // PFCのうち脂質に調理油を加算（炭水化物・糖はそのまま）
    final extraOilG = m.extraOilPer100gFood * r;
    fat += extraOilG;
    cal += extraOilG * _kcalPerFatGram;

    return LineNutritionTotals(
      calories: cal.round(),
      protein: protein,
      fat: fat,
      carbs: carbs,
      sugar: sugar,
      fiber: fiber,
      sodium: sodium,
    );
  }

  static RecipeNutritionTotals computeTotal(List<RecipeIngredientLine> lines) {
    if (lines.isEmpty) return RecipeNutritionTotals.zero;
    var totalCal = 0;
    var protein = 0.0;
    var fat = 0.0;
    var carbs = 0.0;
    var sugar = 0.0;
    var fiber = 0.0;
    var sodium = 0.0;
    for (final line in lines) {
      final o = computeLine(line);
      totalCal += o.calories;
      protein += o.protein;
      fat += o.fat;
      carbs += o.carbs;
      sugar += o.sugar;
      fiber += o.fiber;
      sodium += o.sodium;
    }
    return RecipeNutritionTotals(
      calories: totalCal,
      protein: protein,
      fat: fat,
      carbs: carbs,
      sugar: sugar,
      fiber: fiber,
      sodium: sodium,
    );
  }
}
