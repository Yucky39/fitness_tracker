import 'dart:io';
import 'package:health/health.dart';
import 'package:uuid/uuid.dart';
import '../models/training_log.dart';

/// デバイスのヘルスケア情報（iOS HealthKit / Android Health Connect）から
/// ワークアウト・睡眠・歩数データを取得するサービス。
class HealthService {
  HealthService._();

  static final Health _health = Health();

  static const List<HealthDataType> _workoutTypes = [HealthDataType.WORKOUT];
  static const List<HealthDataType> _sleepTypes = [
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.SLEEP_IN_BED,
  ];
  static const List<HealthDataType> _stepTypes = [HealthDataType.STEPS];
  static const List<HealthDataAccess> _readOnly = [HealthDataAccess.READ];

  /// iOS / Android のみ対応
  static bool get isSupported => Platform.isIOS || Platform.isAndroid;

  /// ワークアウト・睡眠・歩数の読み取り権限を一括リクエストする。
  /// iOS HealthKit はここで宣言した型だけが設定画面に表示される。
  static Future<bool> requestPermissions() async {
    if (!isSupported) return false;
    try {
      return await _health.requestAuthorization(
        [..._workoutTypes, ..._sleepTypes, ..._stepTypes],
        permissions: [
          ..._readOnly,
          ..._readOnly,
          ..._readOnly,
        ],
      );
    } catch (_) {
      return false;
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Sleep
  // ──────────────────────────────────────────────────────────────────────────

  /// 睡眠の読み取り権限がすでに付与されているか確認する。
  static Future<bool> hasSleepPermission() async {
    if (!isSupported) return false;
    try {
      final result =
          await _health.hasPermissions(_sleepTypes, permissions: _readOnly);
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// 睡眠の読み取り権限をリクエストする。
  static Future<bool> requestSleepPermission() async {
    if (!isSupported) return false;
    try {
      return await _health.requestAuthorization(_sleepTypes,
          permissions: _readOnly);
    } catch (_) {
      return false;
    }
  }

  /// 昨夜の睡眠時間（分）を返す。
  ///
  /// 「昨日の正午〜今日の正午」の範囲でクエリする。
  /// まず SLEEP_ASLEEP（実際の睡眠段階データ）を試み、
  /// データがなければ SLEEP_IN_BED（就寝時間全体）にフォールバックする。
  /// 取得失敗・権限なし・データなしの場合は null を返す。
  static Future<int?> fetchLastNightSleepMinutes() async {
    if (!isSupported) return null;
    try {
      final now = DateTime.now();
      final todayNoon = DateTime(now.year, now.month, now.day, 12);
      final yesterdayNoon = todayNoon.subtract(const Duration(days: 1));

      // まず SLEEP_ASLEEP（実睡眠ステージ）を試みる
      final asleepData = await _health.getHealthDataFromTypes(
        startTime: yesterdayNoon,
        endTime: todayNoon,
        types: [HealthDataType.SLEEP_ASLEEP],
      );

      if (asleepData.isNotEmpty) {
        int total = 0;
        for (final point in asleepData) {
          total += point.dateTo.difference(point.dateFrom).inMinutes;
        }
        if (total > 0) return total;
      }

      // フォールバック: SLEEP_IN_BED（全就寝時間）
      final inBedData = await _health.getHealthDataFromTypes(
        startTime: yesterdayNoon,
        endTime: todayNoon,
        types: [HealthDataType.SLEEP_IN_BED],
      );

      if (inBedData.isEmpty) return null;

      int total = 0;
      for (final point in inBedData) {
        total += point.dateTo.difference(point.dateFrom).inMinutes;
      }
      return total > 0 ? total : null;
    } catch (_) {
      return null;
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Steps
  // ──────────────────────────────────────────────────────────────────────────

  /// 歩数の読み取り権限がすでに付与されているか確認する。
  static Future<bool> hasStepPermission() async {
    if (!isSupported) return false;
    try {
      final result =
          await _health.hasPermissions(_stepTypes, permissions: _readOnly);
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// 歩数の読み取り権限をリクエストする。
  static Future<bool> requestStepPermission() async {
    if (!isSupported) return false;
    try {
      return await _health.requestAuthorization(_stepTypes,
          permissions: _readOnly);
    } catch (_) {
      return false;
    }
  }

  /// 今日 0:00〜現在の合計歩数を返す。
  /// 権限がない／取得失敗時は null を返す。
  static Future<int?> fetchTodaySteps() async {
    if (!isSupported) return null;
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final steps = await _health.getTotalStepsInInterval(startOfDay, now);
      return steps;
    } catch (_) {
      return null;
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Workouts
  // ──────────────────────────────────────────────────────────────────────────

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
        types: _workoutTypes,
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
      rpe: null,
      note: 'ヘルスケアから取得',
      date: point.dateFrom,
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
