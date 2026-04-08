import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'food_item.dart';
import 'recipe_ingredient.dart';
import '../services/recipe_nutrition_calculator.dart';

class PresetItem {
  final String name;
  final int calories;
  final double protein;
  final double fat;
  final double carbs;
  final double sugar;
  final double fiber;
  final double sodium;
  final MealType mealType;

  const PresetItem({
    required this.name,
    required this.calories,
    required this.protein,
    required this.fat,
    required this.carbs,
    required this.sugar,
    required this.fiber,
    required this.sodium,
    required this.mealType,
  });

  Map<String, dynamic> toMap() => {
        'name': name,
        'calories': calories,
        'protein': protein,
        'fat': fat,
        'carbs': carbs,
        'sugar': sugar,
        'fiber': fiber,
        'sodium': sodium,
        'meal_type': mealType.key,
      };

  factory PresetItem.fromMap(Map<String, dynamic> m) => PresetItem(
        name: m['name'] as String,
        calories: (m['calories'] as num).toInt(),
        protein: (m['protein'] as num).toDouble(),
        fat: (m['fat'] as num).toDouble(),
        carbs: (m['carbs'] as num).toDouble(),
        sugar: (m['sugar'] as num?)?.toDouble() ?? 0.0,
        fiber: (m['fiber'] as num?)?.toDouble() ?? 0.0,
        sodium: (m['sodium'] as num?)?.toDouble() ?? 0.0,
        mealType: MealType.fromKey(m['meal_type'] as String?),
      );

  factory PresetItem.fromFoodItem(FoodItem item) => PresetItem(
        name: item.name,
        calories: item.calories,
        protein: item.protein,
        fat: item.fat,
        carbs: item.carbs,
        sugar: item.sugar,
        fiber: item.fiber,
        sodium: item.sodium,
        mealType: item.mealType,
      );
}

enum MealPresetKind {
  /// 食事一覧から保存した複数品目
  meal,
  /// 食材・分量・調理法から計算したレシピ
  recipe,
}

class MealPreset {
  final String id;
  final String name;
  final MealPresetKind kind;
  final List<PresetItem> items;
  final List<RecipeIngredientLine>? recipeLines;
  final DateTime createdAt;

  const MealPreset({
    required this.id,
    required this.name,
    this.kind = MealPresetKind.meal,
    required this.items,
    this.recipeLines,
    required this.createdAt,
  });

  int get totalCalories => items.fold(0, (s, i) => s + i.calories);

  bool get isRecipe => kind == MealPresetKind.recipe;

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'kind': kind.name,
        'items': jsonEncode(items.map((i) => i.toMap()).toList()),
        'recipe_data': recipeLines != null
            ? jsonEncode(recipeLines!.map((e) => e.toMap()).toList())
            : null,
        'created_at': createdAt.toIso8601String(),
      };

  factory MealPreset.fromMap(Map<String, dynamic> m) {
    final rawItems = jsonDecode(m['items'] as String) as List<dynamic>;
    final kindStr = m['kind'] as String? ?? MealPresetKind.meal.name;
    final kind = MealPresetKind.values.firstWhere(
      (e) => e.name == kindStr,
      orElse: () => MealPresetKind.meal,
    );
    List<RecipeIngredientLine>? recipeLines;
    final rawRecipe = m['recipe_data'];
    if (rawRecipe != null && rawRecipe is String && rawRecipe.isNotEmpty) {
      final list = jsonDecode(rawRecipe) as List<dynamic>;
      recipeLines = list
          .map((e) => RecipeIngredientLine.fromMap(e as Map<String, dynamic>))
          .toList();
    }
    return MealPreset(
      id: m['id'] as String,
      name: m['name'] as String,
      kind: kind,
      items: rawItems
          .map((e) => PresetItem.fromMap(e as Map<String, dynamic>))
          .toList(),
      recipeLines: recipeLines,
      createdAt: DateTime.parse(m['created_at'] as String),
    );
  }

  static MealPreset create({
    required String name,
    required List<FoodItem> items,
  }) =>
      MealPreset(
        id: const Uuid().v4(),
        name: name,
        kind: MealPresetKind.meal,
        items: items.map(PresetItem.fromFoodItem).toList(),
        createdAt: DateTime.now(),
      );

  /// レシピ1件分として保存（日記に追加するときは [items] の1行を使う）
  static MealPreset createRecipe({
    required String name,
    required List<RecipeIngredientLine> lines,
    required MealType mealType,
  }) {
    final total = RecipeNutritionCalculator.computeTotal(lines);
    final item = PresetItem(
      name: name,
      calories: total.calories,
      protein: total.protein,
      fat: total.fat,
      carbs: total.carbs,
      sugar: total.sugar,
      fiber: total.fiber,
      sodium: total.sodium,
      mealType: mealType,
    );
    return MealPreset(
      id: const Uuid().v4(),
      name: name,
      kind: MealPresetKind.recipe,
      items: [item],
      recipeLines: lines,
      createdAt: DateTime.now(),
    );
  }
}
