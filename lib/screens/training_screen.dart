import 'dart:async';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/training_log.dart';
import '../providers/training_provider.dart';
import 'routine_screen.dart';

class TrainingScreen extends ConsumerStatefulWidget {
  const TrainingScreen({super.key});

  @override
  ConsumerState<TrainingScreen> createState() => _TrainingScreenState();
}

class _TrainingScreenState extends ConsumerState<TrainingScreen> {
  // Interval timer state
  Timer? _timer;
  int _timerSeconds = 0;
  bool _timerRunning = false;
  int _timerTotal = 0;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer(int seconds) {
    _timer?.cancel();
    setState(() {
      _timerTotal = seconds;
      _timerSeconds = seconds;
      _timerRunning = true;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_timerSeconds <= 0) {
        t.cancel();
        setState(() => _timerRunning = false);
      } else {
        setState(() => _timerSeconds--);
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    setState(() {
      _timerRunning = false;
      _timerSeconds = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final trainingState = ref.watch(trainingProvider);
    final trainingNotifier = ref.read(trainingProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('トレーニング記録'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            tooltip: 'ルーティン管理',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RoutineScreen()),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          trainingState.isLoading
              ? const Center(child: CircularProgressIndicator())
              : trainingState.logs.isEmpty
                  ? const Center(child: Text('まだ記録がありません'))
                  : CustomScrollView(
                      slivers: [
                        SliverToBoxAdapter(
                          child: _buildOneRmCard(trainingState),
                        ),
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final log = trainingState.logs[index];
                              return _buildLogItem(
                                  context, log, trainingNotifier);
                            },
                            childCount: trainingState.logs.length,
                          ),
                        ),
                        const SliverToBoxAdapter(
                            child: SizedBox(height: 80)),
                      ],
                    ),
          // Interval timer overlay
          if (_timerRunning || _timerSeconds > 0)
            _buildTimerOverlay(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddTrainingDialog(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildOneRmCard(TrainingState state) {
    // Group by exercise, find best estimated 1RM using Epley: w*(1+reps/30)
    final Map<String, double> bestOneRm = {};
    for (final log in state.logs) {
      if (log.reps > 0 && log.weight > 0) {
        final est = log.weight * (1 + log.reps / 30);
        if (!bestOneRm.containsKey(log.exerciseName) ||
            est > bestOneRm[log.exerciseName]!) {
          bestOneRm[log.exerciseName] = est;
        }
      }
    }
    if (bestOneRm.isEmpty) return const SizedBox.shrink();

    final sorted = bestOneRm.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(4).toList();

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.emoji_events, color: Colors.amber, size: 18),
                SizedBox(width: 6),
                Text('推定1RM（エプリー式）',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: top.map((e) {
                return GestureDetector(
                  onTap: () => _showExerciseChart(context, e.key),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primaryContainer
                          .withOpacity(0.5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(e.key,
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                        Text(
                          '${e.value.toStringAsFixed(1)} kg',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 4),
            const Text('タップで重量推移グラフを表示',
                style: TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  void _showExerciseChart(BuildContext context, String exerciseName) {
    final logs = ref
        .read(trainingProvider)
        .logs
        .where((l) => l.exerciseName == exerciseName && l.weight > 0)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    if (logs.isEmpty) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$exerciseName - 重量推移',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  lineBarsData: [
                    LineChartBarData(
                      spots: logs.asMap().entries.map((e) {
                        return FlSpot(
                            e.key.toDouble(), e.value.weight);
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
                        interval: (logs.length / 4).ceilToDouble().clamp(1, logs.length.toDouble()),
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
                        sideTitles: SideTitles(
                            showTitles: true, reservedSize: 36)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
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

  Widget _buildLogItem(
      BuildContext context, TrainingLog log, TrainingNotifier notifier) {
    return Dismissible(
      key: Key(log.id),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('削除の確認'),
                content: const Text('この記録を削除しますか？'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('キャンセル'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('削除'),
                  ),
                ],
              ),
            ) ??
            false;
      },
      onDismissed: (_) => notifier.deleteLog(log.id),
      background: Container(color: Colors.red),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: ListTile(
          title: Text(log.exerciseName,
              style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(
            '${log.weight}kg × ${log.reps}回 × ${log.sets}セット  '
            'インターバル: ${log.interval}秒\n'
            '${DateFormat('yyyy/MM/dd HH:mm').format(log.date)}'
            '${log.note.isNotEmpty ? '\nメモ: ${log.note}' : ''}',
          ),
          isThreeLine: log.note.isNotEmpty,
          trailing: log.interval > 0
              ? IconButton(
                  icon: const Icon(Icons.timer_outlined, color: Colors.teal),
                  tooltip: 'インターバルタイマー開始',
                  onPressed: () => _startTimer(log.interval),
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildTimerOverlay() {
    final progress = _timerTotal > 0 ? _timerSeconds / _timerTotal : 0.0;
    final mins = _timerSeconds ~/ 60;
    final secs = _timerSeconds % 60;
    final isDone = _timerSeconds == 0;

    return Positioned(
      bottom: 80,
      left: 16,
      right: 16,
      child: Card(
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: isDone ? Colors.green.shade50 : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              SizedBox(
                width: 56,
                height: 56,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.grey.withOpacity(0.2),
                      valueColor: AlwaysStoppedAnimation<Color>(
                          isDone ? Colors.green : Colors.teal),
                    ),
                    Icon(
                      isDone ? Icons.check : Icons.timer,
                      color: isDone ? Colors.green : Colors.teal,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isDone ? '休憩終了！' : 'インターバル休憩中',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDone ? Colors.green : null),
                    ),
                    if (!isDone)
                      Text(
                        '$mins:${secs.toString().padLeft(2, '0')}',
                        style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: _stopTimer,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddTrainingDialog(BuildContext context, WidgetRef ref) {
    final weightController = TextEditingController();
    final repsController = TextEditingController();
    final setsController = TextEditingController();
    final intervalController = TextEditingController();
    final noteController = TextEditingController();
    String exerciseName = '';

    final recentExerciseNames = ref
        .read(trainingProvider)
        .logs
        .map((l) => l.exerciseName)
        .toSet()
        .toList()
      ..sort();

    showDialog(
      context: context,
      builder: (context) {
        TrainingLog? previousLog;

        return StatefulBuilder(
          builder: (context, setState) {
            void fillFromPreviousLog(String name) {
              final prev =
                  ref.read(trainingProvider.notifier).getPreviousLog(name);
              setState(() {
                previousLog = prev;
                if (prev != null) {
                  weightController.text = prev.weight.toString();
                  repsController.text = prev.reps.toString();
                  setsController.text = prev.sets.toString();
                  intervalController.text = prev.interval.toString();
                }
              });
            }

            return AlertDialog(
              title: const Text('トレーニングを記録'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Autocomplete<String>(
                      optionsBuilder: (textEditingValue) {
                        exerciseName = textEditingValue.text;
                        if (textEditingValue.text.isEmpty) {
                          return recentExerciseNames;
                        }
                        return recentExerciseNames.where((name) =>
                            name.toLowerCase().contains(
                                textEditingValue.text.toLowerCase()));
                      },
                      onSelected: (selection) {
                        exerciseName = selection;
                        fillFromPreviousLog(selection);
                      },
                      fieldViewBuilder:
                          (ctx, controller, focusNode, onFieldSubmitted) {
                        return TextField(
                          controller: controller,
                          focusNode: focusNode,
                          decoration:
                              const InputDecoration(labelText: '種目名'),
                          onChanged: (value) {
                            exerciseName = value;
                            final prev = ref
                                .read(trainingProvider.notifier)
                                .getPreviousLog(value);
                            setState(() => previousLog = prev);
                          },
                        );
                      },
                    ),
                    if (previousLog != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          '前回: ${previousLog!.weight}kg × ${previousLog!.reps}回 × ${previousLog!.sets}セット'
                          '${previousLog!.note.isNotEmpty ? '\nメモ: ${previousLog!.note}' : ''}',
                          style: TextStyle(
                              color: Colors.grey[600], fontSize: 12),
                        ),
                      ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: weightController,
                            decoration:
                                const InputDecoration(labelText: '重量 (kg)'),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextField(
                            controller: repsController,
                            decoration:
                                const InputDecoration(labelText: '回数'),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: setsController,
                            decoration:
                                const InputDecoration(labelText: 'セット数'),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextField(
                            controller: intervalController,
                            decoration: const InputDecoration(
                                labelText: 'インターバル (秒)'),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    TextField(
                      controller: noteController,
                      decoration: const InputDecoration(labelText: 'メモ'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('キャンセル'),
                ),
                TextButton(
                  onPressed: () {
                    if (exerciseName.isNotEmpty) {
                      final interval =
                          int.tryParse(intervalController.text) ?? 0;
                      ref.read(trainingProvider.notifier).addLog(
                            exerciseName: exerciseName,
                            weight:
                                double.tryParse(weightController.text) ?? 0,
                            reps: int.tryParse(repsController.text) ?? 0,
                            sets: int.tryParse(setsController.text) ?? 0,
                            interval: interval,
                            note: noteController.text,
                          );
                      Navigator.pop(context);
                      // Auto-start timer if interval is set
                      if (interval > 0) _startTimer(interval);
                    }
                  },
                  child: const Text('記録'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
