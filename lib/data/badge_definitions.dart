import 'package:flutter/material.dart';

enum BadgeCategory { nutrition, training, steps, body, streak }

class BadgeDefinition {
  final String key;
  final String title;
  final String description;
  final String emoji; // バッジの主役ビジュアル
  final IconData icon;
  final BadgeCategory category;
  final int requiredCount; // 達成に必要な回数

  const BadgeDefinition({
    required this.key,
    required this.title,
    required this.description,
    required this.emoji,
    required this.icon,
    required this.category,
    this.requiredCount = 1,
  });
}

const List<BadgeDefinition> allBadges = [
  // ─── 栄養 ──────────────────────────────────────────────────────────────────
  BadgeDefinition(
    key: 'nutrition_first_log',
    title: '最初の一歩',
    description: '初めて食事を記録した',
    emoji: '🍽️',
    icon: Icons.restaurant_rounded,
    category: BadgeCategory.nutrition,
  ),
  BadgeDefinition(
    key: 'nutrition_7day_streak',
    title: '食事管理の習慣',
    description: '7日連続で食事を記録した',
    emoji: '🔥',
    icon: Icons.local_fire_department_rounded,
    category: BadgeCategory.nutrition,
    requiredCount: 7,
  ),
  BadgeDefinition(
    key: 'nutrition_30day_streak',
    title: '食事管理マスター',
    description: '30日連続で食事を記録した',
    emoji: '🏆',
    icon: Icons.emoji_events_rounded,
    category: BadgeCategory.nutrition,
    requiredCount: 30,
  ),
  BadgeDefinition(
    key: 'nutrition_calorie_goal_10',
    title: 'カロリーコントロール',
    description: 'カロリー目標を10回達成した',
    emoji: '🎯',
    icon: Icons.track_changes_rounded,
    category: BadgeCategory.nutrition,
    requiredCount: 10,
  ),
  BadgeDefinition(
    key: 'nutrition_protein_goal_7',
    title: 'プロテインマスター',
    description: 'タンパク質目標を7日達成した',
    emoji: '💪',
    icon: Icons.fitness_center_rounded,
    category: BadgeCategory.nutrition,
    requiredCount: 7,
  ),

  // ─── トレーニング ───────────────────────────────────────────────────────────
  BadgeDefinition(
    key: 'training_first_log',
    title: 'ジム入会',
    description: '初めてトレーニングを記録した',
    emoji: '🏋️',
    icon: Icons.sports_gymnastics_rounded,
    category: BadgeCategory.training,
  ),
  BadgeDefinition(
    key: 'training_10_sessions',
    title: '10セッション達成',
    description: 'トレーニングを10回記録した',
    emoji: '⭐',
    icon: Icons.star_rounded,
    category: BadgeCategory.training,
    requiredCount: 10,
  ),
  BadgeDefinition(
    key: 'training_50_sessions',
    title: '継続は力なり',
    description: 'トレーニングを50回記録した',
    emoji: '🥇',
    icon: Icons.military_tech_rounded,
    category: BadgeCategory.training,
    requiredCount: 50,
  ),
  BadgeDefinition(
    key: 'training_3days_week',
    title: '週3トレーニー',
    description: '1週間に3回トレーニングを記録した',
    emoji: '📅',
    icon: Icons.calendar_view_week_rounded,
    category: BadgeCategory.training,
    requiredCount: 3,
  ),

  // ─── 歩数 ──────────────────────────────────────────────────────────────────
  BadgeDefinition(
    key: 'steps_10k_day',
    title: '1万歩達成',
    description: '1日1万歩以上歩いた',
    emoji: '👣',
    icon: Icons.directions_walk_rounded,
    category: BadgeCategory.steps,
  ),
  BadgeDefinition(
    key: 'steps_7day_streak',
    title: '毎日ウォーカー',
    description: '7日連続で5000歩以上歩いた',
    emoji: '🏃',
    icon: Icons.run_circle_rounded,
    category: BadgeCategory.steps,
    requiredCount: 7,
  ),

  // ─── 身体 ──────────────────────────────────────────────────────────────────
  BadgeDefinition(
    key: 'body_first_metrics',
    title: '記録開始',
    description: '初めて体重を記録した',
    emoji: '⚖️',
    icon: Icons.monitor_weight_rounded,
    category: BadgeCategory.body,
  ),
  BadgeDefinition(
    key: 'body_10_metrics',
    title: '体重管理継続',
    description: '体重を10回記録した',
    emoji: '📉',
    icon: Icons.trending_down_rounded,
    category: BadgeCategory.body,
    requiredCount: 10,
  ),

  // ─── 継続 ──────────────────────────────────────────────────────────────────
  BadgeDefinition(
    key: 'streak_7day_overall',
    title: '一週間の継続',
    description: '7日間アプリを継続して使用した',
    emoji: '🔥',
    icon: Icons.whatshot_rounded,
    category: BadgeCategory.streak,
    requiredCount: 7,
  ),
  BadgeDefinition(
    key: 'streak_30day_overall',
    title: '30日の継続',
    description: '30日間アプリを継続して使用した',
    emoji: '🎉',
    icon: Icons.celebration_rounded,
    category: BadgeCategory.streak,
    requiredCount: 30,
  ),
];
