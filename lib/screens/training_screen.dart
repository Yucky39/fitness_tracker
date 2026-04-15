import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/exercise_muscle_map.dart';
import '../models/training_log.dart';
import '../providers/active_workout_provider.dart';
import '../providers/energy_profile_provider.dart';
import '../providers/muscle_heatmap_provider.dart';
import '../providers/routine_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/sleep_provider.dart';
import '../providers/training_advice_provider.dart';
import '../providers/training_daily_advice_provider.dart';
import '../providers/training_provider.dart';
import '../services/health_service.dart';
import '../services/training_calorie_calculator.dart';
import '../widgets/muscle_heatmap_painter.dart';
import '../widgets/training/exercise_weight_chart_sheet.dart';
import '../widgets/training/training_log_card.dart';
import '../widgets/training/training_log_dialog.dart';
import '../widgets/training/training_one_rm_card.dart';
import '../widgets/training/training_today_summary.dart';
import '../widgets/training/training_timer_overlay.dart';
import 'active_workout_screen.dart';
import 'review_screen.dart';
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

  void _startSession(dynamic routine, List<TrainingLog> allLogs) {
    ref.read(activeWorkoutProvider.notifier).startSession(
          routine: routine,
          allLogs: allLogs,
        );
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ActiveWorkoutScreen()),
    );
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
    final routineState = ref.watch(routineProvider);
    final effectiveBw = bodyWeightKg > 0
        ? bodyWeightKg
        : TrainingCalorieCalculator.defaultBodyWeightKg;

    final today = DateTime.now();
    final selectedDate = trainingState.selectedDate;
    final isToday = selectedDate.year == today.year &&
        selectedDate.month == today.month &&
        selectedDate.day == today.day;

    // 今日のルーティンでメモに種目が書かれているものを探す
    final todaysRoutines = routineState.routines
        .where((r) => r.weekdays.contains(DateTime.now().weekday))
        .where((r) => r.note.trim().isNotEmpty)
        .toList();

    final selectedDateLogs = trainingState.selectedDateLogs;

    Widget bodyChild;
    if (trainingState.isLoading) {
      bodyChild = const Center(child: CircularProgressIndicator());
    } else {
      bodyChild = _buildBody(
        context,
        ref,
        trainingState,
        trainingNotifier,
        effectiveBw,
        settings,
        sleepState,
        selectedDateLogs,
        isToday,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('トレーニング記録'),
        actions: [
          if (isToday && todaysRoutines.isNotEmpty)
            FilledButton.tonal(
              onPressed: () => _startSession(todaysRoutines.first, trainingState.logs),
              child: const Text('セッション開始'),
            ),
          if (HealthService.isSupported)
            IconButton(
              icon: const Icon(Icons.sync),
              tooltip: 'ヘルスケアからワークアウトを取り込む',
              onPressed: _manualImportFromHealth,
            ),
          IconButton(
            icon: const Icon(Icons.bar_chart_rounded),
            tooltip: '振り返り（週間・月間）',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const ReviewScreen(),
              ),
            ),
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
    List<TrainingLog> selectedDateLogs,
    bool isToday,
  ) {
    final adviceState = ref.watch(trainingAdviceProvider);
    final heatmap = ref.watch(muscleHeatmapProvider);

    return CustomScrollView(
      slivers: [
        // ── 日付ナビゲーション
        SliverToBoxAdapter(
          child: _DateNavigation(
            selectedDate: state.selectedDate,
            onChangeDate: (d) => notifier.changeDate(d),
          ),
        ),

        // ── セッションサマリー（選択日にログがある場合）
        if (selectedDateLogs.isNotEmpty)
          SliverToBoxAdapter(
            child: TrainingTodaySummary(
              todayLogs: selectedDateLogs,
              bodyWeightKg: bodyWeightKg,
              date: state.selectedDate,
            ),
          ),

        // ── デイリーAIアドバイスカード（選択日）
        if (settings.trainingAdviceEnabled && selectedDateLogs.isNotEmpty)
          SliverToBoxAdapter(
            child: _DailyAdviceCard(
              selectedDate: state.selectedDate,
              dayLogs: selectedDateLogs,
              allLogs: state.logs,
              sleepContext: sleepState.adviceContext,
            ),
          ),

        // ── 記録なし（選択日）
        if (selectedDateLogs.isEmpty)
          SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
                child: Text(
                  isToday
                      ? (HealthService.isSupported
                          ? 'まだ今日の記録がありません\n右下の + ボタンで追加できます\n\nAppleヘルスやHealth Connectにワークアウトがある場合は、右上の同期ボタンから取り込めます'
                          : 'まだ今日の記録がありません\n右下の + ボタンで追加できます')
                      : 'この日のトレーニング記録はありません',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
            ),
          ),

        // ── 筋肉ヒートマップ（過去7日間、常に表示）
        SliverToBoxAdapter(
          child: _MuscleHeatmapCard(heatmap: heatmap),
        ),

        // ── 1RM カード（全記録ベース）
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

        // ── 選択日のログ一覧
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final log = selectedDateLogs[index];
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
            childCount: selectedDateLogs.length,
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ],
    );
  }
}

