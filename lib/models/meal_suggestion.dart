/// 1日の食事提案データモデル
///
/// AI が生成した提案を保持する。
/// PFC・カロリーは文部科学省「日本食品標準成分表」の栄養素値を基準とする。

class SuggestedIngredient {
  final String name;
  final String amount; // 例: "150g", "1個", "大さじ2"
  final int calories;
  final double protein;
  final double fat;
  final double carbs;

  const SuggestedIngredient({
    required this.name,
    required this.amount,
    required this.calories,
    required this.protein,
    required this.fat,
    required this.carbs,
  });

  factory SuggestedIngredient.fromJson(Map<String, dynamic> j) =>
      SuggestedIngredient(
        name: j['name'] as String? ?? '',
        amount: j['amount'] as String? ?? '',
        calories: (j['calories'] as num?)?.toInt() ?? 0,
        protein: (j['protein'] as num?)?.toDouble() ?? 0.0,
        fat: (j['fat'] as num?)?.toDouble() ?? 0.0,
        carbs: (j['carbs'] as num?)?.toDouble() ?? 0.0,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'amount': amount,
        'calories': calories,
        'protein': protein,
        'fat': fat,
        'carbs': carbs,
      };
}

/// メニュー1品（料理単位）
class SuggestedDish {
  final String name;
  final List<SuggestedIngredient> ingredients;
  final List<String> steps; // 調理手順
  final int calories;
  final double protein;
  final double fat;
  final double carbs;
  final String? note; // 補足（例: 「高タンパクな主菜」）

  const SuggestedDish({
    required this.name,
    required this.ingredients,
    required this.steps,
    required this.calories,
    required this.protein,
    required this.fat,
    required this.carbs,
    this.note,
  });

  factory SuggestedDish.fromJson(Map<String, dynamic> j) => SuggestedDish(
        name: j['name'] as String? ?? '',
        ingredients: (j['ingredients'] as List<dynamic>?)
                ?.map((e) =>
                    SuggestedIngredient.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        steps: (j['steps'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        calories: (j['calories'] as num?)?.toInt() ?? 0,
        protein: (j['protein'] as num?)?.toDouble() ?? 0.0,
        fat: (j['fat'] as num?)?.toDouble() ?? 0.0,
        carbs: (j['carbs'] as num?)?.toDouble() ?? 0.0,
        note: j['note'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'ingredients': ingredients.map((i) => i.toJson()).toList(),
        'steps': steps,
        'calories': calories,
        'protein': protein,
        'fat': fat,
        'carbs': carbs,
        if (note != null) 'note': note,
      };
}

/// 食事タイミング（朝食・昼食・夕食・間食）ごとの提案
class SuggestedMeal {
  final String mealType; // 'breakfast' | 'lunch' | 'dinner' | 'snack'
  final String mealTypeLabel;
  final List<SuggestedDish> dishes;

  const SuggestedMeal({
    required this.mealType,
    required this.mealTypeLabel,
    required this.dishes,
  });

  int get totalCalories => dishes.fold(0, (s, d) => s + d.calories);
  double get totalProtein => dishes.fold(0.0, (s, d) => s + d.protein);
  double get totalFat => dishes.fold(0.0, (s, d) => s + d.fat);
  double get totalCarbs => dishes.fold(0.0, (s, d) => s + d.carbs);

  factory SuggestedMeal.fromJson(Map<String, dynamic> j) {
    final type = j['meal_type'] as String? ?? 'snack';
    final labelMap = {
      'breakfast': '朝食',
      'lunch': '昼食',
      'dinner': '夕食',
      'snack': '間食',
    };
    return SuggestedMeal(
      mealType: type,
      mealTypeLabel: labelMap[type] ?? type,
      dishes: (j['dishes'] as List<dynamic>?)
              ?.map((e) => SuggestedDish.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
        'meal_type': mealType,
        'dishes': dishes.map((d) => d.toJson()).toList(),
      };
}

/// 1日の食事提案全体
class DailyMealSuggestion {
  final List<SuggestedMeal> meals;
  final String? supplementNote; // サプリ・プロテインの考慮コメント
  final DateTime generatedAt;

  const DailyMealSuggestion({
    required this.meals,
    this.supplementNote,
    required this.generatedAt,
  });

  int get totalCalories => meals.fold(0, (s, m) => s + m.totalCalories);
  double get totalProtein => meals.fold(0.0, (s, m) => s + m.totalProtein);
  double get totalFat => meals.fold(0.0, (s, m) => s + m.totalFat);
  double get totalCarbs => meals.fold(0.0, (s, m) => s + m.totalCarbs);

  factory DailyMealSuggestion.fromJson(Map<String, dynamic> j) =>
      DailyMealSuggestion(
        meals: (j['meals'] as List<dynamic>?)
                ?.map((e) => SuggestedMeal.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        supplementNote: j['supplement_note'] as String?,
        generatedAt: DateTime.tryParse(j['generated_at'] as String? ?? '') ??
            DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'meals': meals.map((m) => m.toJson()).toList(),
        if (supplementNote != null) 'supplement_note': supplementNote,
        'generated_at': generatedAt.toIso8601String(),
      };
}
