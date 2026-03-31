import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/database_service.dart';
import 'meal_provider.dart';

class DailyNutritionSummary {
  final DateTime date;
  final int calories;
  final double protein;
  final double fat;
  final double carbs;

  const DailyNutritionSummary({
    required this.date,
    required this.calories,
    required this.protein,
    required this.fat,
    required this.carbs,
  });
}

Future<List<DailyNutritionSummary>> _fetchTrendData({int days = 14}) async {
  final now = DateTime.now();
  final startDate =
      DateTime(now.year, now.month, now.day).subtract(Duration(days: days - 1));
  final endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);

  final adapter = await DatabaseService().database;
  final maps = await adapter.query(
    'food_items',
    where: 'date BETWEEN ? AND ?',
    whereArgs: [startDate.toIso8601String(), endDate.toIso8601String()],
    orderBy: 'date ASC',
  );

  // Group by date key
  final grouped = <String, (int, double, double, double)>{};
  for (final map in maps) {
    final date = DateTime.parse(map['date'] as String);
    final key =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final prev = grouped[key];
    grouped[key] = (
      (prev?.$1 ?? 0) + (map['calories'] as int? ?? 0),
      (prev?.$2 ?? 0.0) + ((map['protein'] as num?)?.toDouble() ?? 0.0),
      (prev?.$3 ?? 0.0) + ((map['fat'] as num?)?.toDouble() ?? 0.0),
      (prev?.$4 ?? 0.0) + ((map['carbs'] as num?)?.toDouble() ?? 0.0),
    );
  }

  return List.generate(days, (i) {
    final date = startDate.add(Duration(days: i));
    final key =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final data = grouped[key];
    return DailyNutritionSummary(
      date: date,
      calories: data?.$1 ?? 0,
      protein: data?.$2 ?? 0.0,
      fat: data?.$3 ?? 0.0,
      carbs: data?.$4 ?? 0.0,
    );
  });
}

/// Past-14-day nutrition trend. Re-fetches whenever [mealProvider] changes.
final nutritionTrendProvider =
    FutureProvider<List<DailyNutritionSummary>>((ref) async {
  ref.watch(mealProvider); // re-execute when meals are added/removed
  return _fetchTrendData();
});