// ── 日付ナビゲーション ───────────────────────────────────────────────────────

class _DateNavigation extends StatelessWidget {
  final DateTime selectedDate;
  final void Function(DateTime) onChangeDate;

  const _DateNavigation({
    required this.selectedDate,
    required this.onChangeDate,
  });

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final isToday = selectedDate.year == today.year &&
        selectedDate.month == today.month &&
        selectedDate.day == today.day;

    String dateLabel;
    if (isToday) {
      dateLabel = '今日 (${DateFormat('M/d').format(selectedDate)})';
    } else {
      final yesterday = DateTime(today.year, today.month, today.day - 1);
      final isYesterday = selectedDate.year == yesterday.year &&
          selectedDate.month == yesterday.month &&
          selectedDate.day == yesterday.day;
      dateLabel = isYesterday
          ? '昨日 (${DateFormat('M/d').format(selectedDate)})'
          : DateFormat('yyyy/M/d').format(selectedDate);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => onChangeDate(
              selectedDate.subtract(const Duration(days: 1)),
            ),
          ),
          TextButton(
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: selectedDate,
                firstDate: DateTime(2020),
                lastDate: today,
              );
              if (picked != null) onChangeDate(picked);
            },
            child: Text(
              dateLabel,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: isToday
                ? null
                : () => onChangeDate(
                      selectedDate.add(const Duration(days: 1)),
                    ),
          ),
        ],
      ),
    );
  }
}

// ── デイリーAIアドバイスカード ─────────────────────────────────────────────

class _DailyAdviceCard extends ConsumerWidget {
  final DateTime selectedDate;
  final List<TrainingLog> dayLogs;
  final List<TrainingLog> allLogs;
  final String? sleepContext;

  const _DailyAdviceCard({
    required this.selectedDate,
    required this.dayLogs,
    required this.allLogs,
    this.sleepContext,
  });

  static String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final dailyAdviceState = ref.watch(trainingDailyAdviceProvider);
    final key = _dateKey(selectedDate);

    final isLoading = dailyAdviceState.isLoading && dailyAdviceState.loadingDateKey == key;
    final adviceText = dailyAdviceState.adviceByDate[key];
    final error = dailyAdviceState.loadingDateKey == null && dailyAdviceState.error != null
        ? dailyAdviceState.error
        : null;

    void fetch({bool force = false}) {
      ref.read(trainingDailyAdviceProvider.notifier).fetchDailyAdvice(
        dayLogs: dayLogs,
        allLogs: allLogs,
        date: selectedDate,
        adviceLevel: settings.adviceLevel,
        apiKey: settings.currentApiKey,
        provider: settings.selectedProvider,
        model: settings.currentModel,
        sleepContext: sleepContext,
        forceRefresh: force,
      );
    }

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome, size: 16, color: Colors.deepOrange),
                const SizedBox(width: 6),
                const Text(
                  'AI デイリーアドバイス',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const Spacer(),
                if (adviceText != null && !isLoading)
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 16),
                    tooltip: '再取得',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => fetch(force: true),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else if (error != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(error, style: const TextStyle(color: Colors.red, fontSize: 13)),
                  const SizedBox(height: 6),
                  OutlinedButton.icon(
                    onPressed: () => fetch(),
                    icon: const Icon(Icons.refresh, size: 14),
                    label: const Text('再試行'),
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              )
            else if (adviceText != null)
              Text(adviceText, style: const TextStyle(fontSize: 13, height: 1.6))
            else
              FilledButton.icon(
                onPressed: () => fetch(),
                icon: const Icon(Icons.auto_awesome, size: 14),
                label: const Text('今日のセッション全体を AI 評価'),
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── 筋肉ヒートマップカード ─────────────────────────────────────────────────

/// 折りたたみ可能な筋肉部位ヒートマップカード
class _MuscleHeatmapCard extends StatefulWidget {
  const _MuscleHeatmapCard({required this.heatmap});
  final Map<MuscleGroup, double> heatmap;

  @override
  State<_MuscleHeatmapCard> createState() => _MuscleHeatmapCardState();
}

class _MuscleHeatmapCardState extends State<_MuscleHeatmapCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.accessibility_new, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      '筋肉部位ヒートマップ（過去7日間）',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: MuscleHeatmapWidget(heatmap: widget.heatmap),
            ),
        ],
      ),
    );
  }
}
