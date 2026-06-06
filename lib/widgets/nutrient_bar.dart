import 'package:flutter/material.dart';

class NutrientBar extends StatelessWidget {
  final String label;
  final double current;
  final double goal;
  final Color color;
  final String unit;

  const NutrientBar({
    super.key,
    required this.label,
    required this.current,
    required this.goal,
    required this.color,
    this.unit = 'g',
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isOver = goal > 0 && current > goal;
    final progress = goal > 0 ? (current / goal).clamp(0.0, 1.0) : 0.0;
    final displayColor = isOver ? scheme.error : color;
    final valueText = isOver
        ? '${current.toStringAsFixed(1)} / ${goal.toStringAsFixed(1)} $unit  (+${(current - goal).toStringAsFixed(1)}超)'
        : '${current.toStringAsFixed(1)} / ${goal.toStringAsFixed(1)} $unit';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            Text(
              valueText,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: isOver ? scheme.error : scheme.onSurfaceVariant,
                    fontWeight: isOver ? FontWeight.w700 : FontWeight.w500,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: progress),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeOutCubic,
          builder: (context, value, _) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: value,
                backgroundColor: displayColor.withValues(alpha: 0.18),
                color: displayColor,
                minHeight: 8,
              ),
            );
          },
        ),
      ],
    );
  }
}
