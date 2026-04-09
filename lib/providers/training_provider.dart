import 'package:intl/intl.dart';
import 'package:riverpod/legacy.dart';
import 'package:uuid/uuid.dart';
import '../models/training_log.dart';
import '../services/database_service.dart';
import '../services/health_service.dart';
import '../services/sync_service.dart';
import '../services/training_calorie_calculator.dart';

class TrainingState {
  final List<TrainingLog> logs;
  final bool isLoading;

  TrainingState({
    this.logs = const [],
    this.isLoading = true,
  });

  TrainingState copyWith({
    List<TrainingLog>? logs,
    bool? isLoading,
  }) {
    return TrainingState(
      logs: logs ?? this.logs,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  /// 今日のログ（端末ローカルの暦日。UTC のまま保存された記録も toLocal() で揃える）
  List<TrainingLog> get todayLogs {
    final n = DateTime.now();
    return logs.where((l) {
      final d = l.date.toLocal();
      return d.year == n.year && d.month == n.month && d.day == n.day;
    }).toList();
  }
}

class TrainingNotifier extends StateNotifier<TrainingState> {
  TrainingNotifier() : super(TrainingState()) {
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    state = state.copyWith(isLoading: true);
    final adapter = await DatabaseService().database;
    final List<Map<String, dynamic>> maps = await adapter.query(
      'training_logs',
      orderBy: 'date DESC',
    );
    state = state.copyWith(
      logs: maps.map(TrainingLog.fromMap).toList(),
      isLoading: false,
    );
  }

  Future<void> addLog({
    required String exerciseName,
    required ExerciseType exerciseType,
    required double weight,
    required int reps,
    required int sets,
    required int interval,
    double distanceKm = 0,
    int durationMinutes = 0,
    int? rpe,
    required String note,
  }) async {
    final adapter = await DatabaseService().database;
    final newLog = TrainingLog(
      id: const Uuid().v4(),
      exerciseName: exerciseName,
      exerciseType: exerciseType,
      weight: weight,
      reps: reps,
      sets: sets,
      interval: interval,
      distanceKm: distanceKm,
      durationMinutes: durationMinutes,
      rpe: rpe,
      note: note,
      date: DateTime.now(),
    );
    await adapter.insert('training_logs', newLog.toMap());
    SyncService().syncRecord('training_logs', newLog.toMap());
    await _loadLogs();
  }

  /// HealthKit / Health Connect から取得済みの TrainingLog をそのまま保存
  Future<void> addLogFromHealth(TrainingLog log) async {
    final adapter = await DatabaseService().database;
    await adapter.insert('training_logs', log.toMap());
    SyncService().syncRecord('training_logs', log.toMap());
    await _loadLogs();
  }

  /// ヘルスケアに同期されたワークアウト（ウェアラブル等）を取り込み、DB にレコードとして保存する。
  /// 既に同じソースUUIDまたは同一時刻の旧形式レコードがある場合はスキップする。
  /// 取り込んだ件数を返す。
  Future<int> syncWorkoutsFromHealth({int days = 90}) async {
    if (!HealthService.isSupported) return 0;
    await HealthService.requestPermissions();
    final workouts = await HealthService.fetchRecentWorkouts(days: days);
    if (workouts.isEmpty) return 0;

    final existingUuids = <String>{};
    final legacyKeys = <String>{};
    for (final l in state.logs) {
      final u = TrainingLog.healthImportUuidFromNote(l.note);
      if (u != null && u.isNotEmpty) {
        existingUuids.add(u);
      } else if (l.note == TrainingLog.healthImportNotePrefix) {
        legacyKeys.add(_healthWorkoutLegacyKey(l));
      }
    }

    var added = 0;
    for (final w in workouts) {
      final u = TrainingLog.healthImportUuidFromNote(w.note);
      if (u != null && u.isNotEmpty && existingUuids.contains(u)) continue;

      final key = _healthWorkoutLegacyKey(w);
      if (legacyKeys.contains(key)) continue;

      if (u != null && u.isNotEmpty) existingUuids.add(u);
      legacyKeys.add(key);

      await addLogFromHealth(w);
      added++;
    }
    return added;
  }

  String _healthWorkoutLegacyKey(TrainingLog l) {
    final d = l.date.toLocal();
    return '${l.exerciseName}_${DateFormat('yyyyMMddHHmm').format(d)}';
  }

  Future<void> updateLog(TrainingLog updated) async {
    final adapter = await DatabaseService().database;
    await adapter.update(
      'training_logs',
      updated.toMap(),
      where: 'id = ?',
      whereArgs: [updated.id],
    );
    SyncService().syncRecord('training_logs', updated.toMap());
    await _loadLogs();
  }

  Future<void> deleteLog(String id) async {
    final adapter = await DatabaseService().database;
    await adapter.delete('training_logs', where: 'id = ?', whereArgs: [id]);
    SyncService().deleteRecord('training_logs', id);
    await _loadLogs();
  }

  /// AI評価テキストのみを更新（DB部分更新 + インメモリ反映）
  Future<void> updateLogAdvice(String logId, String advice) async {
    final adapter = await DatabaseService().database;
    await adapter.update(
      'training_logs',
      {'ai_advice': advice},
      where: 'id = ?',
      whereArgs: [logId],
    );
    state = state.copyWith(
      logs: state.logs
          .map((l) => l.id == logId ? l.copyWith(aiAdvice: advice) : l)
          .toList(),
    );
  }

  /// 指定種目の直近ログ（編集対象以外）
  TrainingLog? getPreviousLog(String exerciseName, {String? excludeId}) {
    try {
      return state.logs.firstWhere(
        (log) =>
            log.exerciseName == exerciseName &&
            (excludeId == null || log.id != excludeId),
      );
    } catch (_) {
      return null;
    }
  }

  /// 指定種目の自己ベスト (1RM換算: weight × (1 + reps/30))
  double getBestOneRepMax(String exerciseName, {String? excludeId}) {
    final candidates = state.logs.where((l) =>
        l.exerciseName == exerciseName &&
        l.exerciseType != ExerciseType.cardio &&
        (excludeId == null || l.id != excludeId));
    if (candidates.isEmpty) return 0;
    return candidates
        .map((l) => l.weight * (1 + l.reps / 30.0))
        .reduce((a, b) => a > b ? a : b);
  }

  /// 指定種目の最大重量
  double getBestWeight(String exerciseName, {String? excludeId}) {
    final candidates = state.logs.where((l) =>
        l.exerciseName == exerciseName &&
        l.exerciseType != ExerciseType.cardio &&
        (excludeId == null || l.id != excludeId));
    if (candidates.isEmpty) return 0;
    return candidates.map((l) => l.weight).reduce((a, b) => a > b ? a : b);
  }

  /// 記録が自己ベスト（最大重量）を更新しているか（有酸素種目は対象外）
  bool isPersonalRecord(TrainingLog log) {
    if (log.exerciseType == ExerciseType.cardio) return false;
    final best = getBestWeight(log.exerciseName, excludeId: log.id);
    return best > 0 && log.weight >= best;
  }

  /// 1RM換算値
  static double oneRepMax(double weight, int reps) {
    if (reps <= 0 || weight <= 0) return 0;
    return weight * (1 + reps / 30.0);
  }

  /// 消費カロリー推定
  static double estimateCalories(
    TrainingLog log, {
    double bodyWeightKg = TrainingCalorieCalculator.defaultBodyWeightKg,
  }) =>
      TrainingCalorieCalculator.estimate(
        weight: log.weight,
        reps: log.reps,
        sets: log.sets,
        intervalSec: log.interval,
        exerciseType: log.exerciseType,
        bodyWeightKg: bodyWeightKg,
        exerciseName: log.exerciseName,
        durationMinutes: log.durationMinutes,
      );
}

final trainingProvider =
    StateNotifierProvider<TrainingNotifier, TrainingState>((ref) {
  return TrainingNotifier();
});
