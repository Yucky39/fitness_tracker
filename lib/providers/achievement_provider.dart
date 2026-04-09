import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/badge_definitions.dart';
import '../models/achievement.dart';
import '../services/database_service.dart';

class StreakData {
  final int nutritionStreak;
  final int trainingStreak;
  final int overallStreak;
  final String nutritionLastDate;
  final String trainingLastDate;
  final String overallLastDate;

  const StreakData({
    this.nutritionStreak = 0,
    this.trainingStreak = 0,
    this.overallStreak = 0,
    this.nutritionLastDate = '',
    this.trainingLastDate = '',
    this.overallLastDate = '',
  });

  StreakData copyWith({
    int? nutritionStreak,
    int? trainingStreak,
    int? overallStreak,
    String? nutritionLastDate,
    String? trainingLastDate,
    String? overallLastDate,
  }) =>
      StreakData(
        nutritionStreak: nutritionStreak ?? this.nutritionStreak,
        trainingStreak: trainingStreak ?? this.trainingStreak,
        overallStreak: overallStreak ?? this.overallStreak,
        nutritionLastDate: nutritionLastDate ?? this.nutritionLastDate,
        trainingLastDate: trainingLastDate ?? this.trainingLastDate,
        overallLastDate: overallLastDate ?? this.overallLastDate,
      );

  Map<String, dynamic> toJson() => {
        'nutritionStreak': nutritionStreak,
        'trainingStreak': trainingStreak,
        'overallStreak': overallStreak,
        'nutritionLastDate': nutritionLastDate,
        'trainingLastDate': trainingLastDate,
        'overallLastDate': overallLastDate,
      };

  factory StreakData.fromJson(Map<String, dynamic> j) => StreakData(
        nutritionStreak: j['nutritionStreak'] as int? ?? 0,
        trainingStreak: j['trainingStreak'] as int? ?? 0,
        overallStreak: j['overallStreak'] as int? ?? 0,
        nutritionLastDate: j['nutritionLastDate'] as String? ?? '',
        trainingLastDate: j['trainingLastDate'] as String? ?? '',
        overallLastDate: j['overallLastDate'] as String? ?? '',
      );
}

class AchievementState {
  final List<Achievement> achievements;
  final StreakData streaks;
  final List<String> newlyUnlocked;
  final bool isLoading;

  const AchievementState({
    this.achievements = const [],
    this.streaks = const StreakData(),
    this.newlyUnlocked = const [],
    this.isLoading = true,
  });

  AchievementState copyWith({
    List<Achievement>? achievements,
    StreakData? streaks,
    List<String>? newlyUnlocked,
    bool? isLoading,
  }) =>
      AchievementState(
        achievements: achievements ?? this.achievements,
        streaks: streaks ?? this.streaks,
        newlyUnlocked: newlyUnlocked ?? this.newlyUnlocked,
        isLoading: isLoading ?? this.isLoading,
      );
}

class AchievementNotifier extends StateNotifier<AchievementState> {
  AchievementNotifier() : super(const AchievementState()) {
    _load();
  }

  static const _kStreaks = 'streakData';

  Future<void> _load() async {
    try {
      final adapter = await DatabaseService().database;
      final maps = await adapter.query('achievements');
      final achievements = maps.map(Achievement.fromMap).toList();

      final prefs = await SharedPreferences.getInstance();
      final streakJson = prefs.getString(_kStreaks);
      final streaks = streakJson != null
          ? StreakData.fromJson(
              jsonDecode(streakJson) as Map<String, dynamic>)
          : const StreakData();

      // 未登録バッジを progress=0 で補完
      final existingKeys = achievements.map((a) => a.badgeKey).toSet();
      for (final def in allBadges) {
        if (!existingKeys.contains(def.key)) {
          achievements.add(Achievement(badgeKey: def.key));
        }
      }

      state = state.copyWith(
        achievements: achievements,
        streaks: streaks,
        isLoading: false,
      );
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> _saveStreaks(StreakData streaks) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kStreaks, jsonEncode(streaks.toJson()));
  }

  /// 食事記録時に呼ぶ
  Future<void> onNutritionLogged(int totalFoodItems) async {
    final today = _todayKey();
    var streaks = state.streaks;

    if (streaks.nutritionLastDate != today) {
      final streak = _isConsecutive(streaks.nutritionLastDate, today)
          ? streaks.nutritionStreak + 1
          : 1;
      streaks = streaks.copyWith(
        nutritionStreak: streak,
        nutritionLastDate: today,
      );
      await _saveStreaks(streaks);
    }

    await _evaluateAndUnlock({
      'nutrition_first_log': totalFoodItems >= 1 ? 1 : 0,
      'nutrition_7day_streak': streaks.nutritionStreak,
      'nutrition_30day_streak': streaks.nutritionStreak,
    }, streaks);
  }

