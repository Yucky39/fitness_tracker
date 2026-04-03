import '../models/training_log.dart';

/// レジスタンス・有酸素トレーニングの消費カロリーを推定する。
///
/// 【筋トレ計算式】
///   消費kcal ≈ 総挙上量(kg) × 係数 + 安静時代謝分
///
///   係数の根拠 (Lyle McDonald式 + METs を組み合わせた近似):
///     - フリーウェイト(コンパウンド系): 0.032 kcal/kg·rep
///     - マシン・アイソレーション:      0.024 kcal/kg·rep
///     - 自重:  体重の60%相当を使用, 係数 0.032
///
/// 【有酸素計算式】
///   消費kcal = MET × 体重(kg) × 時間(h)
///
///   MET参考値 (Compendium of Physical Activities 2011):
///     ランニング (8 km/h): 9.8 / ウォーキング: 3.5 / サイクリング: 7.5 等
///
/// 参考: NSCA Essentials of Strength Training and Conditioning 4th Ed.
class TrainingCalorieCalculator {
  TrainingCalorieCalculator._();

  /// [bodyWeightKg] 未設定時のデフォルト体重
  static const double defaultBodyWeightKg = 70.0;

  static const Map<ExerciseType, double> _liftCoeff = {
    ExerciseType.freeWeight: 0.032,
    ExerciseType.machine: 0.024,
    ExerciseType.bodyweight: 0.032,
  };

  /// 種目名に対応する MET 値 (有酸素運動用)
  static const Map<String, double> _cardioMet = {
    'ランニング': 9.8,
    'トレッドミル': 9.8,
    'ウォーキング': 3.5,
    'サイクリング': 7.5,
    '水泳': 7.0,
    'HIIT': 10.0,
    'ジャンプロープ': 11.0,
    'エアロビクス': 6.5,
    'ローイングマシン': 7.0,
    'エリプティカル': 5.0,
  };

  /// デフォルト MET (上記に含まれない有酸素種目)
  static const double _defaultCardioMet = 6.0;

  /// 1セッション（1種目の記録）の推定消費カロリー
  ///
  /// 【筋トレ】
  /// [weight]      : 扱った重量(kg)。自重種目の場合は0で良い。
  /// [reps]        : 1セットの回数
  /// [sets]        : セット数
  /// [intervalSec] : セット間インターバル(秒)
  ///
  /// 【有酸素】
  /// [exerciseName]   : 種目名（MET参照用）
  /// [durationMinutes]: 運動時間(分)
  static double estimate({
    required double weight,
    required int reps,
    required int sets,
    required int intervalSec,
    required ExerciseType exerciseType,
    double bodyWeightKg = defaultBodyWeightKg,
    String exerciseName = '',
    int durationMinutes = 0,
  }) {
    if (exerciseType == ExerciseType.cardio) {
      if (durationMinutes <= 0) return 0;
      final met = _cardioMet[exerciseName] ?? _defaultCardioMet;
      return met * bodyWeightKg * (durationMinutes / 60.0);
    }

    if (reps <= 0 || sets <= 0) return 0;

    // 自重の場合は体重の60%を有効重量とする (プッシュアップ等の近似値)
    final effectiveWeight = exerciseType == ExerciseType.bodyweight
        ? (weight > 0 ? weight + bodyWeightKg * 0.6 : bodyWeightKg * 0.6)
        : weight;

    final coeff = _liftCoeff[exerciseType] ?? 0.032;

    // 挙上仕事量ベース
    final liftCalories = effectiveWeight * reps * sets * coeff;

    // インターバル中の代謝 (MET ≈ 2.0 for standing rest)
    final restSeconds = (sets - 1) * intervalSec.clamp(0, 600);
    final restCalories = 2.0 * bodyWeightKg * (restSeconds / 3600.0);

    return liftCalories + restCalories;
  }

  /// [logs] に含まれる全セッションの合計消費カロリー
  static double total(List<TrainingLog> logs,
      {double bodyWeightKg = defaultBodyWeightKg}) {
    return logs.fold(
        0.0,
        (sum, log) =>
            sum +
            estimate(
              weight: log.weight,
              reps: log.reps,
              sets: log.sets,
              intervalSec: log.interval,
              exerciseType: log.exerciseType,
              bodyWeightKg: bodyWeightKg,
              exerciseName: log.exerciseName,
              durationMinutes: log.durationMinutes,
            ));
  }
}
