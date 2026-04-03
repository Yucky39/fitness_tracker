import 'package:riverpod/legacy.dart';
import '../models/food_item.dart';
import '../services/database_service.dart';

class DashboardState {
  final Map<DateTime, int> weeklyCalories;
  /// Calendar-today totals (local device date), independent of meal tab date.
  final int todayCalories;
  final double todayProtein;
  final double todayFat;
  final double todayCarbs;
  /// Today's food names, most recently logged first (for home panel).
  final List<String> todayRecentFoodNames;
  final bool isLoading;

  DashboardState({
    this.weeklyCalories = const {},
    this.todayCalories = 0,
    this.todayProtein = 0,
    this.todayFat = 0,
    this.todayCarbs = 0,
    this.todayRecentFoodNames = const [],
    this.isLoading = true,
  });

  DashboardState copyWith({
    Map<DateTime, int>? weeklyCalories,
    int? todayCalories,
    double? todayProtein,
    double? todayFat,
    double? todayCarbs,
    List<String>? todayRecentFoodNames,
    bool? isLoading,
  }) =>
      DashboardState(
        weeklyCalories: weeklyCalories ?? this.weeklyCalories,
        todayCalories: todayCalories ?? this.todayCalories,
        todayProtein: todayProtein ?? this.todayProtein,
        todayFat: todayFat ?? this.todayFat,
        todayCarbs: todayCarbs ?? this.todayCarbs,
        todayRecentFoodNames: todayRecentFoodNames ?? this.todayRecentFoodNames,
        isLoading: isLoading ?? this.isLoading,
      );
}

class DashboardNotifier extends StateNotifier<DashboardState> {
  DashboardNotifier() : super(DashboardState()) {
    loadWeeklyData();
  }

  Future<void> loadWeeklyData() async {
    state = state.copyWith(isLoading: true);
    final db = await DatabaseService().database;
    final now = DateTime.now();
    final weeklyCalories = <DateTime, int>{};

    for (int i = 6; i >= 0; i--) {
      final date = DateTime(now.year, now.month, now.day - i);
      final start = date.toIso8601String();
      final end = DateTime(date.year, date.month, date.day, 23, 59, 59)
          .toIso8601String();
      final maps = await db.query(
        'food_items',
        where: 'date BETWEEN ? AND ?',
        whereArgs: [start, end],
      );
      final calories =
          maps.fold<int>(0, (sum, m) => sum + (m['calories'] as int));
      weeklyCalories[date] = calories;
    }

    final todayStart =
        DateTime(now.year, now.month, now.day).toIso8601String();
    final todayEnd =
        DateTime(now.year, now.month, now.day, 23, 59, 59).toIso8601String();
    final todayMaps = await db.query(
      'food_items',
      where: 'date BETWEEN ? AND ?',
      whereArgs: [todayStart, todayEnd],
      orderBy: 'date DESC',
    );

    final todayItems = todayMaps.map(FoodItem.fromMap).toList();
    final todayCalories =
        todayItems.fold<int>(0, (s, e) => s + e.calories);
    final todayProtein =
        todayItems.fold<double>(0, (s, e) => s + e.protein);
    final todayFat = todayItems.fold<double>(0, (s, e) => s + e.fat);
    final todayCarbs =
        todayItems.fold<double>(0, (s, e) => s + e.carbs);

    final nameBuffer = <String>[];
    for (final item in todayItems) {
      if (nameBuffer.length >= 2) break;
      if (!nameBuffer.contains(item.name)) {
        nameBuffer.add(item.name);
      }
    }

    state = state.copyWith(
      weeklyCalories: weeklyCalories,
      todayCalories: todayCalories,
      todayProtein: todayProtein,
      todayFat: todayFat,
      todayCarbs: todayCarbs,
      todayRecentFoodNames: nameBuffer,
      isLoading: false,
    );
  }
}

final dashboardProvider =
    StateNotifierProvider<DashboardNotifier, DashboardState>(
        (_) => DashboardNotifier());
