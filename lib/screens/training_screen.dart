import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/exercise_muscle_map.dart';
import '../models/training_log.dart';
import '../models/training_session_record.dart';
import '../providers/active_workout_provider.dart';
import '../providers/energy_profile_provider.dart';
import '../providers/muscle_heatmap_provider.dart';
import '../providers/routine_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/sleep_provider.dart';
import '../providers/training_advice_provider.dart';
import '../providers/training_daily_advice_provider.dart';
import '../providers/training_provider.dart';
import '../providers/training_session_provider.dart';
import '../services/health_service.dart';
import '../services/training_calorie_calculator.dart';
import '../services/ai_exceptions.dart';
import '../widgets/ai_error_text.dart';
import '../widgets/ai_limit_banner.dart';
import '../widgets/muscle_heatmap_painter.dart';
import '../widgets/muscle_rest_card.dart';
import '../widgets/training/exercise_weight_chart_sheet.dart';
import '../widgets/training/session_record_card.dart';
import '../widgets/training/session_registration_dialog.dart';
import '../widgets/training/training_log_card.dart';
import '../widgets/training/training_log_dialog.dart';
import '../widgets/training/training_one_rm_card.dart';
import '../widgets/training/training_today_summary.dart';
import '../widgets/training/training_timer_overlay.dart';
import '../widgets/register_home_fab.dart';
import '../providers/home_fab_provider.dart';
import '../theme/app_tokens.dart';
import '../theme/bewell_colors.dart';
import '../widgets/source_reference_link.dart';
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

    final today = DateTime.now();
    final selectedDate = trainingState.selectedDate;
    final isToday = selectedDate.year == today.year &&
        selectedDate.month == today.month &&
        selectedDate.day == today.day;

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

    return RegisterHomeFab(
      tabIndex: 2,
      config: HomeFabConfig(
        tooltip: 'トレーニングを記録',
        onPressed: () => _openTrainingDialog(
          notifier: trainingNotifier,
          bodyWeightKg: effectiveBw,
        ),
      ),
      child: Stack(
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
    final sessionState = ref.watch(trainingSessionProvider);
    final sessionsForDate =
        sessionState.sessionsForDate(state.selectedDate);

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
              sleepContext: sleepState.adviceContextForDate(state.selectedDate),
            ),
          ),

        // ── 記録なし（選択日）
        if (selectedDateLogs.isEmpty)
          SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
                child: Text(
                  isToday
                      ? (HealthService.isSupported
                          ? 'まだ今日の記録がありません\n右下の + ボタンで追加できます\n\nAppleヘルスやHealth Connectにワークアウトがある場合は、右上の同期ボタンから取り込めます'
                          : 'まだ今日の記録がありません\n右下の + ボタンで追加できます')
                      : 'この日のトレーニング記録はありません',
                  textAlign: TextAlign.center,
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ),
            ),
          ),

        // ── 筋肉ヒートマップ（過去7日間、常に表示）
        SliverToBoxAdapter(
          child: _MuscleHeatmapCard(heatmap: heatmap),
        ),

        // ── 部位ごとの休息状況（推奨休息日数に対する回復進捗）
        const SliverToBoxAdapter(
          child: MuscleRestCard(),
        ),

        // ── 1RM カード（選択日のセッションベース。タップ時の推移グラフは全記録から表示）
        SliverToBoxAdapter(
          child: TrainingOneRmCard(
            logs: selectedDateLogs,
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
                          sleepContext:
                              sleepState.adviceContextForDate(log.date),
                        )
                    : null,
              );
            },
            childCount: selectedDateLogs.length,
          ),
        ),
        // ── セッション登録セクション
        SliverToBoxAdapter(
          child: _SessionSection(
            selectedDate: state.selectedDate,
            dayLogs: selectedDateLogs,
            sessions: sessionsForDate,
            allLogs: state.logs,
            sessionState: sessionState,
          ),
        ),

        const SliverToBoxAdapter(
            child: SizedBox(height: AppSpacing.bottomNavClearance)),
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

// ── セッション登録セクション ─────────────────────────────────────────────────

class _SessionSection extends ConsumerWidget {
  final DateTime selectedDate;
  final List<TrainingLog> dayLogs;
  final List<TrainingSessionRecord> sessions;
  final List<TrainingLog> allLogs;
  final TrainingSessionState sessionState;

