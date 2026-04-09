import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/active_workout_provider.dart';
import '../providers/training_provider.dart';

class ActiveWorkoutScreen extends ConsumerStatefulWidget {
  const ActiveWorkoutScreen({super.key});

  @override
  ConsumerState<ActiveWorkoutScreen> createState() =>
      _ActiveWorkoutScreenState();
}

class _ActiveWorkoutScreenState extends ConsumerState<ActiveWorkoutScreen> {
  final _weightController = TextEditingController();
  final _repsController = TextEditingController();
  final _noteController = TextEditingController();
  int _rpe = 7;

  // インターバルタイマー
  Timer? _timer;
  int _timerSeconds = 0;
  bool _timerRunning = false;
  int _timerTotal = 0;

  @override
  void initState() {
    super.initState();
    _syncFieldsFromSession();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _weightController.dispose();
    _repsController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _syncFieldsFromSession() {
    final session = ref.read(activeWorkoutProvider).session;
    if (session == null) return;
    final exercise = session.currentExercise;
    if (exercise == null) return;
    _weightController.text = exercise.suggestedWeight > 0
        ? exercise.suggestedWeight.toStringAsFixed(
            exercise.suggestedWeight % 1 == 0 ? 0 : 1)
        : '';
    _repsController.text = exercise.suggestedReps.toString();
    _noteController.clear();
    setState(() => _rpe = 7);
  }

  void _startTimer(int seconds) {
    _timer?.cancel();
    setState(() {
      _timerTotal = seconds;
      _timerSeconds = seconds;
      _timerRunning = true;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
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

  void _confirmSet() {
    final weight = double.tryParse(_weightController.text) ?? 0;
    final reps = int.tryParse(_repsController.text) ?? 0;
    if (reps <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('レップ数を入力してください')),
      );
      return;
    }

    final session = ref.read(activeWorkoutProvider).session;
    final exercise = session?.currentExercise;

    ref.read(activeWorkoutProvider.notifier).confirmSet(
          weight: weight,
          reps: reps,
          rpe: _rpe,
          note: _noteController.text.trim(),
        );

    // インターバルタイマー開始
    if (exercise != null && exercise.intervalSeconds > 0) {
      _startTimer(exercise.intervalSeconds);
    }

    // 次のセットのフィールドを更新
    _syncFieldsFromSession();
  }

  Future<void> _finishWorkout() async {
    final logs = ref.read(activeWorkoutProvider.notifier).finishSession();
    if (logs.isNotEmpty) {
      await ref.read(trainingProvider.notifier).bulkAddLogs(logs);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('${logs.length}セットを保存しました！お疲れ様でした！')),
        );
      }
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<bool> _onWillPop() async {
    final session = ref.read(activeWorkoutProvider).session;
    if (session == null || session.completedLogs.isEmpty) return true;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ワークアウトを中断しますか？'),
        content: Text(
            'まだ ${session.completedLogs.length} セット記録されています。\n保存して終了しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('続ける'),
          ),
          TextButton(
            onPressed: () {
              ref.read(activeWorkoutProvider.notifier).abandonSession();
              Navigator.pop(ctx, true);
            },
            child: const Text('破棄して終了'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('保存して終了'),
          ),
        ],
      ),
    );

    if (result == true) {
      await _finishWorkout();
      return false; // _finishWorkout が pop する
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final workoutState = ref.watch(activeWorkoutProvider);
    final session = workoutState.session;
    final scheme = Theme.of(context).colorScheme;

    if (session == null || session.isFinished) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _finishWorkout();
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final exercise = session.currentExercise!;
    final totalExercises = session.exercises.length;
    final currentExerciseIndex = session.currentExerciseIndex;
    final currentSet = session.currentSet;
    final totalSets = exercise.targetSets;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) await _onWillPop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('セッション ${currentExerciseIndex + 1}/$totalExercises'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: _onWillPop,
          ),
          actions: [
            FilledButton(
              onPressed: _finishWorkout,
              child: const Text('終了'),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Column(
          children: [
            // 全体進捗バー
            LinearProgressIndicator(
              value: (currentExerciseIndex + (currentSet - 1) / totalSets) /
                  totalExercises,
              minHeight: 4,
              backgroundColor: scheme.surfaceContainerHighest,
              color: scheme.primary,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // エクササイズ名
                    Text(
                      exercise.name,
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'セット $currentSet / $totalSets',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: scheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 16),

                    // インターバルタイマー
                    if (_timerRunning || _timerSeconds > 0) ...[
                      _buildTimerSection(scheme),
                      const SizedBox(height: 16),
                    ],

                    // 重量・レップ入力
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _weightController,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: const InputDecoration(
                              labelText: '重量',
                              suffixText: 'kg',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _repsController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'レップ数',
                              suffixText: 'rep',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // RPE スライダー
                    Text('RPE: $_rpe / 10',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    Slider(
                      value: _rpe.toDouble(),
                      min: 1,
                      max: 10,
                      divisions: 9,
                      label: _rpe.toString(),
                      onChanged: (v) => setState(() => _rpe = v.round()),
                    ),
                    const SizedBox(height: 8),

                    // メモ
                    TextField(
                      controller: _noteController,
                      decoration: const InputDecoration(
                        labelText: 'メモ（任意）',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // セット完了ボタン
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        icon: const Icon(Icons.check_rounded),
                        label: currentSet < totalSets
                            ? Text('セット $currentSet 完了')
                            : Text('${exercise.name} 完了'),
                        onPressed: _confirmSet,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // スキップボタン
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () {
                          ref
                              .read(activeWorkoutProvider.notifier)
                              .skipExercise();
                          _syncFieldsFromSession();
                        },
                        child: const Text('このエクササイズをスキップ'),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 完了済みセット
                    if (session.completedLogs.isNotEmpty) ...[
                      const Divider(),
                      const SizedBox(height: 8),
                      Text('完了したセット',
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      for (final log in session.completedLogs.reversed)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle_outline_rounded,
                                  size: 16, color: Colors.green),
                              const SizedBox(width: 8),
                              Text('${log.exerciseName}: '
                                  '${log.weight > 0 ? '${log.weight}kg × ' : ''}'
                                  '${log.reps}rep'),
                            ],
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimerSection(ColorScheme scheme) {
    final progress =
        _timerTotal > 0 ? (_timerTotal - _timerSeconds) / _timerTotal : 0.0;
    final minutes = _timerSeconds ~/ 60;
    final seconds = _timerSeconds % 60;

    return Card(
      color: scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.timer_rounded,
                color: scheme.onSecondaryContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'インターバル: '
                    '${minutes > 0 ? '$minutes分' : ''}$seconds秒',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: scheme.onSecondaryContainer,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress.clamp(0.0, 1.0),
                      minHeight: 6,
                      backgroundColor:
                          scheme.secondary.withValues(alpha: 0.2),
                      color: scheme.secondary,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: _stopTimer,
              color: scheme.onSecondaryContainer,
            ),
          ],
        ),
      ),
    );
  }
}
