import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/training_log.dart';
import '../providers/energy_profile_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/sleep_provider.dart';
import '../providers/training_advice_provider.dart';
import '../providers/training_provider.dart';
import '../services/health_service.dart';
import '../services/training_calorie_calculator.dart';
import 'routine_screen.dart';

class TrainingScreen extends ConsumerStatefulWidget {
  const TrainingScreen({super.key});

  @override
  ConsumerState<TrainingScreen> createState() => _TrainingScreenState();
}

class _TrainingScreenState extends ConsumerState<TrainingScreen> {
  Timer? _timer;
  int _timerSeconds = 0;
  bool _timerRunning = false;
  int _timerTotal = 0;

  @override
  void initState() {
    super.initState();
    if (HealthService.isSupported) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _autoImportFromHealth();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _autoImportFromHealth() async {
    final granted = await HealthService.requestPermissions();
    if (!granted || !mounted) return;

    final workouts = await HealthService.fetchRecentWorkouts(days: 30);
    if (workouts.isEmpty || !mounted) return;

    final notifier = ref.read(trainingProvider.notifier);

    final existingDates = ref
        .read(trainingProvider)
        .logs
        .where((l) => l.note == 'ヘルスケアから取得')
        .map((l) =>
            '${l.exerciseName}_${DateFormat('yyyyMMddHHmm').format(l.date)}')
        .toSet();

    final newWorkouts = workouts.where((w) {
      final key =
          '${w.exerciseName}_${DateFormat('yyyyMMddHHmm').format(w.date)}';
      return !existingDates.contains(key);
    }).toList();

    if (newWorkouts.isEmpty) return;

    for (final w in newWorkouts) {
      await notifier.addLogFromHealth(w);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ヘルスケアから ${newWorkouts.length} 件のワークアウトを取り込みました'),
        ),
      );
    }
  }

  void _startIntervalTimer(int seconds) {
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

  void _stopIntervalTimer() {
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
    final bodyWeightKg = ref.watch(energyProfileProvider).weightKg;
    final settings = ref.watch(settingsProvider);
    final sleepState = ref.watch(sleepProvider);
    final effectiveBw = bodyWeightKg > 0
        ? bodyWeightKg
        : TrainingCalorieCalculator.defaultBodyWeightKg;

    Widget bodyChild;
    if (trainingState.isLoading) {
      bodyChild = const Center(child: CircularProgressIndicator());
    } else if (trainingState.logs.isEmpty) {
      bodyChild = const Center(
        child: Text(
          'まだ記録がありません\n右下の + ボタンで追加できます',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
      );
    } else {
      bodyChild = _buildBody(
        context,
        ref,
        trainingState,
        trainingNotifier,
        effectiveBw,
        settings,
        sleepState,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('トレーニング記録'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            tooltip: 'ルーティン管理',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const RoutineScreen(),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          bodyChild,
          if (_timerRunning || _timerSeconds > 0) _buildTimerOverlay(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showTrainingDialog(
          context: context,
          ref: ref,
          notifier: trainingNotifier,
          bodyWeightKg: effectiveBw,
        ),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    TrainingState state,
    TrainingNotifier notifier,
    double bodyWeightKg,
    SettingsState settings,
    SleepState sleepState,
  ) {
    final todayLogs = state.todayLogs;
    final adviceState = ref.watch(trainingAdviceProvider);

    return CustomScrollView(
      slivers: [
        if (todayLogs.isNotEmpty)
          SliverToBoxAdapter(
            child: _buildTodaySummary(context, todayLogs, bodyWeightKg),
          ),
        SliverToBoxAdapter(
          child: _buildOneRmCard(state),
        ),

        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final log = state.logs[index];
              final isPr = notifier.isPersonalRecord(log);
              final kcal = TrainingNotifier.estimateCalories(log,
                  bodyWeightKg: bodyWeightKg);

              return _TrainingLogCard(
                log: log,
                isPr: isPr,
                estimatedKcal: kcal,
                bodyWeightKg: bodyWeightKg,
                onEdit: () => _showTrainingDialog(
                  context: context,
                  ref: ref,
                  notifier: notifier,
                  existingLog: log,
                  bodyWeightKg: bodyWeightKg,
                ),
                onDelete: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('削除の確認'),
                      content: const Text('この記録を削除しますか？'),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('キャンセル')),
                        TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('削除')),
                      ],
                    ),
                  );
                  if (ok == true) notifier.deleteLog(log.id);
                },
                onIntervalTimer: log.interval > 0
                    ? () => _startIntervalTimer(log.interval)
                    : null,
                showAiAdvice: settings.trainingAdviceEnabled,
                aiLoading: adviceState.loadingLogId == log.id,
                aiAdvice: adviceState.adviceByLogId[log.id] ?? log.aiAdvice,
                aiError: adviceState.errorLogId == log.id
                    ? adviceState.errorMessage
                    : null,
                onRequestAiAdvice: settings.trainingAdviceEnabled
                    ? () => ref
                        .read(trainingAdviceProvider.notifier)
                        .fetchAdviceForLog(
                          log: log,
                          allLogs: state.logs,
                          adviceLevel: settings.adviceLevel,
                          apiKey: settings.currentApiKey,
                          provider: settings.selectedProvider,
                          model: settings.currentModel,
                          sleepContext: sleepState.adviceContext,
                        )
                    : null,
              );
            },
            childCount: state.logs.length,
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ],
    );
  }

  // ── Today's session summary ──────────────────────────────────────────────

  Widget _buildTodaySummary(
      BuildContext context, List<TrainingLog> todayLogs, double bodyWeightKg) {
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
          const Text(
            '今日のセッション',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _summaryItem('消費カロリー', '${totalKcal.round()} kcal',
                  Icons.local_fire_department, '目安値'),
              if (totalVolume > 0)
                _summaryItem(
                    '総ボリューム',
                    totalVolume >= 1000
                        ? '${(totalVolume / 1000).toStringAsFixed(1)} t'
                        : '${totalVolume.round()} kg',
                    Icons.fitness_center,
                    '重量×回数×セット'),
              if (totalDistanceKm > 0)
                _summaryItem(
                    '走行距離',
                    '${totalDistanceKm.toStringAsFixed(1)} km',
                    Icons.directions_run,
                    '有酸素合計'),
              _summaryItem('種目数', '$exerciseCount 種目',
                  Icons.list_alt_outlined, ''),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryItem(
      String label, String value, IconData icon, String sub) {
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

  // ── Add / Edit dialog ────────────────────────────────────────────────────

  void _showTrainingDialog({
    required BuildContext context,
    required WidgetRef ref,
    required TrainingNotifier notifier,
    TrainingLog? existingLog,
    required double bodyWeightKg,
  }) {
    final isEdit = existingLog != null;
    final weightController = TextEditingController(
        text: isEdit && existingLog.weight > 0
            ? existingLog.weight.toString()
            : '');
    final repsController = TextEditingController(
        text: isEdit ? existingLog.reps.toString() : '');
    final setsController = TextEditingController(
        text: isEdit ? existingLog.sets.toString() : '');
    final intervalController = TextEditingController(
        text: isEdit ? existingLog.interval.toString() : '');
    final distanceController = TextEditingController(
        text: isEdit && existingLog.distanceKm > 0
            ? existingLog.distanceKm.toString()
            : '');
    final durationController = TextEditingController(
        text: isEdit && existingLog.durationMinutes > 0
            ? existingLog.durationMinutes.toString()
            : '');
    final noteController =
        TextEditingController(text: isEdit ? existingLog.note : '');

    String exerciseName = existingLog?.exerciseName ?? '';
    ExerciseType exerciseType =
        existingLog?.exerciseType ?? ExerciseType.freeWeight;

    final allExerciseNames = [
      for (final list in ExercisePresets.byCategory.values) ...list
    ];
    final recentExerciseNames = ref
        .read(trainingProvider)
        .logs
        .map((l) => l.exerciseName)
        .toSet()
        .toList()
      ..sort();
    final suggestions = <String>{
      ...recentExerciseNames,
      ...allExerciseNames,
    }.toList();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          TrainingLog? previousLog;
          double previewKcal = 0;

          void updatePreview() {
            if (exerciseType == ExerciseType.cardio) {
              final dur = int.tryParse(durationController.text) ?? 0;
              previewKcal = TrainingCalorieCalculator.estimate(
                weight: 0,
                reps: 0,
                sets: 0,
                intervalSec: 0,
                exerciseType: ExerciseType.cardio,
                bodyWeightKg: bodyWeightKg,
                exerciseName: exerciseName,
                durationMinutes: dur,
              );
            } else {
              final w = double.tryParse(weightController.text) ?? 0;
              final r = int.tryParse(repsController.text) ?? 0;
              final s = int.tryParse(setsController.text) ?? 0;
              final iv = int.tryParse(intervalController.text) ?? 0;
              previewKcal = TrainingCalorieCalculator.estimate(
                weight: w,
                reps: r,
                sets: s,
                intervalSec: iv,
                exerciseType: exerciseType,
                bodyWeightKg: bodyWeightKg,
              );
            }
          }

          void fillFromPreviousLog(String name) {
            final prev =
                notifier.getPreviousLog(name, excludeId: existingLog?.id);
            if (prev != null) {
              setState(() {
                previousLog = prev;
                if (prev.exerciseType == ExerciseType.cardio) {
                  distanceController.text = prev.distanceKm > 0
                      ? prev.distanceKm.toString()
                      : '';
                  durationController.text = prev.durationMinutes > 0
                      ? prev.durationMinutes.toString()
                      : '';
                } else {
                  weightController.text = prev.weight.toString();
                  repsController.text = prev.reps.toString();
                  setsController.text = prev.sets.toString();
                  intervalController.text = prev.interval.toString();
                }
                exerciseType = prev.exerciseType;
                updatePreview();
              });
            } else {
              setState(() {
                previousLog = null;
                exerciseType = ExercisePresets.inferType(name);
              });
            }
          }

          updatePreview();

          final isCardio = exerciseType == ExerciseType.cardio;

          return AlertDialog(
            title: Text(isEdit ? 'トレーニングを編集' : 'トレーニングを記録'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Exercise name ────────────────────────────────────
                  Autocomplete<String>(
                    initialValue: TextEditingValue(text: exerciseName),
                    optionsBuilder: (v) {
                      exerciseName = v.text;
                      if (v.text.isEmpty) return suggestions.take(20);
                      return suggestions.where((n) =>
                          n.toLowerCase().contains(v.text.toLowerCase()));
                    },
                    onSelected: (sel) {
                      exerciseName = sel;
                      fillFromPreviousLog(sel);
                    },
                    fieldViewBuilder:
                        (ctx, controller, focusNode, onFieldSubmitted) {
                      return TextField(
                        controller: controller,
                        focusNode: focusNode,
                        decoration: const InputDecoration(labelText: '種目名'),
                        onChanged: (v) {
                          exerciseName = v;
                          exerciseType = ExercisePresets.inferType(v);
                          setState(updatePreview);
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 10),

                  // ── Exercise type ────────────────────────────────────
                  const Text('器具・種別',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    children: ExerciseType.values.map((t) {
                      return ChoiceChip(
                        label: Text(t.label),
                        selected: exerciseType == t,
                        onSelected: (_) => setState(() {
                          exerciseType = t;
                          updatePreview();
                        }),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _exerciseTypeHint(exerciseType),
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),

                  // ── Previous log hint ────────────────────────────────
                  if (previousLog != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.history, size: 14,
                              color: Colors.blue),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              previousLog!.exerciseType == ExerciseType.cardio
                                  ? '前回: ${previousLog!.durationMinutes}分'
                                    '${previousLog!.distanceKm > 0 ? '  ${previousLog!.distanceKm.toStringAsFixed(1)}km' : ''}'
                                    '  (${DateFormat('M/d').format(previousLog!.date)})'
                                  : '前回: ${previousLog!.weight}kg × ${previousLog!.reps}回 × ${previousLog!.sets}セット'
                                    '  (${DateFormat('M/d').format(previousLog!.date)})',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.blue),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 8),

                  // ── Cardio: distance + duration ──────────────────────
                  if (isCardio) ...[
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: distanceController,
                            decoration:
                                const InputDecoration(labelText: '距離 (km)'),
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            onChanged: (_) => setState(updatePreview),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: durationController,
                            decoration:
                                const InputDecoration(labelText: '時間 (分)'),
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setState(updatePreview),
                          ),
                        ),
                      ],
                    ),
                  ],

                  // ── Resistance: weight / reps / sets / interval ──────
                  if (!isCardio) ...[
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: weightController,
                            decoration: InputDecoration(
                              labelText:
                                  exerciseType == ExerciseType.bodyweight
                                      ? '追加重量 (kg)'
                                      : '重量 (kg)',
                              hintText:
                                  exerciseType == ExerciseType.bodyweight
                                      ? '0 = 自体重のみ'
                                      : '',
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            onChanged: (_) => setState(updatePreview),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: repsController,
                            decoration:
                                const InputDecoration(labelText: '回数'),
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setState(updatePreview),
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
                            onChanged: (_) => setState(updatePreview),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: intervalController,
                            decoration: const InputDecoration(
                                labelText: 'インターバル (秒)'),
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setState(updatePreview),
                          ),
                        ),
                      ],
                    ),
                  ],

                  TextField(
                    controller: noteController,
                    decoration: const InputDecoration(labelText: 'メモ'),
                  ),
                  const SizedBox(height: 14),

                  // ── Calorie preview ──────────────────────────────────
                  if (previewKcal > 0)
                    _CaloriePreviewChip(
                      kcal: previewKcal,
                      isCardio: isCardio,
                      weight: double.tryParse(weightController.text) ?? 0,
                      reps: int.tryParse(repsController.text) ?? 0,
                      sets: int.tryParse(setsController.text) ?? 0,
                      exerciseType: exerciseType,
                      distanceKm:
                          double.tryParse(distanceController.text) ?? 0,
                      durationMinutes:
                          int.tryParse(durationController.text) ?? 0,
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('キャンセル')),
              TextButton(
                onPressed: () {
                  if (exerciseName.isEmpty) return;
                  int? intervalToStart;
                  if (isCardio) {
                    final dist =
                        double.tryParse(distanceController.text) ?? 0;
                    final dur =
                        int.tryParse(durationController.text) ?? 0;
                    if (isEdit) {
                      notifier.updateLog(existingLog.copyWith(
                        exerciseName: exerciseName,
                        exerciseType: exerciseType,
                        weight: 0,
                        reps: 0,
                        sets: 0,
                        interval: 0,
                        distanceKm: dist,
                        durationMinutes: dur,
                        note: noteController.text,
                      ));
                    } else {
                      notifier.addLog(
                        exerciseName: exerciseName,
                        exerciseType: exerciseType,
                        weight: 0,
                        reps: 0,
                        sets: 0,
                        interval: 0,
                        distanceKm: dist,
                        durationMinutes: dur,
                        note: noteController.text,
                      );
                    }
                  } else {
                    final w = double.tryParse(weightController.text) ?? 0;
                    final r = int.tryParse(repsController.text) ?? 0;
                    final s = int.tryParse(setsController.text) ?? 0;
                    final iv = int.tryParse(intervalController.text) ?? 0;
                    if (isEdit) {
                      notifier.updateLog(existingLog.copyWith(
                        exerciseName: exerciseName,
                        exerciseType: exerciseType,
                        weight: w,
                        reps: r,
                        sets: s,
                        interval: iv,
                        distanceKm: 0,
                        durationMinutes: 0,
                        note: noteController.text,
                      ));
                    } else {
                      notifier.addLog(
                        exerciseName: exerciseName,
                        exerciseType: exerciseType,
                        weight: w,
                        reps: r,
                        sets: s,
                        interval: iv,
                        note: noteController.text,
                      );
                      if (iv > 0) intervalToStart = iv;
                    }
                  }
                  Navigator.pop(context);
                  if (intervalToStart != null) {
                    _startIntervalTimer(intervalToStart);
                  }
                },
                child: Text(isEdit ? '保存' : '記録'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildOneRmCard(TrainingState state) {
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
            const Row(
              children: [
                Icon(Icons.emoji_events, color: Colors.amber, size: 18),
                SizedBox(width: 6),
                Text(
                  '推定1RM（エプリー式）',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
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
                          .withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          e.key,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${e.value.toStringAsFixed(1)} kg',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 4),
            const Text(
              'タップで重量推移グラフを表示',
              style: TextStyle(fontSize: 10, color: Colors.grey),
            ),
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
                      backgroundColor: Colors.grey.withValues(alpha: 0.2),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isDone ? Colors.green : Colors.teal,
                      ),
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
                        color: isDone ? Colors.green : null,
                      ),
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
                onPressed: _stopIntervalTimer,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _exerciseTypeHint(ExerciseType type) {
    switch (type) {
      case ExerciseType.freeWeight:
        return 'バーベル・ダンベル等。実際に持ち上げる重量を入力してください。';
      case ExerciseType.machine:
        return 'ケーブル・マシン等。スタック重量を入力してください。';
      case ExerciseType.bodyweight:
        return '体重を利用する種目。追加ウェイトがあれば入力（なければ0）。';
      case ExerciseType.cardio:
        return '器具不要の有酸素運動。距離と時間を入力してください。';
    }
  }
}

// ── Training log card ──────────────────────────────────────────────────────

class _TrainingLogCard extends StatefulWidget {
  final TrainingLog log;
  final bool isPr;
  final double estimatedKcal;
  final double bodyWeightKg;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onIntervalTimer;
  final bool showAiAdvice;
  final bool aiLoading;
  final String? aiAdvice;
  final String? aiError;
  final VoidCallback? onRequestAiAdvice;

  const _TrainingLogCard({
    required this.log,
    required this.isPr,
    required this.estimatedKcal,
    required this.bodyWeightKg,
    required this.onEdit,
    required this.onDelete,
    this.onIntervalTimer,
    this.showAiAdvice = false,
    this.aiLoading = false,
    this.aiAdvice,
    this.aiError,
    this.onRequestAiAdvice,
  });

  @override
  State<_TrainingLogCard> createState() => _TrainingLogCardState();
}

class _TrainingLogCardState extends State<_TrainingLogCard> {
  bool _adviceExpanded = false;

  @override
  void didUpdateWidget(_TrainingLogCard old) {
    super.didUpdateWidget(old);
    // 新たに解析結果が届いたら自動展開
    if (old.aiAdvice == null && widget.aiAdvice != null) {
      setState(() => _adviceExpanded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final log = widget.log;
    final isPr = widget.isPr;
    final estimatedKcal = widget.estimatedKcal;
    final onEdit = widget.onEdit;
    final onDelete = widget.onDelete;
    final onIntervalTimer = widget.onIntervalTimer;
    final showAiAdvice = widget.showAiAdvice;
    final aiLoading = widget.aiLoading;
    final aiAdvice = widget.aiAdvice;
    final aiError = widget.aiError;
    final onRequestAiAdvice = widget.onRequestAiAdvice;
    final isCardio = log.exerciseType == ExerciseType.cardio;
    final oneRm =
        isCardio ? 0.0 : TrainingNotifier.oneRepMax(log.weight, log.reps);
    final volumeLabel = log.totalVolume >= 1000
        ? '${(log.totalVolume / 1000).toStringAsFixed(1)} t'
        : '${log.totalVolume.round()} kg';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            onTap: onEdit,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              // ── Header ──────────────────────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Exercise type badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _typeColor(log.exerciseType)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      log.exerciseType.label,
                      style: TextStyle(
                          fontSize: 10,
                          color: _typeColor(log.exerciseType),
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      log.exerciseName,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                  if (isPr)
                    const Tooltip(
                      message: '自己ベスト（最大重量）更新！',
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.emoji_events,
                              color: Colors.amber, size: 18),
                          SizedBox(width: 2),
                          Text('PR',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.amber,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  if (onIntervalTimer != null)
                    IconButton(
                      icon: const Icon(Icons.timer_outlined,
                          color: Colors.teal, size: 22),
                      tooltip: 'インターバルタイマー開始',
                      onPressed: onIntervalTimer,
                    ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 20),
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                          value: 'edit',
                          child: Row(children: [
                            Icon(Icons.edit, size: 18),
                            SizedBox(width: 8),
                            Text('編集')
                          ])),
                      const PopupMenuItem(
                          value: 'delete',
                          child: Row(children: [
                            Icon(Icons.delete_outline,
                                size: 18, color: Colors.red),
                            SizedBox(width: 8),
                            Text('削除',
                                style: TextStyle(color: Colors.red))
                          ])),
                    ],
                    onSelected: (v) {
                      if (v == 'edit') onEdit();
                      if (v == 'delete') onDelete();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // ── Main metrics ────────────────────────────────────────
              if (isCardio)
                Wrap(
                  spacing: 16,
                  runSpacing: 4,
                  children: [
                    if (log.distanceKm > 0)
                      _metricText(
                          '${log.distanceKm.toStringAsFixed(2)} km', '距離'),
                    if (log.durationMinutes > 0)
                      _metricText('${log.durationMinutes} 分', '時間'),
                    if (log.paceMinPerKm != null)
                      _metricText(
                          _formatPace(log.paceMinPerKm!), 'ペース/km'),
                  ],
                )
              else
                Wrap(
                  spacing: 16,
                  runSpacing: 4,
                  children: [
                    _metricText(
                      log.exerciseType == ExerciseType.bodyweight &&
                              log.weight == 0
                          ? '自体重'
                          : '${log.weight} kg',
                      '重量',
                    ),
                    _metricText('${log.reps} 回', '回数'),
                    _metricText('${log.sets} set', 'セット'),
                    if (log.interval > 0)
                      _metricText('${log.interval} 秒', 'インターバル'),
                  ],
                ),
              const SizedBox(height: 8),

              // ── Derived metrics ─────────────────────────────────────
              Row(
                children: [
                  _statChip(Icons.local_fire_department,
                      '${estimatedKcal.round()} kcal', Colors.deepOrange,
                      tooltip: '消費カロリー目安'),
                  if (!isCardio && log.totalVolume > 0) ...[
                    const SizedBox(width: 8),
                    _statChip(Icons.stacked_bar_chart, volumeLabel,
                        Colors.indigo,
                        tooltip: '総ボリューム (重量×回数×セット)'),
                  ],
                  if (oneRm > 0) ...[
                    const SizedBox(width: 8),
                    _statChip(Icons.speed, '1RM≈${oneRm.round()} kg',
                        Colors.teal,
                        tooltip: 'Epley式 推定1RM'),
                  ],
                ],
              ),

              if (log.note.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.notes, size: 13, color: Colors.grey),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(log.note,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey)),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 4),
              Text(
                DateFormat('yyyy/MM/dd HH:mm').format(log.date),
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
                ],
              ),
            ),
          ),
          if (showAiAdvice && onRequestAiAdvice != null)
            _buildAiAdviceSection(
              context,
              aiAdvice: aiAdvice,
              aiLoading: aiLoading,
              aiError: aiError,
              onRequestAiAdvice: onRequestAiAdvice,
            ),
        ],
      ),
    );
  }

  Widget _buildAiAdviceSection(
    BuildContext context, {
    required String? aiAdvice,
    required bool aiLoading,
    required String? aiError,
    required VoidCallback onRequestAiAdvice,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 8, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1),
          const SizedBox(height: 4),

          // ── 評価済みの場合: 折り畳みヘッダー ──
          if (aiAdvice != null) ...[
            InkWell(
              onTap: () => setState(() => _adviceExpanded = !_adviceExpanded),
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    const Icon(Icons.psychology, size: 18, color: Colors.teal),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text(
                        'AI評価済み',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.teal,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Icon(
                      _adviceExpanded
                          ? Icons.expand_less
                          : Icons.expand_more,
                      size: 20,
                      color: Colors.teal,
                    ),
                  ],
                ),
              ),
            ),
            if (_adviceExpanded) ...[
              const SizedBox(height: 6),
              MarkdownBody(
                data: aiAdvice,
                // 長い番号付きリストでも高さ計算が安定する（baseline だとスクロール内で欠けることがある）
                listItemCrossAxisAlignment:
                    MarkdownListItemCrossAxisAlignment.start,
                styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                  p: const TextStyle(fontSize: 13, height: 1.6),
                  h3: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    height: 1.8,
                  ),
                  strong: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                  horizontalRuleDecoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: Colors.grey.shade300, width: 1),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: aiLoading ? null : onRequestAiAdvice,
                icon: aiLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh, size: 18),
                label: const Text('再評価', style: TextStyle(fontSize: 13)),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  foregroundColor: Colors.grey[600],
                ),
              ),
            ],
          ],

          // ── 未評価の場合: 評価ボタン ──
          if (aiAdvice == null) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: aiLoading ? null : onRequestAiAdvice,
                icon: aiLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.psychology_outlined, size: 20),
                label: const Text(
                  'この記録をAI評価',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ),
          ],

          if (aiError != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                aiError,
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  /// ペース表示: 5.5 → "5:30/km"
  String _formatPace(double minPerKm) {
    final min = minPerKm.floor();
    final sec = ((minPerKm - min) * 60).round();
    return '$min:${sec.toString().padLeft(2, '0')}/km';
  }

  Widget _metricText(String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 15)),
        Text(label,
            style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }

  Widget _statChip(IconData icon, String label, Color color,
      {required String tooltip}) {
    return Tooltip(
      message: tooltip,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    color: color,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Color _typeColor(ExerciseType type) {
    switch (type) {
      case ExerciseType.freeWeight:
        return Colors.deepOrange;
      case ExerciseType.machine:
        return Colors.blue;
      case ExerciseType.bodyweight:
        return Colors.green;
      case ExerciseType.cardio:
        return Colors.teal;
    }
  }
}

// ── Calorie preview chip (inside dialog) ──────────────────────────────────

class _CaloriePreviewChip extends StatelessWidget {
  final double kcal;
  final bool isCardio;
  final double weight;
  final int reps;
  final int sets;
  final ExerciseType exerciseType;
  final double distanceKm;
  final int durationMinutes;

  const _CaloriePreviewChip({
    required this.kcal,
    required this.isCardio,
    required this.weight,
    required this.reps,
    required this.sets,
    required this.exerciseType,
    required this.distanceKm,
    required this.durationMinutes,
  });

  @override
  Widget build(BuildContext context) {
    final volume = weight * reps * sets;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.deepOrange.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.deepOrange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_fire_department,
                  color: Colors.deepOrange, size: 18),
              const SizedBox(width: 6),
              Text(
                '推定消費カロリー: ${kcal.round()} kcal',
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.deepOrange,
                    fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (isCardio && distanceKm > 0 && durationMinutes > 0)
            Text(
              'ペース: ${_formatPace(durationMinutes / distanceKm)}  ／  距離: ${distanceKm.toStringAsFixed(2)} km',
              style: TextStyle(fontSize: 12, color: Colors.orange.shade800),
            )
          else if (!isCardio && volume > 0)
            Text(
              'ボリューム: ${volume.round()} kg  ／  1RM (Epley): ≈${TrainingNotifier.oneRepMax(weight, reps).round()} kg',
              style: TextStyle(fontSize: 12, color: Colors.orange.shade800),
            ),
          const SizedBox(height: 2),
          Text(
            isCardio
                ? '※ MET法（運動強度×体重×時間）による目安値です。'
                : '※ MET法＋挙上量ベースの目安値です。実際の消費カロリーは個人差があります。',
            style: TextStyle(fontSize: 10, color: Colors.orange.shade700),
          ),
        ],
      ),
    );
  }

  String _formatPace(double minPerKm) {
    final min = minPerKm.floor();
    final sec = ((minPerKm - min) * 60).round();
    return '$min:${sec.toString().padLeft(2, '0')}/km';
  }
}
