/// カロリー目標算出用の身体情報・活動量・体重計画
class EnergyProfile {
  final BiologicalSex sex;
  final int age;
  final double heightCm;
  final double weightKg;
  final double targetWeightKg;
  final int goalWeeks;
  final ActivityLevel activityLevel;

  const EnergyProfile({
    required this.sex,
    required this.age,
    required this.heightCm,
    required this.weightKg,
    required this.targetWeightKg,
    required this.goalWeeks,
    required this.activityLevel,
  });
}

enum BiologicalSex {
  male,
  female;

  String get label => switch (this) {
        BiologicalSex.male => '男性',
        BiologicalSex.female => '女性',
      };

  static BiologicalSex? tryParse(String? s) {
    switch (s) {
      case 'male':
        return BiologicalSex.male;
      case 'female':
        return BiologicalSex.female;
      default:
        return null;
    }
  }
}

/// 1日の総消費カロリー（TDEE）に掛ける活動係数
enum ActivityLevel {
  sedentary,
  light,
  moderate,
  active,
  veryActive;

  double get factor => switch (this) {
        ActivityLevel.sedentary => 1.2,
        ActivityLevel.light => 1.375,
        ActivityLevel.moderate => 1.55,
        ActivityLevel.active => 1.725,
        ActivityLevel.veryActive => 1.9,
      };

  String get label => switch (this) {
        ActivityLevel.sedentary => '低い（座り仕事中心）',
        ActivityLevel.light => 'やや低い（軽い歩行・週1〜2回運動）',
        ActivityLevel.moderate => '普通（週3〜5回程度の運動）',
        ActivityLevel.active => '高い（ほぼ毎日運動・肉体労働気味）',
        ActivityLevel.veryActive => '非常に高い（アスリート級）',
      };

  static ActivityLevel fromStorage(String? s) {
    return ActivityLevel.values.firstWhere(
      (e) => e.name == s,
      orElse: () => ActivityLevel.moderate,
    );
  }
}
