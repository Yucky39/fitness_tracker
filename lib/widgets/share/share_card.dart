import 'package:flutter/material.dart';

/// ワークアウト完了 or バッジ解除のシェア用カード。
/// RepaintBoundary でラップして PNG キャプチャに使う。
class WorkoutShareCard extends StatelessWidget {
  const WorkoutShareCard({
    super.key,
    required this.totalSets,
    required this.exerciseNames,
    required this.durationMinutes,
  });

  final int totalSets;
  final List<String> exerciseNames;
  final int durationMinutes;

  @override
  Widget build(BuildContext context) {
    return _ShareCardBase(
      topLabel: 'ワークアウト完了！',
      emoji: '💪',
      title: '$totalSets セット達成',
      subtitle: exerciseNames.take(3).join(' · ') +
          (exerciseNames.length > 3 ? ' ほか' : ''),
      bottomLabel: '$durationMinutes 分',
      gradientColors: const [Color(0xFF1565C0), Color(0xFF0D47A1)],
    );
  }
}

class BadgeShareCard extends StatelessWidget {
  const BadgeShareCard({
    super.key,
    required this.emoji,
    required this.title,
    required this.description,
    required this.categoryColor,
  });

  final String emoji;
  final String title;
  final String description;
  final Color categoryColor;

  @override
  Widget build(BuildContext context) {
    return _ShareCardBase(
      topLabel: 'バッジを獲得！',
      emoji: emoji,
      title: title,
      subtitle: description,
      gradientColors: [
        categoryColor,
        Color.lerp(categoryColor, Colors.black, 0.3)!,
      ],
    );
  }
}

class _ShareCardBase extends StatelessWidget {
  const _ShareCardBase({
    required this.topLabel,
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.gradientColors,
    this.bottomLabel,
  });

  final String topLabel;
  final String emoji;
  final String title;
  final String subtitle;
  final List<Color> gradientColors;
  final String? bottomLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      height: 320,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ヘッダー
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'BeWell',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  topLabel,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const Spacer(),
            // 絵文字
            Text(
              emoji,
              style: const TextStyle(
                fontSize: 56,
                fontFamilyFallback: [
                  'Apple Color Emoji',
                  'Noto Color Emoji',
                  'Segoe UI Emoji',
                ],
              ),
            ),
            const SizedBox(height: 8),
            // タイトル
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.bold,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 6),
            // サブタイトル
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.75),
                fontSize: 13,
              ),
            ),
            const Spacer(),
            // フッター
            Row(
              children: [
                Text(
                  '#BeWell',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                if (bottomLabel != null)
                  Text(
                    bottomLabel!,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
