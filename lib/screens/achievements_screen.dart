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
        backgroundColor: scheme.surface,
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
                            achievements: state.achievements, filter: null),
                        for (final cat in BadgeCategory.values)
                          _BadgeGrid(
                              achievements: state.achievements, filter: cat),
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
          _streakChip(context, '🍽 食事', streaks.nutritionStreak, scheme),
          _streakChip(context, '💪 トレーニング', streaks.trainingStreak, scheme),
          _streakChip(context, '🚶 歩数', streaks.overallStreak, scheme),
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
            if (streak > 0) Text('🔥', style: const TextStyle(fontSize: 16)),
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
    final filteredDefs =
        allBadges.where((d) => filter == null || d.category == filter).toList();

    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: GridView.builder(
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
      ),
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

    // 円の背景を未取得だけグレーにするとカードと同化し絵文字が消えたように見える。
    // 未取得もカテゴリ色を弱く載せ、全体の Opacity で「まだ」の印象を付ける。
    final circleBg = isUnlocked
        ? color.withValues(alpha: 0.18)
        : color.withValues(alpha: 0.1);
    final circleBorder = isUnlocked
        ? color.withValues(alpha: 0.5)
        : color.withValues(alpha: 0.28);

    return Stack(
      children: [
        Card(
          // surface と surfaceContainerLow の差が小さいテーマでは同化しやすい。
          // 未取得は surfaceContainerHigh、取得済みはカテゴリ色をはっきり載せる。
          color: isUnlocked
              ? Color.alphaBlend(
                  color.withValues(alpha: 0.22),
                  scheme.surfaceContainerHigh,
                )
              : scheme.surfaceContainerHigh,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: isUnlocked
                  ? color.withValues(alpha: 0.55)
                  : scheme.outline.withValues(alpha: 0.35),
              width: isUnlocked ? 1.5 : 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 絵文字を主役に、背景円はカテゴリカラー（未取得はより薄い同系色）
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: circleBg,
                    border: Border.all(color: circleBorder, width: 1.5),
                  ),
                  alignment: Alignment.center,
                  // 未取得時は TextStyle.color で絵文字を薄くしない（単色化・欠落の原因になりやすい）。
                  // Opacity と絵文字用 fontFamilyFallback で薄く表示する。
                  child: Opacity(
                    opacity: isUnlocked ? 1.0 : 0.45,
                    child: Text(
                      def.emoji,
                      style: const TextStyle(
                        fontSize: 28,
                        fontFamilyFallback: [
                          'Apple Color Emoji',
                          'Noto Color Emoji',
                          'Segoe UI Emoji',
                        ],
                      ),
                    ),
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
                        color: isUnlocked
                            ? null
                            : scheme.onSurface.withValues(alpha: 0.55),
                      ),
                ),
                if (isUnlocked && unlockedAt != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    DateFormat('M/d達成').format(unlockedAt!),
                    style: TextStyle(
                        fontSize: 10,
                        color: color,
                        fontWeight: FontWeight.w600),
                  ),
                ] else if (!isUnlocked && def.requiredCount > 1) ...[
                  const SizedBox(height: 4),
                  Text(
                    '$progress / ${def.requiredCount}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: 10,
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 3),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: def.requiredCount > 0
                          ? (progress / def.requiredCount).clamp(0.0, 1.0)
                          : 0,
                      minHeight: 4,
                      backgroundColor: scheme.surfaceContainerHighest,
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        // 未取得バッジに小さいロックアイコンを右上に表示
        if (!isUnlocked)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.surfaceContainerHighest,
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.6),
                ),
              ),
              child: Icon(
                Icons.lock_rounded,
                size: 12,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}
