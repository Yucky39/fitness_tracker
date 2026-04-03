import 'dart:io';
import 'package:health/health.dart';
import 'package:uuid/uuid.dart';
import '../models/training_log.dart';

/// デバイスのヘルスケア情報（iOS HealthKit / Android Health Connect）から
/// ワークアウトデータを取得して TrainingLog に変換するサービス。
class HealthService {
  HealthService._();

  static final Health _health = Health();

  static const List<HealthDataType> _types = [HealthDataType.WORKOUT];
  static const List<HealthDataAccess> _permissions = [HealthDataAccess.READ];

  /// iOS / Android のみ対応
  static bool get isSupported => Platform.isIOS || Platform.isAndroid;

  /// ヘルスケアの読み取り権限をリクエストする。
  /// 許可された場合 true を返す。
  static Future<bool> requestPermissions() async {
    if (!isSupported) return false;
    try {
      return await _health.requestAuthorization(_types,
          permissions: _permissions);
    } catch (_) {
      return false;
    }
  }

  /// 直近 [days] 日間のワークアウトを取得して TrainingLog リストに変換する。
  /// 権限がない場合や取得失敗時は空リストを返す。
  static Future<List<TrainingLog>> fetchRecentWorkouts({int days = 30}) async {
    if (!isSupported) return [];
    try {
      final end = DateTime.now();
      final start = end.subtract(Duration(days: days));

      final data = await _health.getHealthDataFromTypes(
        startTime: start,
        endTime: end,
        types: _types,
      );

      return data
          .where((p) => p.value is WorkoutHealthValue)
          .map(_toTrainingLog)
          .toList();
    } catch (_) {
      return [];
    }
  }

  static TrainingLog _toTrainingLog(HealthDataPoint point) {
    final workout = point.value as WorkoutHealthValue;
    final durationMin = point.dateTo.difference(point.dateFrom).inMinutes;
    // iOS: totalDistance は meters 単位
    final distanceKm =
        workout.totalDistance != null && workout.totalDistance! > 0
            ? workout.totalDistance! / 1000.0
            : 0.0;

    return TrainingLog(
      id: const Uuid().v4(),
      exerciseName: _activityName(workout.workoutActivityType),
      exerciseType: ExerciseType.cardio,
      weight: 0,
      reps: 0,
      sets: 0,
      interval: 0,
      distanceKm: distanceKm,
      durationMinutes: durationMin,
      note: 'ヘルスケアから取得',
      // 一覧・「今日」判定が端末の暦日と一致するようローカル時刻で保存
      date: point.dateFrom.toLocal(),
    );
  }

  /// HealthWorkoutActivityType を日本語の種目名にマッピング
  static String _activityName(HealthWorkoutActivityType? type) {
    switch (type) {
      case HealthWorkoutActivityType.RUNNING:
        return 'ランニング';
      case HealthWorkoutActivityType.WALKING:
        return 'ウォーキング';
      case HealthWorkoutActivityType.BIKING:
        return 'サイクリング';
      case HealthWorkoutActivityType.SWIMMING_OPEN_WATER:
      case HealthWorkoutActivityType.SWIMMING_POOL:
        return '水泳';
      case HealthWorkoutActivityType.HIGH_INTENSITY_INTERVAL_TRAINING:
        return 'HIIT';
      case HealthWorkoutActivityType.JUMP_ROPE:
        return 'ジャンプロープ';
      case HealthWorkoutActivityType.ELLIPTICAL:
        return 'エリプティカル';
      case HealthWorkoutActivityType.ROWING:
        return 'ローイングマシン';
      case HealthWorkoutActivityType.CARDIO_DANCE:
      case HealthWorkoutActivityType.STEP_TRAINING:
        return 'エアロビクス';
      default:
        return '有酸素運動';
    }
  }
}
