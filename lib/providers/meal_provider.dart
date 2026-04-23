import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/detailed_nutrients.dart';
import '../models/food_item.dart';
import '../models/micronutrients.dart';
import '../services/database_service.dart';
import '../services/sync_service.dart';
import 'achievement_provider.dart';
import 'dashboard_provider.dart';

class MealState {
  final List<FoodItem> todayItems;
  final List<FoodItem> recentFoods;
  final DateTime selectedDate;
  final int calorieGoal;
  final double proteinGoal;
  final double fatGoal;
  final double carbsGoal;
  final double fiberGoal;
  final double sodiumGoal;
  final bool isLoading;

  /// 食事の追加・更新・削除のたびに増やす。日付変更だけでは増やさない（サマリ再計算のトリガー用）。
  final int mealDataEpoch;

  MealState({
    this.todayItems = const [],
    this.recentFoods = const [],
    DateTime? selectedDate,
    this.calorieGoal = 2000,
    this.proteinGoal = 150,
    this.fatGoal = 60,
    this.carbsGoal = 200,
    this.fiberGoal = 25,
    this.sodiumGoal = 2300,
    this.isLoading = true,
    this.mealDataEpoch = 0,
  }) : selectedDate = selectedDate ?? DateTime.now();

  MealState copyWith({
    List<FoodItem>? todayItems,
    List<FoodItem>? recentFoods,
    DateTime? selectedDate,
    int? calorieGoal,
    double? proteinGoal,
    double? fatGoal,
    double? carbsGoal,
    double? fiberGoal,
    double? sodiumGoal,
    bool? isLoading,
    int? mealDataEpoch,
  }) {
    return MealState(
      todayItems: todayItems ?? this.todayItems,
      recentFoods: recentFoods ?? this.recentFoods,
      selectedDate: selectedDate ?? this.selectedDate,
      calorieGoal: calorieGoal ?? this.calorieGoal,
      proteinGoal: proteinGoal ?? this.proteinGoal,
      fatGoal: fatGoal ?? this.fatGoal,
      carbsGoal: carbsGoal ?? this.carbsGoal,
      fiberGoal: fiberGoal ?? this.fiberGoal,
      sodiumGoal: sodiumGoal ?? this.sodiumGoal,
      isLoading: isLoading ?? this.isLoading,
      mealDataEpoch: mealDataEpoch ?? this.mealDataEpoch,
    );
  }

  int get totalCalories => todayItems.fold(0, (sum, item) => sum + item.calories);
  double get totalProtein => todayItems.fold(0, (sum, item) => sum + item.protein);
  double get totalFat => todayItems.fold(0, (sum, item) => sum + item.fat);
  double get totalCarbs => todayItems.fold(0, (sum, item) => sum + item.carbs);
  double get totalSugar => todayItems.fold(0.0, (sum, item) => sum + item.sugar);
  double get totalFiber => todayItems.fold(0.0, (sum, item) => sum + item.fiber);
  double get totalSodium => todayItems.fold(0.0, (sum, item) => sum + item.sodium);

  Micronutrients get totalMicronutrients => todayItems.fold<Micronutrients>(
        Micronutrients.zero,
        (sum, item) => sum + item.micronutrients,
      );

  DetailedNutrients get totalDetailedNutrients => todayItems.fold<DetailedNutrients>(
        DetailedNutrients.zero,
        (sum, item) => sum + item.detailedNutrients,
      );

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
  MealNotifier(this._ref) : super(MealState()) {
    _loadData();
  }

  final Ref _ref;

  void _invalidateDashboard() {
    _ref.invalidate(dashboardProvider);
  }

  void _bumpMealDataEpoch() {
    state = state.copyWith(mealDataEpoch: state.mealDataEpoch + 1);
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
      fiberGoal: prefs.getDouble('fiberGoal') ?? 25,
      sodiumGoal: prefs.getDouble('sodiumGoal') ?? 2300,
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
      if (item.mealType == MealType.supplement) continue;
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
    double? fiber,
    double? sodium,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('calorieGoal', calories);
    await prefs.setDouble('proteinGoal', protein);
    await prefs.setDouble('fatGoal', fat);
    await prefs.setDouble('carbsGoal', carbs);
    if (fiber != null) await prefs.setDouble('fiberGoal', fiber);
    if (sodium != null) await prefs.setDouble('sodiumGoal', sodium);

    state = state.copyWith(
      calorieGoal: calories,
      proteinGoal: protein,
      fatGoal: fat,
      carbsGoal: carbs,
      fiberGoal: fiber ?? state.fiberGoal,
      sodiumGoal: sodium ?? state.sodiumGoal,
    );
    _bumpMealDataEpoch();
    _invalidateDashboard();
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
    Micronutrients micronutrients = Micronutrients.zero,
    DetailedNutrients detailedNutrients = DetailedNutrients.zero,
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
      micronutrients: micronutrients,
      detailedNutrients: detailedNutrients,
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
    _bumpMealDataEpoch();
    _invalidateDashboard();
    // バッジ評価
    _ref.read(achievementProvider.notifier).onNutritionLogged(state.todayItems.length);
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
    _bumpMealDataEpoch();
    _invalidateDashboard();
  }

  Future<void> deleteFoodItem(String id) async {
    final adapter = await DatabaseService().database;
    await adapter.delete('food_items', where: 'id = ?', whereArgs: [id]);
    SyncService().deleteRecord('food_items', id);
    await _loadItemsForDate(state.selectedDate);
    await _loadRecentFoods();
    _bumpMealDataEpoch();
    _invalidateDashboard();
  }
}

final mealProvider = StateNotifierProvider<MealNotifier, MealState>((ref) {
  return MealNotifier(ref);
});
