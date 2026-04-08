import '../models/body_metrics.dart';
import '../models/food_item.dart';
import '../models/period_summary.dart';
import '../models/training_log.dart';
import 'database_service.dart';
import 'training_calorie_calculator.dart';

/// 指定期間の食事・トレ・体組成を集計し、目標に対する簡易評価を付与する。
class PeriodSummaryService {
  PeriodSummaryService._();

  static NutritionGoalMode goalMode({
    required double currentWeightKg,
    required double targetWeightKg,
  }) {
    if (currentWeightKg <= 0 || targetWeightKg <= 0) {
      return NutritionGoalMode.unknown;
    }
    if (targetWeightKg < currentWeightKg - 0.4) return NutritionGoalMode.cut;
    if (targetWeightKg > currentWeightKg + 0.4) return NutritionGoalMode.bulk;
    return NutritionGoalMode.maintain;
  }

  static ({DateTime start, DateTime end}) _range(SummaryPeriodKind kind) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startDay = today.subtract(Duration(days: kind.calendarDays - 1));
    final start = DateTime(startDay.year, startDay.month, startDay.day);
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
    return (start: start, end: end);
  }

  static Future<PeriodSummary> build({
    required SummaryPeriodKind kind,
    required int calorieGoal,
    required double proteinGoal,
    required double bodyWeightKg,
    double? profileWeightKg,
    double? targetWeightKg,
  }) async {
    final range = _range(kind);
    final startStr = range.start.toIso8601String();
    final endStr = range.end.toIso8601String();

    final db = await DatabaseService().database;

    final foodMaps = await db.query(
      'food_items',
      where: 'date BETWEEN ? AND ?',
      whereArgs: [startStr, endStr],
    );
    final foods = foodMaps.map(FoodItem.fromMap).toList();

    final trainingMaps = await db.query(
      'training_logs',
      where: 'date BETWEEN ? AND ?',
      whereArgs: [startStr, endStr],
      orderBy: 'date ASC',
    );
    final trainings = trainingMaps.map(TrainingLog.fromMap).toList();

    final metricsMaps = await db.query(
      'body_metrics',
      where: 'date BETWEEN ? AND ?',
      whereArgs: [startStr, endStr],
      orderBy: 'date ASC',
    );
    final metrics = metricsMaps.map(BodyMetrics.fromMap).toList();

    final w = bodyWeightKg > 0
        ? bodyWeightKg
        : TrainingCalorieCalculator.defaultBodyWeightKg;

    var totalCal = 0;
    var totalProt = 0.0;
    final mealDays = <String>{};
    for (final f in foods) {
      totalCal += f.calories;
      totalProt += f.protein;
      final d = f.date.toLocal();
      mealDays.add('${d.year}-${d.month}-${d.day}');
    }

    final days = kind.calendarDays;
    final avgDailyCal = totalCal / days;
    final avgDailyProt = totalProt / days;

    final trainKcal =
        TrainingCalorieCalculator.total(trainings, bodyWeightKg: w);
    final trainDays = <String>{};
    for (final log in trainings) {
      final d = log.date.toLocal();
      trainDays.add('${d.year}-${d.month}-${d.day}');
    }

    double? wStart;
    double? wEnd;
    double? wDelta;
    if (metrics.length >= 2) {
      wStart = metrics.first.weight;
      wEnd = metrics.last.weight;
      wDelta = wEnd - wStart;
    } else if (metrics.length == 1) {
      wEnd = metrics.first.weight;
    }

    final mode = goalMode(
      currentWeightKg: profileWeightKg ?? 0,
      targetWeightKg: targetWeightKg ?? 0,
    );

    final evaluation = _evaluate(
      kind: kind,
      mode: mode,
      calorieGoal: calorieGoal,
      proteinGoal: proteinGoal,
      avgDailyCalories: avgDailyCal,
      avgDailyProtein: avgDailyProt,
      trainingActiveDays: trainDays.length,
      trainingLogCount: trainings.length,
      trainingEstimatedKcal: trainKcal,
      weightDeltaKg: wDelta,
      hasMealData: foods.isNotEmpty,
      hasTrainingData: trainings.isNotEmpty,
    );

    return PeriodSummary(
      kind: kind,
      rangeStart: range.start,
      rangeEnd: range.end,
      totalFoodCalories: totalCal,
      totalProtein: totalProt,
      avgDailyCalories: avgDailyCal,
      avgDailyProtein: avgDailyProt,
      daysWithMealLogs: mealDays.length,
      trainingLogCount: trainings.length,
      trainingActiveDays: trainDays.length,
      trainingEstimatedKcal: trainKcal,
      weightStartKg: wStart,
      weightEndKg: wEnd,
      weightDeltaKg: wDelta,
      evaluation: evaluation,
    );
  }

  static PeriodEvaluation _evaluate({
    required SummaryPeriodKind kind,
    required NutritionGoalMode mode,
    required int calorieGoal,
    required double proteinGoal,
    required double avgDailyCalories,
    required double avgDailyProtein,
    required int trainingActiveDays,
    required int trainingLogCount,
    required double trainingEstimatedKcal,
    required double? weightDeltaKg,
    required bool hasMealData,
    required bool hasTrainingData,
  }) {
    final weeks = kind.calendarDays / 7.0;
    final trainDaysPerWeek =
        weeks > 0 ? trainingActiveDays / weeks : 0.0;

    if (!hasMealData && !hasTrainingData && weightDeltaKg == null) {
      return const PeriodEvaluation(
        score: 0,
        grade: '—',
        headline: 'この期間の記録がありません',
        bullets: [
          '食事かトレーニングの記録があると、ここにサマリと評価が表示されます。',
        ],
      );
    }

    double calScore;
    if (!hasMealData || calorieGoal <= 0) {
      calScore = 50;
    } else {
      final ratio = avgDailyCalories / calorieGoal;
      calScore = _calorieScore(mode, ratio);
    }

    double protScore;
    if (!hasMealData || proteinGoal <= 0) {
      protScore = 50;
    } else {
      final r = avgDailyProtein / proteinGoal;
      protScore = (r * 100).clamp(0.0, 100.0);
      if (r >= 0.85) {
        protScore = 100;
      } else if (r >= 0.65) {
        protScore = 75;
      } else {
        protScore = (r / 0.65 * 75).clamp(0.0, 75.0);
      }
    }

    double trainScore;
    if (!hasTrainingData) {
      trainScore = 42;
    } else {
      // 週あたりのトレーニング日数（有酸素・筋トレまとめて）を重視
      if (trainDaysPerWeek >= 4) {
        trainScore = 100;
      } else if (trainDaysPerWeek >= 3) {
        trainScore = 88;
      } else if (trainDaysPerWeek >= 2) {
        trainScore = 72;
      } else if (trainDaysPerWeek >= 1) {
        trainScore = 55;
      } else {
        trainScore = 40;
      }
    }

    var score =
        (calScore * 0.42 + protScore * 0.28 + trainScore * 0.30).round();
    score = score.clamp(0, 100);

    final grade = _gradeLetter(score);
    final headline = _headline(score, mode);

    final bullets = <String>[];
    if (hasMealData && calorieGoal > 0) {
      final diffPct =
          ((avgDailyCalories - calorieGoal) / calorieGoal * 100).round();
      final cmp = diffPct == 0
          ? '目標とほぼ同水準'
          : diffPct > 0
              ? '目標より約 $diffPct% 多め'
              : '目標より約 ${-diffPct}% 少なめ';
      bullets.add('平均摂取は約 ${avgDailyCalories.round()} kcal/日（$cmp）。');
    } else if (!hasMealData) {
      bullets.add('この期間は食事記録がありません。');
    }

    if (hasMealData && proteinGoal > 0) {
      final pr = (avgDailyProtein / proteinGoal * 100).round();
      bullets.add('タンパク質は目標の約 $pr%（平均 ${avgDailyProtein.toStringAsFixed(0)} g/日）。');
    }

    if (hasTrainingData) {
      final kcalRounded = trainingEstimatedKcal.round();
      bullets.add(
        'トレーニングは $trainingLogCount 件、週あたりおおよそ ${trainDaysPerWeek.toStringAsFixed(1)} 日運動の記録があります（推定消費 $kcalRounded kcal）。',
      );
    } else {
      bullets.add('この期間はトレーニング記録がありません。');
    }

    if (weightDeltaKg != null) {
      final sign = weightDeltaKg >= 0 ? '+' : '';
      bullets.add(
        '体重記録の変化: $sign${weightDeltaKg.toStringAsFixed(1)} kg（期間内の最初と最後の記録）。',
      );
    }

    bullets.add(_modeComment(mode, avgDailyCalories, calorieGoal, hasMealData));

    return PeriodEvaluation(
      score: score,
      grade: grade,
      headline: headline,
      bullets: bullets,
    );
  }

  /// [trainingEstimatedKcal] はバレル外で参照するため、上のメソッド内で文字列化済み。
  static String _modeComment(
    NutritionGoalMode mode,
    double avgDailyCalories,
    int calorieGoal,
    bool hasMealData,
  ) {
    if (!hasMealData || calorieGoal <= 0) {
      return '目標体重と食事を揃えると、より意図に沿った評価ができます。';
    }
    switch (mode) {
      case NutritionGoalMode.cut:
        return '目標は減量寄りです。無理な不足より、継続できるペースを優先しましょう。';
      case NutritionGoalMode.bulk:
        return '目標は増量寄りです。摂取とトレのバランスを意識して筋肉の増加に繋げましょう。';
      case NutritionGoalMode.maintain:
        return '目標は維持寄りです。体重よりも習慣の安定を評価の軸にすると良いでしょう。';
      case NutritionGoalMode.unknown:
        return 'プロフィールで現体重と目標体重を設定すると、評価の基準がはっきりします。';
    }
  }

  static double _calorieScore(NutritionGoalMode mode, double ratio) {
    double ideal;
    switch (mode) {
      case NutritionGoalMode.cut:
        ideal = 0.88;
        break;
      case NutritionGoalMode.bulk:
        ideal = 1.06;
        break;
      case NutritionGoalMode.maintain:
      case NutritionGoalMode.unknown:
        ideal = 1.0;
        break;
    }
    final dist = (ratio - ideal).abs();
    var s = 100.0 - dist * 220;
    if (mode == NutritionGoalMode.cut && ratio > 1.12) s -= 15;
    if (mode == NutritionGoalMode.bulk && ratio < 0.92) s -= 12;
    return s.clamp(0.0, 100.0);
  }

  static String _gradeLetter(int score) {
    if (score >= 90) return 'S';
    if (score >= 78) return 'A';
    if (score >= 65) return 'B';
    if (score >= 50) return 'C';
    return 'D';
  }

  static String _headline(int score, NutritionGoalMode mode) {
    if (score >= 85) {
      return '全体的にバランス良く続いています';
    }
    if (score >= 70) {
      return '良いペースです。あと一歩で安定';
    }
    if (score >= 55) {
      return '伸びしろがあります';
    }
    if (mode == NutritionGoalMode.unknown) {
      return '記録を積み重ねて傾向を確認しましょう';
    }
    return '習慣の見直しポイントを確認';
  }
}
