/// ダッシュボード「期間サマリ」用のプリセット
enum SummaryPeriodKind {
  /// 直近7日（今日含む）
  week(7, '1週間'),

  /// 直近30日
  month(30, '1ヶ月'),

  /// 直近90日
  quarter(90, '3ヶ月');

  const SummaryPeriodKind(this.calendarDays, this.label);
  final int calendarDays;
  final String label;
}

/// 体重目標から推定する栄養面の意図（評価の基準に使用）
enum NutritionGoalMode {
  cut,
  maintain,
  bulk,
  unknown,
}

/// 期間集計の結果
class PeriodSummary {
  final SummaryPeriodKind kind;
  final DateTime rangeStart;
  final DateTime rangeEnd;
  final int totalFoodCalories;
  final double totalProtein;
  final double avgDailyCalories;
  final double avgDailyProtein;
  final int daysWithMealLogs;
  final int trainingLogCount;
  final int trainingActiveDays;
  final double trainingEstimatedKcal;
  final double? weightStartKg;
  final double? weightEndKg;
  final double? weightDeltaKg;
  final PeriodEvaluation evaluation;

  const PeriodSummary({
    required this.kind,
    required this.rangeStart,
    required this.rangeEnd,
    required this.totalFoodCalories,
    required this.totalProtein,
    required this.avgDailyCalories,
    required this.avgDailyProtein,
    required this.daysWithMealLogs,
    required this.trainingLogCount,
    required this.trainingActiveDays,
    required this.trainingEstimatedKcal,
    this.weightStartKg,
    this.weightEndKg,
    this.weightDeltaKg,
    required this.evaluation,
  });

  bool get hasAnyData =>
      totalFoodCalories > 0 || trainingLogCount > 0 || weightDeltaKg != null;
}

/// 総合評価（スコア・グレード・解説）
class PeriodEvaluation {
  final int score;
  final String grade;
  final String headline;
  final List<String> bullets;

  const PeriodEvaluation({
    required this.score,
    required this.grade,
    required this.headline,
    required this.bullets,
  });
}
