import 'package:riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/energy_profile.dart';

class EnergyProfileState {
  /// 未設定時は null（UIでは空欄表示）
  final BiologicalSex? sex;
  final int age;
  final double heightCm;
  final double weightKg;
  final double targetWeightKg;
  final int goalWeeks;
  final ActivityLevel activityLevel;

  const EnergyProfileState({
    this.sex,
    this.age = 0,
    this.heightCm = 0,
    this.weightKg = 0,
    this.targetWeightKg = 0,
    this.goalWeeks = 12,
    this.activityLevel = ActivityLevel.moderate,
  });

  EnergyProfile? toProfileIfComplete() {
    if (sex == null) return null;
    if (age <= 0 || heightCm <= 0 || weightKg <= 0) return null;
    if (goalWeeks <= 0) return null;
    if (targetWeightKg <= 0) return null;
    return EnergyProfile(
      sex: sex!,
      age: age,
      heightCm: heightCm,
      weightKg: weightKg,
      targetWeightKg: targetWeightKg,
      goalWeeks: goalWeeks,
      activityLevel: activityLevel,
    );
  }
}

class EnergyProfileNotifier extends StateNotifier<EnergyProfileState> {
  EnergyProfileNotifier() : super(const EnergyProfileState()) {
    _load();
  }

  static const _kSex = 'energyProfileSex';
  static const _kAge = 'energyProfileAge';
  static const _kHeight = 'energyProfileHeightCm';
  static const _kWeight = 'energyProfileWeightKg';
  static const _kTarget = 'energyProfileTargetKg';
  static const _kWeeks = 'energyProfileGoalWeeks';
  static const _kActivity = 'energyProfileActivity';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = EnergyProfileState(
      sex: BiologicalSex.tryParse(prefs.getString(_kSex)),
      age: prefs.getInt(_kAge) ?? 0,
      heightCm: prefs.getDouble(_kHeight) ?? 0,
      weightKg: prefs.getDouble(_kWeight) ?? 0,
      targetWeightKg: prefs.getDouble(_kTarget) ?? 0,
      goalWeeks: prefs.getInt(_kWeeks) ?? 12,
      activityLevel: ActivityLevel.fromStorage(prefs.getString(_kActivity)),
    );
  }

  Future<void> save(EnergyProfileState data) async {
    final prefs = await SharedPreferences.getInstance();
    if (data.sex != null) {
      await prefs.setString(_kSex, data.sex!.name);
    } else {
      await prefs.remove(_kSex);
    }
    await prefs.setInt(_kAge, data.age);
    await prefs.setDouble(_kHeight, data.heightCm);
    await prefs.setDouble(_kWeight, data.weightKg);
    await prefs.setDouble(_kTarget, data.targetWeightKg);
    await prefs.setInt(_kWeeks, data.goalWeeks);
    await prefs.setString(_kActivity, data.activityLevel.name);
    state = data;
  }
}

final energyProfileProvider =
    StateNotifierProvider<EnergyProfileNotifier, EnergyProfileState>(
  (ref) => EnergyProfileNotifier(),
);
