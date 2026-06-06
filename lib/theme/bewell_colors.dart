import 'package:flutter/material.dart';

import 'app_tokens.dart';

/// セマンティックカラー — ハードコード [Colors.*] の代替。
@immutable
class BeWellColors extends ThemeExtension<BeWellColors> {
  const BeWellColors({
    required this.water,
    required this.waterContainer,
    required this.success,
    required this.streak,
    required this.warning,
    required this.aiAccent,
    required this.heroGradientStart,
    required this.heroGradientEnd,
  });

  final Color water;
  final Color waterContainer;
  final Color success;
  final Color streak;
  final Color warning;
  final Color aiAccent;
  final Color heroGradientStart;
  final Color heroGradientEnd;

  static BeWellColors light(ColorScheme scheme) => BeWellColors(
        water: const Color(0xFF0284C7),
        waterContainer: const Color(0xFF0284C7).withValues(alpha: 0.12),
        success: const Color(0xFF059669),
        streak: const Color(0xFFEA580C),
        warning: const Color(0xFFD97706),
        aiAccent: BeWellBrand.aiAccent,
        heroGradientStart: scheme.primaryContainer.withValues(alpha: 0.9),
        heroGradientEnd: scheme.tertiaryContainer.withValues(alpha: 0.55),
      );

  static BeWellColors dark(ColorScheme scheme) => BeWellColors(
        water: const Color(0xFF38BDF8),
        waterContainer: const Color(0xFF38BDF8).withValues(alpha: 0.15),
        success: const Color(0xFF34D399),
        streak: const Color(0xFFFB923C),
        warning: const Color(0xFFFBBF24),
        aiAccent: const Color(0xFF818CF8),
        heroGradientStart: scheme.primaryContainer.withValues(alpha: 0.75),
        heroGradientEnd: scheme.tertiaryContainer.withValues(alpha: 0.45),
      );

  @override
  BeWellColors copyWith({
    Color? water,
    Color? waterContainer,
    Color? success,
    Color? streak,
    Color? warning,
    Color? aiAccent,
    Color? heroGradientStart,
    Color? heroGradientEnd,
  }) {
    return BeWellColors(
      water: water ?? this.water,
      waterContainer: waterContainer ?? this.waterContainer,
      success: success ?? this.success,
      streak: streak ?? this.streak,
      warning: warning ?? this.warning,
      aiAccent: aiAccent ?? this.aiAccent,
      heroGradientStart: heroGradientStart ?? this.heroGradientStart,
      heroGradientEnd: heroGradientEnd ?? this.heroGradientEnd,
    );
  }

  @override
  BeWellColors lerp(ThemeExtension<BeWellColors>? other, double t) {
    if (other is! BeWellColors) return this;
    return BeWellColors(
      water: Color.lerp(water, other.water, t)!,
      waterContainer: Color.lerp(waterContainer, other.waterContainer, t)!,
      success: Color.lerp(success, other.success, t)!,
      streak: Color.lerp(streak, other.streak, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      aiAccent: Color.lerp(aiAccent, other.aiAccent, t)!,
      heroGradientStart:
          Color.lerp(heroGradientStart, other.heroGradientStart, t)!,
      heroGradientEnd: Color.lerp(heroGradientEnd, other.heroGradientEnd, t)!,
    );
  }
}

extension BeWellColorsX on BuildContext {
  BeWellColors get bewellColors =>
      Theme.of(this).extension<BeWellColors>()!;
}