  /// トレーニング記録時に呼ぶ
  Future<void> onTrainingLogged(int totalTrainingLogs) async {
    final today = _todayKey();
    var streaks = state.streaks;

    if (streaks.trainingLastDate != today) {
      final streak = _isConsecutive(streaks.trainingLastDate, today)
          ? streaks.trainingStreak + 1
          : 1;
      streaks = streaks.copyWith(
        trainingStreak: streak,
        trainingLastDate: today,
      );
      await _saveStreaks(streaks);
    }

    // 今週のトレーニング日数
    final weekStart =
        DateTime.now().subtract(Duration(days: DateTime.now().weekday - 1));

    await _evaluateAndUnlock({
      'training_first_log': totalTrainingLogs >= 1 ? 1 : 0,
      'training_10_sessions': totalTrainingLogs,
      'training_50_sessions': totalTrainingLogs,
      'training_3days_week': streaks.trainingStreak, // 簡略化
    }, streaks, weekStart: weekStart);
  }

  /// 体重記録時に呼ぶ
  Future<void> onBodyMetricsLogged(int totalMetrics) async {
    await _evaluateAndUnlock({
      'body_first_metrics': totalMetrics >= 1 ? 1 : 0,
      'body_10_metrics': totalMetrics,
    }, state.streaks);
  }

  /// 歩数更新時に呼ぶ
  Future<void> onStepsUpdated(int steps) async {
    final today = _todayKey();
    var streaks = state.streaks;

    if (steps >= 5000 && streaks.overallLastDate != today) {
      final streak = _isConsecutive(streaks.overallLastDate, today)
          ? streaks.overallStreak + 1
          : 1;
      streaks = streaks.copyWith(
        overallStreak: streak,
        overallLastDate: today,
      );
      await _saveStreaks(streaks);
    }

    await _evaluateAndUnlock({
      'steps_10k_day': steps >= 10000 ? 1 : 0,
      'steps_7day_streak': streaks.overallStreak,
      'streak_7day_overall': streaks.overallStreak,
      'streak_30day_overall': streaks.overallStreak,
    }, streaks);
  }

  Future<void> _evaluateAndUnlock(
    Map<String, int> progressValues,
    StreakData streaks, {
    DateTime? weekStart,
  }) async {
    final adapter = await DatabaseService().database;
    final newlyUnlocked = <String>[];

    final updatedAchievements = [...state.achievements];

    for (var i = 0; i < updatedAchievements.length; i++) {
      final ach = updatedAchievements[i];
      if (ach.isUnlocked) continue;

      final def = allBadges.firstWhere(
        (b) => b.key == ach.badgeKey,
        orElse: () => allBadges.first,
      );
      if (def.key != ach.badgeKey) continue;

      final progress = progressValues[ach.badgeKey] ?? 0;

      if (progress >= def.requiredCount) {
        final unlocked = ach.copyWith(
          unlockedAt: DateTime.now(),
          progress: progress,
        );
        updatedAchievements[i] = unlocked;
        newlyUnlocked.add(def.key);

        // DB に保存
        final existing = await adapter.query(
          'achievements',
          where: 'badge_key = ?',
          whereArgs: [ach.badgeKey],
          limit: 1,
        );
        if (existing.isEmpty) {
          await adapter.insert('achievements', unlocked.toMap());
        } else {
          await adapter.update(
            'achievements',
            {'unlocked_at': unlocked.unlockedAt!.toIso8601String(), 'progress': progress},
            where: 'badge_key = ?',
            whereArgs: [ach.badgeKey],
          );
        }
      } else if (progress > ach.progress) {
        // 進捗を更新
        updatedAchievements[i] = ach.copyWith(progress: progress);
        final existing = await adapter.query(
          'achievements',
          where: 'badge_key = ?',
          whereArgs: [ach.badgeKey],
          limit: 1,
        );
        if (existing.isEmpty) {
          await adapter.insert(
            'achievements',
            Achievement(badgeKey: ach.badgeKey, progress: progress).toMap(),
          );
        } else {
          await adapter.update(
            'achievements',
            {'progress': progress},
            where: 'badge_key = ?',
            whereArgs: [ach.badgeKey],
          );
        }
      }
    }

    state = state.copyWith(
      achievements: updatedAchievements,
      streaks: streaks,
      newlyUnlocked: newlyUnlocked,
    );
  }

  void clearNewlyUnlocked() {
    state = state.copyWith(newlyUnlocked: []);
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  bool _isConsecutive(String lastDate, String today) {
    if (lastDate.isEmpty) return false;
    try {
      final last = DateTime.parse(lastDate);
      final t = DateTime.parse(today);
      return t.difference(last).inDays == 1;
    } catch (_) {
      return false;
    }
  }
}

final achievementProvider =
    StateNotifierProvider<AchievementNotifier, AchievementState>(
  (_) => AchievementNotifier(),
);

/// バッジのカラー（カテゴリ別）
Color badgeCategoryColor(BadgeCategory category) {
  switch (category) {
    case BadgeCategory.nutrition:
      return Colors.green;
    case BadgeCategory.training:
      return Colors.blue;
    case BadgeCategory.steps:
      return Colors.orange;
    case BadgeCategory.body:
      return Colors.purple;
    case BadgeCategory.streak:
      return Colors.red;
  }
}
