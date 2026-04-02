enum MealType {
  breakfast('breakfast', '朝食'),
  lunch('lunch', '昼食'),
  dinner('dinner', '夕食'),
  snack('snack', '間食');

  const MealType(this.key, this.label);
  final String key;
  final String label;

  static MealType fromKey(String? key) => MealType.values.firstWhere(
        (e) => e.key == key,
        orElse: () => MealType.snack,
      );

  static MealType detectFromTime(DateTime time) {
    final h = time.hour;
    if (h >= 5 && h < 10) return MealType.breakfast;
    if (h >= 10 && h < 15) return MealType.lunch;
    if (h >= 18) return MealType.dinner;
    return MealType.snack;
  }
}

class FoodItem {
  final String id;
  final String name;
  final int calories;
  final double protein;
  final double fat;
  final double carbs;
  final double sugar;
  final double fiber;
  final double sodium;
  final MealType mealType;
  final DateTime date;

  FoodItem({
    required this.id,
    required this.name,
    required this.calories,
    required this.protein,
    required this.fat,
    required this.carbs,
    this.sugar = 0.0,
    this.fiber = 0.0,
    this.sodium = 0.0,
    required this.mealType,
    required this.date,
  });

  FoodItem copyWith({
    String? id,
    String? name,
    int? calories,
    double? protein,
    double? fat,
    double? carbs,
    double? sugar,
    double? fiber,
    double? sodium,
    MealType? mealType,
    DateTime? date,
  }) {
    return FoodItem(
      id: id ?? this.id,
      name: name ?? this.name,
      calories: calories ?? this.calories,
      protein: protein ?? this.protein,
      fat: fat ?? this.fat,
      carbs: carbs ?? this.carbs,
      sugar: sugar ?? this.sugar,
      fiber: fiber ?? this.fiber,
      sodium: sodium ?? this.sodium,
      mealType: mealType ?? this.mealType,
      date: date ?? this.date,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'calories': calories,
      'protein': protein,
      'fat': fat,
      'carbs': carbs,
      'sugar': sugar,
      'fiber': fiber,
      'sodium': sodium,
      'meal_type': mealType.key,
      'date': date.toIso8601String(),
    };
  }

  factory FoodItem.fromMap(Map<String, dynamic> map) {
    return FoodItem(
      id: map['id'] as String,
      name: map['name'] as String,
      calories: map['calories'] as int,
      protein: (map['protein'] as num).toDouble(),
      fat: (map['fat'] as num).toDouble(),
      carbs: (map['carbs'] as num).toDouble(),
      sugar: (map['sugar'] as num?)?.toDouble() ?? 0.0,
      fiber: (map['fiber'] as num?)?.toDouble() ?? 0.0,
      sodium: (map['sodium'] as num?)?.toDouble() ?? 0.0,
      mealType: MealType.fromKey(map['meal_type'] as String?),
      date: DateTime.parse(map['date'] as String),
    );
  }
}
