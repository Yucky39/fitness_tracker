import 'package:flutter/material.dart';

import '../../models/training_log.dart';
import '../../services/training_calorie_calculator.dart';
import '../../theme/app_tokens.dart';
import '../../theme/bewell_colors.dart';

/// 選択日のトレーニングセッションサマリーカード
class TrainingTodaySummary extends StatelessWidget {
  final List<TrainingLog> todayLogs;
  final double bodyWeightKg;
  final DateTime? date;

  const TrainingTodaySummary({
    super.key,
    required this.todayLogs,
    required this.bodyWeightKg,
    this.date,
  });

  String _sessionLabel() {
    final d = date ?? DateTime.now();
    final now = DateTime.now();
    if (d.year == now.year && d.month == now.month && d.day == now.day) {
      return '今日のセッション';
    }
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    if (d.year == yesterday.year &&
        d.month == yesterday.month &&
        d.day == yesterday.day) {
      return '昨日のセッション';
    }
    return '${d.month}/${d.day} のセッション';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final semantic = context.bewellColors;
    final totalKcal = TrainingCalorieCalculator.total(todayLogs,
        bodyWeightKg: bodyWeightKg);
    final cardioLogs =
        todayLogs.where((l) => l.exerciseType == ExerciseType.cardio).toList();
    final strengthLogs =
        todayLogs.where((l) => l.exerciseType != ExerciseType.cardio).toList();
    final totalVolume =
        strengthLogs.fold(0.0, (s, l) => s + l.totalVolume);
    final totalDistanceKm =
        cardioLogs.fold(0.0, (s, l) => s + l.distanceKm);
    final exerciseCount =
        todayLogs.map((l) => l.exerciseName).toSet().length;

    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.xs,
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            semantic.heroGradientStart,
            semantic.heroGradientEnd,
          ],
        ),
        borderRadius: AppRadius.lgAll,
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _sessionLabel(),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: scheme.onPrimaryContainer,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _SummaryItem(
                label: '消費カロリー',
                value: '${totalKcal.round()} kcal',
                icon: Icons.local_fire_department_outlined,
                sub: '目安値',
                foreground: scheme.onPrimaryContainer,
              ),
              if (totalVolume > 0)
                _SummaryItem(
                  label: '総ボリューム',
                  value: totalVolume >= 1000
                      ? '${(totalVolume / 1000).toStringAsFixed(1)} t'
                      : '${totalVolume.round()} kg',
                  icon: Icons.stacked_bar_chart_rounded,
                  foreground: scheme.onPrimaryContainer,
                ),
              if (totalDistanceKm > 0)
                _SummaryItem(
                  label: '総距離',
                  value: '${totalDistanceKm.toStringAsFixed(1)} km',
                  icon: Icons.directions_run_rounded,
                  foreground: scheme.onPrimaryContainer,
                ),
              _SummaryItem(
                label: '種目数',
                value: '$exerciseCount',
                icon: Icons.fitness_center_rounded,
                foreground: scheme.onPrimaryContainer,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.foreground,
    this.sub,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color foreground;
  final String? sub;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 18, color: foreground.withValues(alpha: 0.85)),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w800,
              ),
        ),
        Text(
          sub != null ? '$label ($sub)' : label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: foreground.withValues(alpha: 0.75),
              ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
