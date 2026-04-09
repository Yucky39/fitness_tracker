import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/training_log.dart';
import '../providers/energy_profile_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/sleep_provider.dart';
import '../providers/training_advice_provider.dart';
import '../providers/training_provider.dart';
import '../services/health_service.dart';
import '../services/training_calorie_calculator.dart';
import '../widgets/training/exercise_weight_chart_sheet.dart';
import '../widgets/training/training_log_card.dart';
import '../widgets/training/training_log_dialog.dart';
import '../widgets/training/training_one_rm_card.dart';
import '../widgets/training/training_today_summary.dart';
import '../widgets/training/training_timer_overlay.dart';
import 'routine_screen.dart';
import 'training_plan_screen.dart';

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
    if (!HealthService.isSupported || !mounted) return;
    final n =
        await ref.read(trainingProvider.notifier).syncWorkoutsFromHealth();
    if (n > 0 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ヘルスケアから $n 件のワークアウトを取り込みました'),
        ),
      );
    }
  }

  Future<void> _manualImportFromHealth() async {
    if (!HealthService.isSupported) return;
    final n =
        await ref.read(trainingProvider.notifier).syncWorkoutsFromHealth();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          n > 0
              ? 'ヘルスケアから $n 件のワークアウトを取り込みました'
              : '新しいワークアウトはありませんでした（または権限・データを確認してください）',
        ),
      ),
    );
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

  void _openTrainingDialog({
    required TrainingNotifier notifier,
    required double bodyWeightKg,
    TrainingLog? existingLog,
  }) {
    showTrainingLogDialog(
      context: context,
      ref: ref,
      notifier: notifier,
      bodyWeightKg: bodyWeightKg,
      existingLog: existingLog,
      onIntervalTimerStart: _startIntervalTimer,
    );
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
      bodyChild = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            HealthService.isSupported
                ? 'まだ記録がありません\n右下の + ボタンで追加できます\n\nAppleヘルスやHealth Connectにワークアウトがある場合は、右上の同期ボタンから取り込めます'
                : 'まだ記録がありません\n右下の + ボタンで追加できます',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey),
          ),
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
          if (HealthService.isSupported)
            IconButton(
              icon: const Icon(Icons.sync),
              tooltip: 'ヘルスケアからワークアウトを取り込む',
              onPressed: _manualImportFromHealth,
            ),
          IconButton(
            icon: const Icon(Icons.auto_awesome),
            tooltip: 'AIプラン作成',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const TrainingPlanScreen(),
              ),
            ),
          ),
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
          if (_timerRunning || _timerSeconds > 0)
            TrainingTimerOverlay(
              secondsRemaining: _timerSeconds,
              totalSeconds: _timerTotal,
              onClose: _stopIntervalTimer,
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openTrainingDialog(
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
            child: TrainingTodaySummary(
              todayLogs: todayLogs,
              bodyWeightKg: bodyWeightKg,
            ),
          ),
        SliverToBoxAdapter(
          child: TrainingOneRmCard(
            logs: state.logs,
            onTapExercise: (name) => showExerciseWeightChartSheet(
              context,
              exerciseName: name,
              allLogs: state.logs,
            ),
          ),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final log = state.logs[index];
              final isPr = notifier.isPersonalRecord(log);
              final kcal = TrainingNotifier.estimateCalories(log,
                  bodyWeightKg: bodyWeightKg);

              return TrainingLogCard(
                log: log,
                isPr: isPr,
                estimatedKcal: kcal,
                bodyWeightKg: bodyWeightKg,
                onEdit: () => _openTrainingDialog(
                  notifier: notifier,
                  bodyWeightKg: bodyWeightKg,
                  existingLog: log,
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
}
