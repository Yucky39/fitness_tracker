import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/food_item.dart';
import '../services/database_service.dart';
import '../services/sync_service.dart';

class MealState {
  final List<FoodItem> todayItems;
  final List<FoodItem> recentFoods;
  final DateTime selectedDate;
  final int calorieGoal;
  final double proteinGoal;
  final double fatGoal;
  final double carbsGoal;
  final bool isLoading;

  MealState({
    this.todayItems = const [],
    this.recentFoods = const [],
    DateTime? selectedDate,
    this.calorieGoal = 2000,
    this.proteinGoal = 150,
    this.fatGoal = 60,
    this.carbsGoal = 200,
    this.isLoading = true,
  }) : selectedDate = selectedDate ?? DateTime.now();

  MealState copyWith({
    List<FoodItem>? todayItems,
    List<FoodItem>? recentFoods,
    DateTime? selectedDate,
    int? calorieGoal,
    double? proteinGoal,
    double? fatGoal,
    double? carbsGoal,
    bool? isLoading,
  }) {
    return MealState(
      todayItems: todayItems ?? this.todayItems,
      recentFoods: recentFoods ?? this.recentFoods,
      selectedDate: selectedDate ?? this.selectedDate,
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
  double get totalSugar => todayItems.fold(0.0, (sum, item) => sum + item.sugar);
  double get totalFiber => todayItems.fold(0.0, (sum, item) => sum + item.fiber);
  double get totalSodium => todayItems.fold(0.0, (sum, item) => sum + item.sodium);

  /// 食事タイプごとのカロリー合計（表示順は [MealType.values]）
  Map<MealType, int> get caloriesByMealType {
    final map = {for (final t in MealType.values) t: 0};
    for (final item in todayItems) {
      map[item.mealType] = (map[item.mealType] ?? 0) + item.calories;
    }
    return map;
  }
}

class MealNotifier extends StateNotifier<MealState> {
  MealNotifier() : super(MealState()) {
    _loadData();
  }

  Future<void> _loadData() async {
    state = state.copyWith(isLoading: true);
    try {
      await _loadGoals();
      await _loadItemsForDate(state.selectedDate);
      await _loadRecentFoods();
    } finally {
      state = state.copyWith(isLoading: false);
    }
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

  Future<void> _loadItemsForDate(DateTime date) async {
    final adapter = await DatabaseService().database;
    final startOfDay = DateTime(date.year, date.month, date.day).toIso8601String();
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59).toIso8601String();

    final List<Map<String, dynamic>> maps = await adapter.query(
      'food_items',
      where: 'date BETWEEN ? AND ?',
      whereArgs: [startOfDay, endOfDay],
      orderBy: 'date ASC',
    );

    state = state.copyWith(
      todayItems: maps.map(FoodItem.fromMap).toList(),
    );
  }

  Future<void> _loadRecentFoods() async {
    final adapter = await DatabaseService().database;
    final List<Map<String, dynamic>> maps = await adapter.query(
      'food_items',
      orderBy: 'date DESC',
      limit: 200,
    );

    final seen = <String>{};
    final recentFoods = <FoodItem>[];
    for (final map in maps) {
      final item = FoodItem.fromMap(map);
      if (!seen.contains(item.name) && recentFoods.length < 20) {
        seen.add(item.name);
        recentFoods.add(item);
      }
    }

    state = state.copyWith(recentFoods: recentFoods);
  }

  Future<void> changeDate(DateTime date) async {
    state = state.copyWith(selectedDate: date);
    await _loadItemsForDate(date);
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
    double sugar = 0.0,
    double fiber = 0.0,
    double sodium = 0.0,
    MealType? mealType,
  }) async {
    final adapter = await DatabaseService().database;
    final now = DateTime.now();
    final selectedDate = state.selectedDate;
    final newItem = FoodItem(
      id: const Uuid().v4(),
      name: name,
      calories: calories,
      protein: protein,
      fat: fat,
      carbs: carbs,
      sugar: sugar,
      fiber: fiber,
      sodium: sodium,
      mealType: mealType ?? MealType.detectFromTime(now),
      date: DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        now.hour,
        now.minute,
        now.second,
      ),
    );

    await adapter.insert('food_items', newItem.toMap());
    SyncService().syncRecord('food_items', newItem.toMap());
    await _loadItemsForDate(state.selectedDate);
    await _loadRecentFoods();
  }

  Future<void> updateFoodItem(FoodItem updated) async {
    final adapter = await DatabaseService().database;
    await adapter.update(
      'food_items',
      updated.toMap(),
      where: 'id = ?',
      whereArgs: [updated.id],
    );
    SyncService().syncRecord('food_items', updated.toMap());
    await _loadItemsForDate(state.selectedDate);
    await _loadRecentFoods();
  }

  Future<void> deleteFoodItem(String id) async {
    final adapter = await DatabaseService().database;
    await adapter.delete('food_items', where: 'id = ?', whereArgs: [id]);
    SyncService().deleteRecord('food_items', id);
    await _loadItemsForDate(state.selectedDate);
    await _loadRecentFoods();
  }
}

final mealProvider = StateNotifierProvider<MealNotifier, MealState>((ref) {
  return MealNotifier();
});
