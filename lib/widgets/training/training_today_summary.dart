import 'package:flutter/material.dart';

import '../../models/training_log.dart';
import '../../services/training_calorie_calculator.dart';

/// 選択日のトレーニングセッションサマリーカード
class TrainingTodaySummary extends StatelessWidget {
  final List<TrainingLog> todayLogs;
  final double bodyWeightKg;
  /// 表示中の日付（null の場合は今日として扱う）
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
    if (d.year == yesterday.year && d.month == yesterday.month && d.day == yesterday.day) {
      return '昨日のセッション';
    }
    return '${d.month}/${d.day} のセッション';
  }

  @override
  Widget build(BuildContext context) {
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
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.deepOrange.shade400,
            Colors.orange.shade300,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _sessionLabel(),
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _SummaryItem(
                label: '消費カロリー',
                value: '${totalKcal.round()} kcal',
                icon: Icons.local_fire_department,
                sub: '目安値',
              ),
              if (totalVolume > 0)
                _SummaryItem(
                  label: '総ボリューム',
                  value: totalVolume >= 1000
                      ? '${(totalVolume / 1000).toStringAsFixed(1)} t'
                      : '${totalVolume.round()} kg',
                  icon: Icons.fitness_center,
                  sub: '重量×回数×セット',
                ),
              if (totalDistanceKm > 0)
                _SummaryItem(
                  label: '走行距離',
                  value: '${totalDistanceKm.toStringAsFixed(1)} km',
                  icon: Icons.directions_run,
                  sub: '有酸素合計',
                ),
              _SummaryItem(
                label: '種目数',
                value: '$exerciseCount 種目',
                icon: Icons.list_alt_outlined,
                sub: '',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final String sub;

  const _SummaryItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15)),
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 11)),
        if (sub.isNotEmpty)
          Text(sub,
              style: const TextStyle(color: Colors.white54, fontSize: 10)),
      ],
    );
  }
}
