import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/food_item.dart';
import '../services/database_service.dart';

// State class for Meal Data
class MealState {
  final List<FoodItem> todayItems;
  final int calorieGoal;
  final double proteinGoal;
  final double fatGoal;
  final double carbsGoal;
  final bool isLoading;

  MealState({
    this.todayItems = const [],
    this.calorieGoal = 2000,
    this.proteinGoal = 150,
    this.fatGoal = 60,
    this.carbsGoal = 200,
    this.isLoading = true,
  });

  MealState copyWith({
    List<FoodItem>? todayItems,
    int? calorieGoal,
    double? proteinGoal,
    double? fatGoal,
    double? carbsGoal,
    bool? isLoading,
  }) {
    return MealState(
      todayItems: todayItems ?? this.todayItems,
      calorieGoal: calorieGoal ?? this.calorieGoal,
      proteinGoal: proteinGoal ?? this.proteinGoal,
      fatGoal: fatGoal ?? this.fatGoal,
      carbsGoal: carbsGoal ?? this.carbsGoal,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  int get totalCalories => todayItems.fold(0, (sum, item) => sum + item.calories);
  double get totalProtein => todayItems.fold(0, (sum, item) => sum + item.protein);
  double get totalFat => todayItems.fold(0, (sum, item) => sum + item.fat);
  double get totalCarbs => todayItems.fold(0, (sum, item) => sum + item.carbs);
}

// Notifier
class MealNotifier extends StateNotifier<MealState> {
  MealNotifier() : super(MealState()) {
    _loadData();
  }

  Future<void> _loadData() async {
    state = state.copyWith(isLoading: true);
    await _loadGoals();
    await _loadTodayItems();
    state = state.copyWith(isLoading: false);
  }

  Future<void> _loadGoals() async {
    final prefs = await SharedPreferences.getInstance();
    state = state.copyWith(
      calorieGoal: prefs.getInt('calorieGoal') ?? 2000,
      proteinGoal: prefs.getDouble('proteinGoal') ?? 150,
      fatGoal: prefs.getDouble('fatGoal') ?? 60,
      carbsGoal: prefs.getDouble('carbsGoal') ?? 200,
    );
  }

  Future<void> _loadTodayItems() async {
    final db = await DatabaseService().database;
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day).toIso8601String();
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59).toIso8601String();

    final List<Map<String, dynamic>> maps = await db.query(
      'food_items',
      where: 'date BETWEEN ? AND ?',
      whereArgs: [startOfDay, endOfDay],
    );

    state = state.copyWith(
      todayItems: List.generate(maps.length, (i) => FoodItem.fromMap(maps[i])),
    );
  }

  Future<void> updateGoals({
    required int calories,
    required double protein,
    required double fat,
    required double carbs,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('calorieGoal', calories);
    await prefs.setDouble('proteinGoal', protein);
    await prefs.setDouble('fatGoal', fat);
    await prefs.setDouble('carbsGoal', carbs);

    state = state.copyWith(
      calorieGoal: calories,
      proteinGoal: protein,
      fatGoal: fat,
      carbsGoal: carbs,
    );
  }

  Future<void> addFoodItem({
    required String name,
    required int calories,
    required double protein,
    required double fat,
    required double carbs,
  }) async {
    final db = await DatabaseService().database;
    final newItem = FoodItem(
      id: const Uuid().v4(),
      name: name,
      calories: calories,
      protein: protein,
      fat: fat,
      carbs: carbs,
      date: DateTime.now(),
    );

    await db.insert('food_items', newItem.toMap());
    await _loadTodayItems();
  }

  Future<void> deleteFoodItem(String id) async {
    final db = await DatabaseService().database;
    await db.delete('food_items', where: 'id = ?', whereArgs: [id]);
    await _loadTodayItems();
  }
}

final mealProvider = StateNotifierProvider<MealNotifier, MealState>((ref) {
  return MealNotifier();
});
