import 'package:riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/water_log.dart';
import '../services/database_service.dart';

class WaterState {
  final List<WaterLog> todayLogs;
  final int dailyGoalMl;
  final bool isLoading;

  const WaterState({
    this.todayLogs = const [],
    this.dailyGoalMl = 2000,
    this.isLoading = false,
  });

  int get totalMl => todayLogs.fold(0, (sum, log) => sum + log.amountMl);

  double get progressFraction =>
      dailyGoalMl > 0 ? (totalMl / dailyGoalMl).clamp(0.0, 1.0) : 0.0;

  WaterState copyWith({
    List<WaterLog>? todayLogs,
    int? dailyGoalMl,
    bool? isLoading,
  }) =>
      WaterState(
        todayLogs: todayLogs ?? this.todayLogs,
        dailyGoalMl: dailyGoalMl ?? this.dailyGoalMl,
        isLoading: isLoading ?? this.isLoading,
      );
}

class WaterNotifier extends StateNotifier<WaterState> {
  WaterNotifier() : super(const WaterState()) {
    loadToday();
  }

  static const _uuid = Uuid();

  Future<void> loadToday() async {
    state = state.copyWith(isLoading: true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final goal = prefs.getInt('waterGoalMl') ?? 2000;

      final adapter = await DatabaseService().database;
      final today = DateTime.now();
      final startOfDay =
          DateTime(today.year, today.month, today.day).toIso8601String();
      final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59)
          .toIso8601String();

      final maps = await adapter.query(
        'water_logs',
        where: 'date BETWEEN ? AND ?',
        whereArgs: [startOfDay, endOfDay],
        orderBy: 'date ASC',
      );

      state = state.copyWith(
        todayLogs: maps.map(WaterLog.fromMap).toList(),
        dailyGoalMl: goal,
        isLoading: false,
      );
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> addLog(int amountMl) async {
    final log = WaterLog(
      id: _uuid.v4(),
      amountMl: amountMl,
      date: DateTime.now(),
    );
    final adapter = await DatabaseService().database;
    await adapter.insert('water_logs', log.toMap());
    state = state.copyWith(todayLogs: [...state.todayLogs, log]);
  }

  Future<void> removeLog(String id) async {
    final adapter = await DatabaseService().database;
    await adapter.delete('water_logs', where: 'id = ?', whereArgs: [id]);
    state = state.copyWith(
      todayLogs: state.todayLogs.where((l) => l.id != id).toList(),
    );
  }

  Future<void> setGoal(int goalMl) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('waterGoalMl', goalMl);
    state = state.copyWith(dailyGoalMl: goalMl);
  }
}

final waterProvider =
    StateNotifierProvider<WaterNotifier, WaterState>((_) => WaterNotifier());
