import '../models/energy_profile.dart';

/// Mifflin–St Jeor 式の基礎代謝量と、目標体重・達成期間から1日の推奨エネルギー・PFCを算出する。
class EnergyGoalCalculator {
  EnergyGoalCalculator._();

  /// 体脂肪相当1kgあたりのエネルギー換算（kcal）の一般的な近似値
  static const double kcalPerKgBodyChange = 7700;

  static const double maxDailyDeficit = 1000;
  static const double maxDailySurplus = 600;

  static int minSafeCalories(BiologicalSex sex) =>
      sex == BiologicalSex.female ? 1200 : 1500;

  /// 基礎代謝量 (kcal/日)
  static double bmr(EnergyProfile p) {
    final base = 10 * p.weightKg + 6.25 * p.heightCm - 5 * p.age;
    return p.sex == BiologicalSex.male ? base + 5 : base - 161;
  }

  /// 推定TDEE (kcal/日)
  static double tdee(EnergyProfile p) => bmr(p) * p.activityLevel.factor;

  /// 体重変化に必要な1日あたりのエネルギー差分（プラス＝余剰＝増量側）
  static double dailyEnergyBalanceForGoal(EnergyProfile p) {
    final deltaKg = p.targetWeightKg - p.weightKg;
    if (deltaKg.abs() < 0.05) return 0;
    final days = (p.goalWeeks * 7).clamp(1, 3650);
    return deltaKg * kcalPerKgBodyChange / days;
  }

  static ComputedNutritionGoals compute(EnergyProfile p) {
    final tdeeVal = tdee(p);
    final balance = dailyEnergyBalanceForGoal(p);
    var targetCal = (tdeeVal + balance).round();

    final notes = <String>[];

    if (balance < 0) {
      final deficit = -balance;
      if (deficit > maxDailyDeficit) {
        notes.add(
          '減量ペースが速すぎるため、1日の減量分を${maxDailyDeficit.toInt()}kcalに抑えました（無理な制限は避けてください）',
        );
        targetCal = (tdeeVal - maxDailyDeficit).round();
      }
    } else if (balance > 0) {
      if (balance > maxDailySurplus) {
        notes.add(
          '増量ペースを1日あたり+${maxDailySurplus.toInt()}kcalに抑えました（急激な増量は脂肪増につながりやすいです）',
        );
        targetCal = (tdeeVal + maxDailySurplus).round();
      }
    }

    final minCal = minSafeCalories(p.sex);
    if (targetCal < minCal) {
      notes.add(
        '安全下限（${minCal}kcal/日）まで引き上げました。さらに減量したい場合は期間を延ばすか、医師・管理栄養士に相談してください',
      );
      targetCal = minCal;
    }

    if (targetCal > 6000) {
      notes.add('上限6000kcalに丸めました（極端に高い場合は手動で調整してください）');
      targetCal = 6000;
    }

    final macros = _macroSplit(targetCal.toDouble(), p.weightKg);

    return ComputedNutritionGoals(
      bmr: bmr(p),
      tdee: tdeeVal,
      dailyEnergyBalance: balance,
      calories: targetCal,
      proteinG: macros.$1,
      fatG: macros.$2,
      carbsG: macros.$3,
      notes: notes,
    );
  }

  /// タンパク質は体重ベースとカロリー比率の高い方、脂質25%目安、残り炭水化物（カロリー整合を優先）
  static (double, double, double) _macroSplit(double calories, double weightKg) {
    final fromRatio = 0.30 * calories / 4;
    final fromWeight = 1.8 * weightKg;
    var protein = (fromRatio > fromWeight ? fromRatio : fromWeight).clamp(40.0, 250.0);
    var fat = (0.25 * calories / 9).clamp(25.0, 200.0);
    var carbCal = calories - protein * 4 - fat * 9;
    if (carbCal < 40) {
      fat = ((calories - protein * 4) * 0.35 / 9).clamp(20.0, 200.0);
      carbCal = calories - protein * 4 - fat * 9;
    }
    if (carbCal < 40) {
      protein = ((calories - fat * 9) * 0.30 / 4).clamp(40.0, 250.0);
      carbCal = calories - protein * 4 - fat * 9;
    }
    final carbs = (carbCal / 4).clamp(0.0, 600.0);
    return (
      double.parse(protein.toStringAsFixed(1)),
      double.parse(fat.toStringAsFixed(1)),
      double.parse(carbs.toStringAsFixed(1)),
    );
  }
}

class ComputedNutritionGoals {
  final double bmr;
  final double tdee;
  /// 目標達成のための理論上の1日の収支（プラス＝摂取をTDEEより多く）
  final double dailyEnergyBalance;
  final int calories;
  final double proteinG;
  final double fatG;
  final double carbsG;
  final List<String> notes;

  const ComputedNutritionGoals({
    required this.bmr,
    required this.tdee,
    required this.dailyEnergyBalance,
    required this.calories,
    required this.proteinG,
    required this.fatG,
    required this.carbsG,
    required this.notes,
  });

  /// 安全上限などを適用したあとの「目標摂取 − TDEE」（kcal/日）
  int get appliedDailyDelta => calories - tdee.round();
}
