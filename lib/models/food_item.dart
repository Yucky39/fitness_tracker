class FoodItem {
  final String id;
  final String name;
  final int calories;
  final double protein;
  final double fat;
  final double carbs;
  final DateTime date;

  FoodItem({
    required this.id,
    required this.name,
    required this.calories,
    required this.protein,
    required this.fat,
    required this.carbs,
    required this.date,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'calories': calories,
      'protein': protein,
      'fat': fat,
      'carbs': carbs,
      'date': date.toIso8601String(),
    };
  }

  factory FoodItem.fromMap(Map<String, dynamic> map) {
    return FoodItem(
      id: map['id'],
      name: map['name'],
      calories: map['calories'],
      protein: map['protein'],
      fat: map['fat'],
      carbs: map['carbs'],
      date: DateTime.parse(map['date']),
    );
  }
}
