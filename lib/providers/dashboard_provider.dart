import 'package:riverpod/legacy.dart';
import '../services/database_service.dart';

class DashboardState {
  final Map<DateTime, int> weeklyCalories;
  final bool isLoading;

  DashboardState({this.weeklyCalories = const {}, this.isLoading = true});

  DashboardState copyWith(
          {Map<DateTime, int>? weeklyCalories, bool? isLoading}) =>
      DashboardState(
        weeklyCalories: weeklyCalories ?? this.weeklyCalories,
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
      final end =
          DateTime(date.year, date.month, date.day, 23, 59, 59).toIso8601String();
      final maps = await db.query(
        'food_items',
        where: 'date BETWEEN ? AND ?',
        whereArgs: [start, end],
      );
      final calories =
          maps.fold<int>(0, (sum, m) => sum + (m['calories'] as int));
      weeklyCalories[date] = calories;
    }

    state =
        state.copyWith(weeklyCalories: weeklyCalories, isLoading: false);
  }
}

final dashboardProvider =
    StateNotifierProvider<DashboardNotifier, DashboardState>(
        (_) => DashboardNotifier());