  const _SessionSection({
    required this.selectedDate,
    required this.dayLogs,
    required this.sessions,
    required this.allLogs,
    required this.sessionState,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── セクションヘッダー
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 4),
          child: Row(
            children: [
              Icon(
                Icons.self_improvement,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                'セッション記録',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: dayLogs.isEmpty
                    ? null
                    : () => showSessionRegistrationDialog(
                          context: context,
                          ref: ref,
                          dayLogs: dayLogs,
                          sessionDate: selectedDate,
                        ),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('登録'),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        ),

        // ── セッションカード一覧
        if (sessions.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(
              dayLogs.isEmpty
                  ? 'トレーニングを記録してからセッションを登録できます'
                  : '「登録」ボタンでセッションをまとめてストレッチを確認できます',
              style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          )
        else
          ...sessions.map((session) {
            final sessionLogs = allLogs
                .where((l) => session.logIds.contains(l.id))
                .toList();
            final isLoading =
                sessionState.fetchingStretchForId == session.id;
            final error = sessionState.stretchErrorById[session.id];

            return SessionRecordCard(
              session: session,
              sessionLogs: sessionLogs,
              isStretchLoading: isLoading,
              stretchError: error,
              onRetryStretch: () => ref
                  .read(trainingSessionProvider.notifier)
                  .retryStretch(session, allLogs),
              onDelete: () => ref
                  .read(trainingSessionProvider.notifier)
                  .deleteSession(session.id),
            );
          }),
      ],
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

    final isLoading =
        dailyAdviceState.isLoading && dailyAdviceState.loadingDateKey == key;
    final adviceText = dailyAdviceState.adviceByDate[key];
    final error =
        dailyAdviceState.errorDateKey == key ? dailyAdviceState.error : null;

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
                Icon(Icons.auto_awesome,
                    size: 16, color: context.bewellColors.aiAccent),
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
                  if (AiUsageLimitException.isLimit(error)) ...[
                    AiLimitBanner(error: error),
                  ] else if (isPaywallError(error)) ...[
                    AiErrorText(error),
                  ] else ...[
                    Text(error,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontSize: 13)),
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
                ],
              )
            else if (adviceText != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(adviceText,
                      style: const TextStyle(fontSize: 13, height: 1.6)),
                  const SizedBox(height: 4),
                  const SourceReferenceLink(compact: true),
                ],
              )
            else
              FilledButton.icon(
                onPressed: () => fetch(),
                icon: const Icon(Icons.auto_awesome, size: 14),
                label: const Text('この日のセッション全体を AI 評価'),
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

/// [HomeScreen] の AppBar に表示するトレーニングタブ用アクション。
class TrainingAppBarActions extends ConsumerWidget {
  const TrainingAppBarActions({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trainingState = ref.watch(trainingProvider);
    final routineState = ref.watch(routineProvider);

    final today = DateTime.now();
    final isToday = trainingState.selectedDate.year == today.year &&
        trainingState.selectedDate.month == today.month &&
        trainingState.selectedDate.day == today.day;

    final todaysRoutines = routineState.routines
        .where((r) => r.weekdays.contains(DateTime.now().weekday))
        .toList();

    Future<void> manualImport() async {
      if (!HealthService.isSupported) return;
      final n =
          await ref.read(trainingProvider.notifier).syncWorkoutsFromHealth();
      if (!context.mounted) return;
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

    void startSession() {
      ref.read(activeWorkoutProvider.notifier).startSession(
            routine: todaysRoutines.first,
            allLogs: trainingState.logs,
          );
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ActiveWorkoutScreen()),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isToday && todaysRoutines.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: FilledButton.tonal(
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 36),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: startSession,
              child: const Text('開始', style: TextStyle(fontSize: 13)),
            ),
          ),
        PopupMenuButton<_TrainingMenuAction>(
          tooltip: 'その他',
          icon: const Icon(Icons.more_vert),
          onSelected: (action) {
            switch (action) {
              case _TrainingMenuAction.sync:
                manualImport();
              case _TrainingMenuAction.review:
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(builder: (_) => const ReviewScreen()),
                );
              case _TrainingMenuAction.aiPlan:
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const TrainingPlanScreen(),
                  ),
                );
              case _TrainingMenuAction.routine:
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const RoutineScreen(),
                  ),
                );
            }
          },
          itemBuilder: (context) => [
            if (HealthService.isSupported)
              const PopupMenuItem(
                value: _TrainingMenuAction.sync,
                child: ListTile(
                  leading: Icon(Icons.sync),
                  title: Text('ヘルスケアから取り込む'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            const PopupMenuItem(
              value: _TrainingMenuAction.review,
              child: ListTile(
                leading: Icon(Icons.bar_chart_rounded),
                title: Text('振り返り'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: _TrainingMenuAction.aiPlan,
              child: ListTile(
                leading: Icon(Icons.auto_awesome),
                title: Text('AIプラン作成'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: _TrainingMenuAction.routine,
              child: ListTile(
                leading: Icon(Icons.calendar_month),
                title: Text('ルーティン管理'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

enum _TrainingMenuAction { sync, review, aiPlan, routine }
