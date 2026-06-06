import 'package:flutter/material.dart';

import '../models/training_log.dart';
import 'bewell_colors.dart';

/// 種目タイプ別のセマンティックカラー。
abstract final class ExerciseColors {
  static Color forType(
    ExerciseType type,
    ColorScheme scheme,
    BeWellColors semantic,
  ) {
    return switch (type) {
      ExerciseType.freeWeight => semantic.streak,
      ExerciseType.machine => scheme.primary,
      ExerciseType.bodyweight => semantic.success,
      ExerciseType.cardio => scheme.secondary,
    };
  }
}
