import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/dashboard_provider.dart';
import '../providers/meal_provider.dart';
import '../providers/progress_provider.dart';
import '../providers/routine_provider.dart';
import '../providers/training_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mealState = ref.watch(mealProvider);
    final trainingState = ref.watch(trainingProvider);
    final progressState = ref.watch(progressProvider);
    final dashboardState = ref.watch(dashboardProvider);
    final routineState = ref.watch(routineProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ダッシュボード'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.read(dashboardProvider.notifier).loadWeeklyData(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(dashboardProvider.notifier).loadWeeklyData(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTodaySummary(context, mealState, routineState),
              const SizedBox(height: 16),
              _buildWeeklyCalorieChart(
                  context, dashboardState, mealState.calorieGoal),
              const SizedBox(height: 16),
              if (progressState.metrics.isNotEmpty) ...[
                _buildLatestMetrics(progressState),
                const SizedBox(height: 16),
              ],
              _buildLastWorkout(trainingState),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTodaySummary(
      BuildContext context, MealState mealState, RoutineState routineState) {
    final percent =
        (mealState.totalCalories / mealState.calorieGoal).clamp(0.0, 1.0);
    final isOver = mealState.totalCalories > mealState.calorieGoal;
    final remaining = (mealState.calorieGoal - mealState.totalCalories).abs();
    final todaysRoutines = routineState.routines
        .where((r) => r.weekdays.contains(DateTime.now().weekday))
        .toList();

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.today, color: Colors.teal, size: 20),
                const SizedBox(width: 6),
                Text(
                  '今日 ${DateFormat('M月d日(E)', 'ja').format(DateTime.now())}',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                SizedBox(
                  width: 110,
                  height: 110,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: percent,
                        strokeWidth: 12,
                        backgroundColor: Colors.grey.withOpacity(0.2),
                        valueColor: AlwaysStoppedAnimation<Color>(
                            isOver ? Colors.red : Colors.teal),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${mealState.totalCalories}',
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const Text('kcal',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _macroRow('目標', '${mealState.calorieGoal} kcal',
                          Colors.grey),
                      _macroRow(
                          isOver ? '超過' : '残り',
                          '$remaining kcal',
                          isOver ? Colors.red : Colors.green),
                      const Divider(height: 12),
                      _macroRow(
                          'P',
                          '${mealState.totalProtein.toStringAsFixed(1)}g',
                          Colors.blue),
                      _macroRow(
                          'F',
                          '${mealState.totalFat.toStringAsFixed(1)}g',
                          Colors.orange),
                      _macroRow(
                          'C',
                          '${mealState.totalCarbs.toStringAsFixed(1)}g',
                          Colors.purple),
                    ],
                  ),
                ),
              ],
            ),
            if (todaysRoutines.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.fitness_center,
                      size: 16, color: Colors.teal),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '今日のメニュー: ${todaysRoutines.map((r) => r.name).join(' / ')}',
                      style:
                          const TextStyle(fontSize: 13, color: Colors.teal),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _macroRow(String label, String value, Color color) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 1.5),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(fontSize: 12, color: color)),
            Text(value,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color)),
          ],
        ),
      );

  Widget _buildWeeklyCalorieChart(
      BuildContext context, DashboardState state, int calorieGoal) {
    const weekdayLabels = ['月', '火', '水', '木', '金', '土', '日'];

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('今週のカロリー',
                style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : SizedBox(
                    height: 180,
                    child: BarChart(
                      BarChartData(
                        maxY: (calorieGoal * 1.4).toDouble(),
                        barGroups: state.weeklyCalories.entries
                            .toList()
                            .asMap()
                            .entries
                            .map((entry) {
                          final i = entry.key;
                          final calories =
                              entry.value.value.toDouble();
                          final isEmpty = calories == 0;
                          final isOver = calories > calorieGoal;
                          return BarChartGroupData(
                            x: i,
                            barRods: [
                              BarChartRodData(
                                toY: isEmpty ? 0.5 : calories,
                                color: isEmpty
                                    ? Colors.grey.withOpacity(0.2)
                                    : isOver
                                        ? Colors.red.withOpacity(0.8)
                                        : Colors.teal.withOpacity(0.8),
                                width: 26,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(4),
                                  topRight: Radius.circular(4),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                        titlesData: FlTitlesData(
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                final dates = state.weeklyCalories.keys
                                    .toList();
                                if (value.toInt() < dates.length) {
                                  final wd =
                                      dates[value.toInt()].weekday;
                                  final isToday =
                                      dates[value.toInt()].day ==
                                          DateTime.now().day;
                                  return Text(
                                    weekdayLabels[wd - 1],
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: isToday
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: isToday
                                          ? Colors.teal
                                          : null,
                                    ),
                                  );
                                }
                                return const Text('');
                              },
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 42,
                              getTitlesWidget: (value, meta) => Text(
                                value.toInt().toString(),
                                style: const TextStyle(fontSize: 10),
                              ),
                            ),
                          ),
                          topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                        ),
                        extraLinesData: ExtraLinesData(
                          horizontalLines: [
                            HorizontalLine(
                              y: calorieGoal.toDouble(),
                              color: Colors.red.withOpacity(0.5),
                              strokeWidth: 1.5,
                              dashArray: [5, 5],
                              label: HorizontalLineLabel(
                                show: true,
                                labelResolver: (_) => '目標',
                                style: const TextStyle(
                                    fontSize: 10, color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                        gridData: const FlGridData(show: true),
                        borderData: FlBorderData(show: false),
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildLatestMetrics(ProgressState progressState) {
    final latest = progressState.metrics.last;
    final prev = progressState.metrics.length > 1
        ? progressState.metrics[progressState.metrics.length - 2]
        : null;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('最新の計測',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                Text(
                  DateFormat('M/d').format(latest.date),
                  style:
                      const TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _metricItem(
                    '体重',
                    '${latest.weight}kg',
                    prev != null
                        ? latest.weight - prev.weight
                        : null),
                _metricItem(
                    '体脂肪',
                    '${latest.bodyFatPercentage}%',
                    prev != null
                        ? latest.bodyFatPercentage -
                            prev.bodyFatPercentage
                        : null),
                _metricItem(
                    '腹囲',
                    '${latest.waist}cm',
                    prev != null
                        ? latest.waist - prev.waist
                        : null),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricItem(String label, String value, double? change) {
    Widget changeWidget = const SizedBox.shrink();
    if (change != null && change != 0) {
      final isGood = change < 0;
      changeWidget = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
              isGood ? Icons.arrow_downward : Icons.arrow_upward,
              size: 12,
              color: isGood ? Colors.green : Colors.red),
          Text(
            change.abs().toStringAsFixed(1),
            style: TextStyle(
                fontSize: 11,
                color: isGood ? Colors.green : Colors.red),
          ),
        ],
      );
    }
    return Column(
      children: [
        Text(label,
            style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold)),
        changeWidget,
      ],
    );
  }

  Widget _buildLastWorkout(TrainingState trainingState) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('前回のトレーニング',
                style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (trainingState.logs.isEmpty)
              const Text('まだ記録がありません',
                  style: TextStyle(color: Colors.grey))
            else ...[
              () {
                final lastDate = trainingState.logs.first.date;
                final lastDayLogs = trainingState.logs
                    .where((l) =>
                        l.date.year == lastDate.year &&
                        l.date.month == lastDate.month &&
                        l.date.day == lastDate.day)
                    .toList();
                final exercises =
                    lastDayLogs.map((l) => l.exerciseName).toSet().toList();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('yyyy/M/d').format(lastDate),
                      style: const TextStyle(
                          color: Colors.grey, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: exercises
                          .map((e) => Chip(
                                label: Text(e,
                                    style:
                                        const TextStyle(fontSize: 12)),
                                padding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                              ))
                          .toList(),
                    ),
                  ],
                );
              }(),
            ],
          ],
        ),
      ),
    );
  }
}
