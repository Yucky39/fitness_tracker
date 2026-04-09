import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/training_log.dart';

/// 種目の重量推移を表示するボトムシート
void showExerciseWeightChartSheet(
  BuildContext context, {
  required String exerciseName,
  required List<TrainingLog> allLogs,
}) {
  final logs = allLogs
      .where((l) => l.exerciseName == exerciseName && l.weight > 0)
      .toList()
    ..sort((a, b) => a.date.compareTo(b.date));

  if (logs.isEmpty) return;

  showModalBottomSheet<void>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$exerciseName - 重量推移',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                lineBarsData: [
                  LineChartBarData(
                    spots: logs.asMap().entries.map((e) {
                      return FlSpot(e.key.toDouble(), e.value.weight);
                    }).toList(),
                    isCurved: true,
                    color: Colors.teal,
                    barWidth: 3,
                    dotData: const FlDotData(show: true),
                  ),
                ],
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: (logs.length / 4)
                          .ceilToDouble()
                          .clamp(1, logs.length.toDouble()),
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i >= 0 && i < logs.length) {
                          return Text(
                            DateFormat('M/d').format(logs[i].date),
                            style: const TextStyle(fontSize: 9),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(
                    sideTitles:
                        SideTitles(showTitles: true, reservedSize: 36),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                gridData: const FlGridData(show: true),
                borderData: FlBorderData(show: true),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
