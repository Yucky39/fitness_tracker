import '../models/training_log.dart';

/// レジスタンストレーニングの消費カロリーを推定する。
///
/// 計算式:
///   消費kcal ≈ 総挙上量(kg) × 係数 + 安静時代謝分
///
/// 係数の根拠 (Lyle McDonald式 + METs を組み合わせた近似):
///   - フリーウェイト(コンパウンド系): 0.032 kcal/kg·rep
///   - マシン・アイソレーション:      0.024 kcal/kg·rep
///   - 自重:  体重の60%相当を使用, 係数 0.032
///
/// インターバル中の代謝分:
///   セット間休憩 × MET(2.0軽歩相当) × bodyWeight_kg / 60
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

  /// 1セッション（1種目の記録）の推定消費カロリー
  ///
  /// [weight]      : 扱った重量(kg)。自重種目の場合は0で良い。
  /// [reps]        : 1セットの回数
  /// [sets]        : セット数
  /// [intervalSec] : セット間インターバル(秒)
  /// [exerciseType]: 種目カテゴリ
  /// [bodyWeightKg]: ユーザーの体重(kg) — 自重種目の計算に使用
  static double estimate({
    required double weight,
    required int reps,
    required int sets,
    required int intervalSec,
    required ExerciseType exerciseType,
    double bodyWeightKg = defaultBodyWeightKg,
  }) {
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
  static double total(List<TrainingLog> logs, {double bodyWeightKg = defaultBodyWeightKg}) {
    return logs.fold(0.0, (sum, log) => sum + estimate(
      weight: log.weight,
      reps: log.reps,
      sets: log.sets,
      intervalSec: log.interval,
      exerciseType: log.exerciseType,
      bodyWeightKg: bodyWeightKg,
    ));
  }
}
