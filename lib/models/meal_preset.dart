import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'food_item.dart';

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

class MealPreset {
  final String id;
  final String name;
  final List<PresetItem> items;
  final DateTime createdAt;

  const MealPreset({
    required this.id,
    required this.name,
    required this.items,
    required this.createdAt,
  });

  int get totalCalories => items.fold(0, (s, i) => s + i.calories);

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'items': jsonEncode(items.map((i) => i.toMap()).toList()),
        'created_at': createdAt.toIso8601String(),
      };

  factory MealPreset.fromMap(Map<String, dynamic> m) {
    final rawItems = jsonDecode(m['items'] as String) as List<dynamic>;
    return MealPreset(
      id: m['id'] as String,
      name: m['name'] as String,
      items: rawItems
          .map((e) => PresetItem.fromMap(e as Map<String, dynamic>))
          .toList(),
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
        items: items.map(PresetItem.fromFoodItem).toList(),
        createdAt: DateTime.now(),
      );
}
