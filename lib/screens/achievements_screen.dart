import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/badge_definitions.dart';
import '../providers/achievement_provider.dart';

class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(achievementProvider);
    final scheme = Theme.of(context).colorScheme;

    return DefaultTabController(
      length: BadgeCategory.values.length + 1,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('バッジ・実績'),
          bottom: TabBar(
            isScrollable: true,
            tabs: [
              const Tab(text: 'すべて'),
              for (final cat in BadgeCategory.values)
                Tab(text: _categoryLabel(cat)),
            ],
          ),
        ),
        body: Column(
          children: [
            _buildStreakRow(context, state, scheme),
            Expanded(
              child: state.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      children: [
                        _BadgeGrid(
                            achievements: state.achievements,
                            filter: null),
                        for (final cat in BadgeCategory.values)
                          _BadgeGrid(
                              achievements: state.achievements,
                              filter: cat),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStreakRow(
      BuildContext context, AchievementState state, ColorScheme scheme) {
    final streaks = state.streaks;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: scheme.surfaceContainerHighest,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _streakChip(
              context, '🍽 食事', streaks.nutritionStreak, scheme),
          _streakChip(
              context, '💪 トレーニング', streaks.trainingStreak, scheme),
          _streakChip(
              context, '🚶 歩数', streaks.overallStreak, scheme),
        ],
      ),
    );
  }

  Widget _streakChip(
      BuildContext context, String label, int streak, ColorScheme scheme) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (streak > 0)
              Text('🔥',
                  style: const TextStyle(fontSize: 16)),
            Text(
              ' $streak日',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: streak > 0 ? Colors.deepOrange : null,
                  ),
            ),
          ],
        ),
        Text(label,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant)),
      ],
    );
  }

  String _categoryLabel(BadgeCategory cat) {
    switch (cat) {
      case BadgeCategory.nutrition:
        return '🍽 栄養';
      case BadgeCategory.training:
        return '💪 トレーニング';
      case BadgeCategory.steps:
        return '🚶 歩数';
      case BadgeCategory.body:
        return '⚖️ 身体';
      case BadgeCategory.streak:
        return '🔥 継続';
    }
  }
}

class _BadgeGrid extends StatelessWidget {
  const _BadgeGrid({required this.achievements, this.filter});
  final List achievements;
  final BadgeCategory? filter;

  @override
  Widget build(BuildContext context) {
    final filteredDefs = allBadges
        .where((d) => filter == null || d.category == filter)
        .toList();

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.1,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: filteredDefs.length,
      itemBuilder: (_, i) {
        final def = filteredDefs[i];
        final ach = achievements.firstWhere(
          (a) => a.badgeKey == def.key,
          orElse: () => null,
        );
        final isUnlocked = ach?.isUnlocked ?? false;
        final unlockedAt = ach?.unlockedAt as DateTime?;

        return _BadgeCard(
          def: def,
          isUnlocked: isUnlocked,
          unlockedAt: unlockedAt,
          progress: ach?.progress ?? 0,
        );
      },
    );
  }
}

class _BadgeCard extends StatelessWidget {
  const _BadgeCard({
    required this.def,
    required this.isUnlocked,
    this.unlockedAt,
    this.progress = 0,
  });

  final BadgeDefinition def;
  final bool isUnlocked;
  final DateTime? unlockedAt;
  final int progress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = badgeCategoryColor(def.category);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: ColorFiltered(
          colorFilter: isUnlocked
              ? const ColorFilter.mode(Colors.transparent, BlendMode.saturation)
              : ColorFilter.mode(
                  Colors.grey.shade400,
                  BlendMode.saturation,
                ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isUnlocked
                      ? color.withValues(alpha: 0.2)
                      : scheme.surfaceContainerHighest,
                ),
                child: Icon(
                  isUnlocked ? def.icon : Icons.lock_outline_rounded,
                  size: 28,
                  color: isUnlocked ? color : scheme.outlineVariant,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                def.title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isUnlocked ? null : scheme.outlineVariant,
                    ),
              ),
              if (isUnlocked && unlockedAt != null) ...[
                const SizedBox(height: 2),
                Text(
                  DateFormat('M/d達成').format(unlockedAt!),
                  style: TextStyle(fontSize: 10, color: color),
                ),
              ] else if (!isUnlocked && def.requiredCount > 1) ...[
                const SizedBox(height: 4),
                Text(
                  '$progress / ${def.requiredCount}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.outlineVariant,
                        fontSize: 10,
                      ),
                ),
                const SizedBox(height: 2),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: def.requiredCount > 0
                        ? (progress / def.requiredCount).clamp(0.0, 1.0)
                        : 0,
                    minHeight: 4,
                    backgroundColor: scheme.surfaceContainerHighest,
                    color: color.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
