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
    final bool isOver = goal > 0 && current > goal;
    final double progress = goal > 0 ? (current / goal).clamp(0.0, 1.0) : 0.0;
    final Color displayColor = isOver ? Colors.red : color;
    final String valueText = isOver
        ? '${current.toStringAsFixed(1)} / ${goal.toStringAsFixed(1)} $unit  (+${(current - goal).toStringAsFixed(1)}超)'
        : '${current.toStringAsFixed(1)} / ${goal.toStringAsFixed(1)} $unit';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(
              valueText,
              style: TextStyle(
                color: isOver ? Colors.red : Colors.grey[600],
                fontSize: 12,
                fontWeight: isOver ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: progress,
          backgroundColor: displayColor.withValues(alpha: 0.2),
          color: displayColor,
          minHeight: 8,
          borderRadius: BorderRadius.circular(4),
        ),
      ],
    );
  }
}
