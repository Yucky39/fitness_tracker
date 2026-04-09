import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/sleep_provider.dart';
import '../providers/training_provider.dart';

class SleepDetailScreen extends ConsumerStatefulWidget {
  const SleepDetailScreen({super.key});

  @override
  ConsumerState<SleepDetailScreen> createState() => _SleepDetailScreenState();
}

class _SleepDetailScreenState extends ConsumerState<SleepDetailScreen> {
  @override
  void initState() {
    super.initState();
    // 最新の14日間データをロード
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(sleepProvider.notifier).load14DayTrend();
    });
  }

  @override
  Widget build(BuildContext context) {
    final sleepState = ref.watch(sleepProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('睡眠の記録'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: '睡眠目標を設定',
            onPressed: () => _showGoalDialog(context, ref, sleepState),
          ),
        ],
      ),
      body: sleepState.recentLogs.isEmpty
          ? _buildEmptyState(context, sleepState, scheme)
          : CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _buildSummaryCard(context, sleepState, scheme),
                      const SizedBox(height: 16),
                      _buildTrendChart(context, sleepState, scheme),
                      const SizedBox(height: 16),
                      _buildCorrelationCard(context, sleepState, scheme),
                      const SizedBox(height: 16),
                      _buildLogList(context, sleepState, scheme),
                    ]),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildEmptyState(
      BuildContext context, SleepState state, ColorScheme scheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bedtime_outlined, size: 64, color: scheme.outlineVariant),
          const SizedBox(height: 16),
          Text(
            '睡眠データがありません',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'ヘルスケアアプリと連携すると\n睡眠データが自動取得されます',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 24),
          if (!state.permissionGranted)
            FilledButton.tonal(
              onPressed: () async {
                await ref.read(sleepProvider.notifier).requestAndFetch();
              },
              child: const Text('ヘルスケアと連携'),
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
      BuildContext context, SleepState state, ColorScheme scheme) {
    final goalMinutes = state.goalMinutes;
    final lastSleep = state.sleepMinutes;
    final progress = lastSleep != null && goalMinutes > 0
        ? (lastSleep / goalMinutes).clamp(0.0, 1.0)
        : 0.0;

    final avgMinutes = state.recentLogs.isEmpty
        ? 0
        : (state.recentLogs.fold(0, (s, l) => s + l.durationMinutes) /
                state.recentLogs.length)
            .round();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('昨夜の睡眠',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    )),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lastSleep != null
                            ? '${lastSleep ~/ 60}時間${lastSleep % 60}分'
                            : 'データなし',
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: _qualityColor(state.quality, scheme),
                                ),
                      ),
                      Text(
                        '目標: ${goalMinutes ~/ 60}時間${goalMinutes % 60 > 0 ? '${goalMinutes % 60}分' : ''}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '14日平均',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                    Text(
                      '${avgMinutes ~/ 60}時間${avgMinutes % 60}分',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: Colors.indigo.withValues(alpha: 0.15),
                color: _qualityColor(state.quality, scheme),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              state.quality == SleepQuality.good
                  ? '目標達成！ ${state.quality.emoji}'
                  : '${((1 - progress) * goalMinutes / 60).toStringAsFixed(1)}時間不足 ${state.quality.emoji}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendChart(
      BuildContext context, SleepState state, ColorScheme scheme) {
    final logs = state.recentLogs;
    if (logs.isEmpty) return const SizedBox.shrink();

    final spots = logs.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.durationHours);
    }).toList();

    final goalHours = state.goalMinutes / 60.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('過去14日間のトレンド',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    )),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: (goalHours + 2).ceilToDouble(),
                  gridData: const FlGridData(show: true),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 2,
                        reservedSize: 32,
                        getTitlesWidget: (v, _) => Text(
                          '${v.toInt()}h',
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: (logs.length / 4).ceilToDouble(),
                        getTitlesWidget: (v, _) {
                          final idx = v.toInt();
                          if (idx < 0 || idx >= logs.length) {
                            return const SizedBox.shrink();
                          }
                          return Text(
                            DateFormat('M/d').format(logs[idx].date),
                            style: const TextStyle(fontSize: 9),
                          );
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: Colors.indigo,
                      barWidth: 2.5,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.indigo.withValues(alpha: 0.1),
                      ),
                    ),
                  ],
                  extraLinesData: ExtraLinesData(
                    horizontalLines: [
                      HorizontalLine(
                        y: goalHours,
                        color: Colors.green,
                        strokeWidth: 1.5,
                        dashArray: [6, 4],
                        label: HorizontalLineLabel(
                          show: true,
                          labelResolver: (_) => '目標 ${goalHours.toStringAsFixed(1)}h',
                          style: const TextStyle(
                              fontSize: 10, color: Colors.green),
                          alignment: Alignment.topRight,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCorrelationCard(
      BuildContext context, SleepState sleepState, ColorScheme scheme) {
    final trainingState = ref.watch(trainingProvider);
    final logs = sleepState.recentLogs;
    if (logs.length < 3) return const SizedBox.shrink();

    final goodSleepDays = logs
        .where((l) => l.durationMinutes >= sleepState.goalMinutes)
        .map((l) => DateFormat('yyyy-MM-dd').format(l.date))
        .toSet();

    final poorSleepDays = logs
        .where((l) => l.durationMinutes < sleepState.goalMinutes)
        .map((l) => DateFormat('yyyy-MM-dd').format(l.date))
        .toSet();

    // 過去14日間のトレーニングログ
    final since = DateTime.now().subtract(const Duration(days: 14));
    final recentTraining = trainingState.logs
        .where((l) => l.date.isAfter(since))
        .toList();

    int goodSleepTrainingCount = 0;
    int poorSleepTrainingCount = 0;

    for (final log in recentTraining) {
      final dateKey = DateFormat('yyyy-MM-dd').format(log.date);
      if (goodSleepDays.contains(dateKey)) {
        goodSleepTrainingCount++;
      } else if (poorSleepDays.contains(dateKey)) {
        poorSleepTrainingCount++;
      }
    }

    final goodDayCount = goodSleepDays.length;
    final poorDayCount = poorSleepDays.length;

    final goodAvg = goodDayCount > 0
        ? (goodSleepTrainingCount / goodDayCount).toStringAsFixed(1)
        : '—';
    final poorAvg = poorDayCount > 0
        ? (poorSleepTrainingCount / poorDayCount).toStringAsFixed(1)
        : '—';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('睡眠 × トレーニング',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    )),
            const SizedBox(height: 8),
            Text(
              '良眠の日（目標達成）と睡眠不足の日のトレーニング回数を比較',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _correlationTile(
                    context,
                    '😴 良眠の日',
                    '$goodAvg 回/日',
                    Colors.green,
                    scheme,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _correlationTile(
                    context,
                    '😵 睡眠不足の日',
                    '$poorAvg 回/日',
                    Colors.orange,
                    scheme,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _correlationTile(BuildContext context, String label, String value,
      Color color, ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color)),
          Text('トレーニング',
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _buildLogList(
      BuildContext context, SleepState state, ColorScheme scheme) {
    final logs = [...state.recentLogs].reversed.toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('履歴',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    )),
            const SizedBox(height: 8),
            for (final log in logs) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: log.durationMinutes >= state.goalMinutes
                            ? Colors.green
                            : log.durationMinutes >= 360
                                ? Colors.orange
                                : Colors.red,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(DateFormat('M月d日(E)', 'ja').format(log.date),
                        style: const TextStyle(fontSize: 13)),
                    const Spacer(),
                    Text(
                      '${log.durationMinutes ~/ 60}時間${log.durationMinutes % 60}分',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),
              if (log != logs.last) const Divider(height: 1),
            ],
          ],
        ),
      ),
    );
  }

  Color _qualityColor(SleepQuality quality, ColorScheme scheme) {
    switch (quality) {
      case SleepQuality.good:
        return Colors.green;
      case SleepQuality.fair:
        return Colors.orange;
      case SleepQuality.poor:
        return Colors.red;
      case SleepQuality.unknown:
        return scheme.onSurfaceVariant;
    }
  }

  void _showGoalDialog(
      BuildContext context, WidgetRef ref, SleepState state) {
    final hours = state.goalMinutes ~/ 60;
    final minutes = state.goalMinutes % 60;
    final hoursCtrl =
        TextEditingController(text: hours.toString());
    final minutesCtrl =
        TextEditingController(text: minutes.toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('睡眠目標を設定'),
        content: Row(
          children: [
            Expanded(
              child: TextField(
                controller: hoursCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '時間',
                  suffixText: 'h',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: minutesCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '分',
                  suffixText: 'min',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () {
              final h = int.tryParse(hoursCtrl.text) ?? 7;
              final m = int.tryParse(minutesCtrl.text) ?? 0;
              ref
                  .read(sleepProvider.notifier)
                  .setGoal(h * 60 + m);
              Navigator.pop(ctx);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
}
