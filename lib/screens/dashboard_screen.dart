import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/period_summary.dart';
import '../providers/daily_coach_provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/energy_profile_provider.dart';
import '../providers/home_tab_provider.dart';
import '../providers/meal_provider.dart';
import '../providers/period_summary_provider.dart';
import '../providers/progress_provider.dart';
import '../providers/routine_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/achievement_provider.dart';
import '../providers/sleep_provider.dart';
import '../providers/steps_provider.dart';
import 'sleep_detail_screen.dart';
import '../models/training_routine.dart';
import '../providers/training_provider.dart';
import '../services/training_calorie_calculator.dart';
import '../widgets/coach_plan_nudge_card.dart';
import '../widgets/daily_coach_card.dart';
import '../widgets/dashboard/dashboard_collapsible_section.dart';
import '../widgets/dashboard/dashboard_section_header.dart';
import '../widgets/dashboard/wellness_summary_section.dart';
import '../widgets/micro_tap.dart';
import '../widgets/muscle_rest_card.dart';
import '../theme/app_tokens.dart';
import '../theme/bewell_colors.dart';
import 'routine_screen.dart';
import 'trainer_chat_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  static const int _tabMeal = 1;
  static const int _tabTraining = 2;
  static const int _tabProgress = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final mealState = ref.watch(mealProvider);
    final trainingState = ref.watch(trainingProvider);
    final progressState = ref.watch(progressProvider);
    final dashboardState = ref.watch(dashboardProvider);
    final routineState = ref.watch(routineProvider);
    final energy = ref.watch(energyProfileProvider);
    final settings = ref.watch(settingsProvider);
    final stepsState = ref.watch(stepsProvider);
    final achievementState = ref.watch(achievementProvider);

    final intake = dashboardState.todayCalories;
    final goal = mealState.calorieGoal;
    final bodyW = energy.weightKg;
    final trainingBurn = _todayBurn(trainingState, bodyW);
    final stepsBurn = stepsState.burnedKcal.toDouble();
    final burn = trainingBurn + stepsBurn;
    final remainingMeal = goal - intake;
    /// 摂取 − (推定消費トレ + 推定消費歩数)。運動を差し引いたあとのカロリー収支（ダイエット目線の可視化用）。
    final calorieBalance = intake - burn;

    final todaysRoutines = routineState.routines
        .where((r) => r.weekdays.contains(DateTime.now().weekday))
        .toList();

    void goTab(int i) => ref.read(homeTabIndexProvider.notifier).state = i;

    Future<void> refresh() async {
      await Future.wait([
        ref.read(dashboardProvider.notifier).loadWeeklyData(),
        ref.read(periodSummaryProvider.notifier).load(),
        ref.read(sleepProvider.notifier).syncOnDashboardVisible(),
        ref.read(stepsProvider.notifier).syncOnDashboardVisible(),
      ]);
      await ref.read(dailyCoachProvider.notifier).maybeAutoGenerate();
    }

    return ColoredBox(
      color: scheme.surface,
      child: RefreshIndicator(
        onRefresh: refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.xxl,
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  if (!achievementState.isLoading)
                    _buildStreakRow(context, achievementState),
                  _buildBalanceCard(
                    context,
                    scheme,
                    intake: intake,
                    goal: goal,
                    trainingBurn: trainingBurn,
                    stepsBurn: stepsBurn,
                    remainingMeal: remainingMeal,
                    calorieBalance: calorieBalance,
                    protein: dashboardState.todayProtein,
                    fat: dashboardState.todayFat,
                    carbs: dashboardState.todayCarbs,
                    proteinGoal: mealState.proteinGoal,
                    fatGoal: mealState.fatGoal,
                    carbsGoal: mealState.carbsGoal,
                  ),
                  const DashboardSectionHeader(
                    title: 'AIコーチ',
                    subtitle: 'あなたの記録に基づくアドバイス',
                  ),
                  const DailyCoachCard(),
                  const CoachPlanNudgeCard(),
                  const DashboardSectionHeader(
                    title: 'ウェルネス',
                    subtitle: '睡眠・歩数・水分',
                  ),
                  WellnessSummarySection(
                    onSleepDetail: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const _SleepDetailWrapper(),
                      ),
                    ),
                  ),
                  const DashboardSectionHeader(title: 'アクティビティ'),
                  _buildPanelSection(
                    context,
                    scheme,
                    dashboardState: dashboardState,
                    trainingState: trainingState,
                    progressState: progressState,
                    todayBurn: burn,
                    onMeal: () => goTab(_tabMeal),
                    onTraining: () => goTab(_tabTraining),
                    onProgress: () => goTab(_tabProgress),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _buildTrainerChatCard(context, scheme),
                  DashboardCollapsibleSection(
                    title: '詳細を見る',
                    subtitle: '筋肉休息・週次サマリー・予定・グラフ',
                    children: [
                      const MuscleRestCard(margin: EdgeInsets.zero),
                      _buildPeriodSummarySection(context, scheme, ref),
                      _buildRoutineReminderCard(
                        context,
                        scheme,
                        todaysRoutines,
                        settings: settings,
                        onOpenRoutine: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const RoutineScreen(),
                            ),
                          );
                        },
                        onOpenMealSettings: () => goTab(_tabMeal),
                      ),
                      _buildWeeklyCalorieChart(
                        context,
                        scheme,
                        dashboardState,
                        mealState.calorieGoal,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.bottomNavClearance),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static double _todayBurn(TrainingState trainingState, double bodyWeightKg) {
    final w = bodyWeightKg > 0
        ? bodyWeightKg
        : TrainingCalorieCalculator.defaultBodyWeightKg;
    var sum = 0.0;
    for (final log in trainingState.todayLogs) {
      sum += TrainingNotifier.estimateCalories(log, bodyWeightKg: w);
    }
    return sum;
  }

  Widget _buildStreakRow(
    BuildContext context,
    AchievementState achievementState,
  ) {
    final streaks = achievementState.streaks;
    if (streaks.nutritionStreak == 0 &&
        streaks.trainingStreak == 0 &&
        streaks.overallStreak == 0) {
      return const SizedBox.shrink();
    }

    final semantic = context.bewellColors;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: [
          if (streaks.nutritionStreak > 0)
            _streakChip(
              context,
              semantic,
              '🍽',
              streaks.nutritionStreak,
              '食事',
            ),
          if (streaks.trainingStreak > 0)
            _streakChip(
              context,
              semantic,
              '💪',
              streaks.trainingStreak,
              'トレ',
            ),
          if (streaks.overallStreak > 0)
            _streakChip(
              context,
              semantic,
              '🚶',
              streaks.overallStreak,
              '歩数',
            ),
        ],
      ),
    );
  }

  Widget _streakChip(
    BuildContext context,
    BeWellColors semantic,
    String emoji,
    int streak,
    String label,
  ) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: semantic.streak.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: semantic.streak.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$emoji 🔥', style: const TextStyle(fontSize: 13)),
            const SizedBox(width: 4),
            Text(
              '$streak日 $label',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: semantic.streak,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceCard(
    BuildContext context,
    ColorScheme scheme, {
    required int intake,
    required int goal,
    required double trainingBurn,
    required double stepsBurn,
    required int remainingMeal,
    required double calorieBalance,
    required double protein,
    required double fat,
    required double carbs,
    required double proteinGoal,
    required double fatGoal,
    required double carbsGoal,
  }) {
    final percent = goal > 0 ? (intake / goal).clamp(0.0, 1.0) : 0.0;
    final isOver = intake > goal;
    final balanceRounded = calorieBalance.round();
    final balanceColor = balanceRounded < 0
        ? scheme.tertiary
        : balanceRounded == 0
            ? scheme.onPrimaryContainer.withValues(alpha: 0.85)
            : scheme.error;

    final semantic = context.bewellColors;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: AppRadius.xlAll,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [semantic.heroGradientStart, semantic.heroGradientEnd],
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '今日のカロリー',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: scheme.onPrimaryContainer,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              '収支は「摂取 −（トレ推定 + 歩数推定）」で算出\n(安静時の代謝は含みません)',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onPrimaryContainer.withValues(alpha: 0.65),
                    height: 1.35,
                  ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 118,
                  height: 118,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox.expand(
                        child: CircularProgressIndicator(
                          value: percent,
                          strokeWidth: 10,
                          backgroundColor:
                              scheme.onPrimaryContainer.withValues(alpha: 0.12),
                          color: isOver
                              ? scheme.error
                              : scheme.primary,
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$intake',
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: scheme.onPrimaryContainer,
                                ),
                          ),
                          Text(
                            '/ $goal kcal',
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium
                                ?.copyWith(
                                  color: scheme.onPrimaryContainer
                                      .withValues(alpha: 0.75),
                                ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _balanceLine(
                        context,
                        scheme,
                        '摂取',
                        '$intake kcal',
                        scheme.onPrimaryContainer,
                      ),
                      _balanceLine(
                        context,
                        scheme,
                        '推定消費（トレ）',
                        '${trainingBurn.round()} kcal',
                        scheme.onPrimaryContainer.withValues(alpha: 0.9),
                      ),
                      if (stepsBurn > 0)
                        _balanceLine(
                          context,
                          scheme,
                          '推定消費（歩数）',
                          '${stepsBurn.round()} kcal',
                          scheme.onPrimaryContainer.withValues(alpha: 0.9),
                        ),
                      const Divider(height: 20),
                      _balanceLine(
                        context,
                        scheme,
                        isOver ? '目標超過（食事）' : '目標まで（食事）',
                        isOver
                            ? '${intake - goal} kcal 超過'
                            : '$remainingMeal kcal',
                        isOver ? scheme.error : scheme.tertiary,
                      ),
                      _balanceLine(
                        context,
                        scheme,
                        'カロリー収支 \n(摂取−運動)',
                        balanceRounded > 0
                            ? '+$balanceRounded kcal'
                            : '$balanceRounded kcal',
                        balanceColor,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Text(
              'PFC（今日）',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.onPrimaryContainer.withValues(alpha: 0.85),
                  ),
            ),
            const SizedBox(height: 8),
            _macroRow(context, scheme, 'タンパク質',
                '${protein.toStringAsFixed(1)} / ${proteinGoal.toStringAsFixed(0)} g'),
            _macroRow(context, scheme, '脂質',
                '${fat.toStringAsFixed(1)} / ${fatGoal.toStringAsFixed(0)} g'),
            _macroRow(context, scheme, '炭水化物',
                '${carbs.toStringAsFixed(1)} / ${carbsGoal.toStringAsFixed(0)} g'),
          ],
        ),
      ),
    );
  }

  Widget _balanceLine(
    BuildContext context,
    ColorScheme scheme,
    String label,
    String value,
    Color valueColor,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onPrimaryContainer.withValues(alpha: 0.75),
                  ),
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: valueColor,
                ),
          ),
        ],
      ),
    );
  }

  Widget _macroRow(
    BuildContext context,
    ColorScheme scheme,
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: scheme.onPrimaryContainer.withValues(alpha: 0.7),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: scheme.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrainerChatCard(BuildContext context, ColorScheme scheme) {
    void open() {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const TrainerChatScreen(),
        ),
      );
    }

    return Material(
      color: scheme.primaryContainer,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      clipBehavior: Clip.antiAlias,
      child: MicroTap(
        onTap: open,
        scale: 0.97,
        child: InkWell(
          onTap: open,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.auto_awesome_rounded,
                      color: scheme.primary, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AIトレーナーに相談',
                        style:
                            Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: scheme.onPrimaryContainer,
                                ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'トレーニング・食事・日々のルーティンをチャットで相談',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.3,
                          color: scheme.onPrimaryContainer
                              .withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    color: scheme.onPrimaryContainer.withValues(alpha: 0.7)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPanelSection(
    BuildContext context,
    ColorScheme scheme, {
    required DashboardState dashboardState,
    required TrainingState trainingState,
    required ProgressState progressState,
    required double todayBurn,
    required VoidCallback onMeal,
    required VoidCallback onTraining,
    required VoidCallback onProgress,
  }) {
    final mealSubtitle = dashboardState.todayRecentFoodNames.isEmpty
        ? '記録を追加'
        : dashboardState.todayRecentFoodNames.join(' · ');

    final trainLines = <String>[];
    if (trainingState.todayLogs.isNotEmpty) {
      trainLines.add('今日 ${trainingState.todayLogs.length} 件');
      trainLines.add('推定 ${todayBurn.round()} kcal');
    } else {
      trainLines.add('今日は未記録');
    }
    if (trainingState.logs.isNotEmpty) {
      final last = trainingState.logs.first.date;
      trainLines.add('前回 ${DateFormat('M/d').format(last)}');
    }

    final trainValue = trainingState.todayLogs.isEmpty
        ? '—'
        : '${todayBurn.round()} kcal';

    String progressSubtitle = 'データなし';
    String progressValue = '—';
    if (progressState.metrics.isNotEmpty) {
      final m = progressState.metrics.last;
      progressSubtitle = '${m.weight} kg · 体脂肪 ${m.bodyFatPercentage}%';
      progressValue = '${m.weight} kg';
    }

    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 400;
        final mealPanel = _dashboardPanel(
          context,
          scheme,
          icon: Icons.restaurant_rounded,
          title: '食事',
          subtitle: mealSubtitle,
          value: '${dashboardState.todayCalories} kcal',
          accent: scheme.secondary,
          onTap: onMeal,
        );
        final trainPanel = _dashboardPanel(
          context,
          scheme,
          icon: Icons.fitness_center_rounded,
          title: 'トレーニング',
          subtitle: trainLines.join('\n'),
          value: trainValue,
          accent: scheme.primary,
          onTap: onTraining,
        );
        final progPanel = _dashboardPanel(
          context,
          scheme,
          icon: Icons.show_chart_rounded,
          title: '進捗',
          subtitle: progressSubtitle,
          value: progressValue,
          accent: scheme.tertiary,
          onTap: onProgress,
        );

        if (wide) {
          return Column(
            children: [
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: mealPanel),
                    const SizedBox(width: 12),
                    Expanded(child: trainPanel),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              progPanel,
            ],
          );
        }
        return Column(
          children: [
            mealPanel,
            const SizedBox(height: 12),
            trainPanel,
            const SizedBox(height: 12),
            progPanel,
          ],
        );
      },
    );
  }

  Widget _dashboardPanel(
    BuildContext context,
    ColorScheme scheme, {
    required IconData icon,
    required String title,
    required String subtitle,
    required String value,
    required Color accent,
    required VoidCallback onTap,
  }) {
    return Material(
      color: scheme.surfaceContainerHigh,
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.lgAll,
        side: BorderSide(
          color: scheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: MicroTap(
        onTap: onTap,
        scale: 0.97,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: accent, size: 22),
                ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: scheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            height: 1.35,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }

  Widget _buildRoutineReminderCard(
    BuildContext context,
    ColorScheme scheme,
    List<TrainingRoutine> todaysRoutines, {
    required SettingsState settings,
    required VoidCallback onOpenRoutine,
    required VoidCallback onOpenMealSettings,
  }) {
    final timeStr = settings.workoutReminderEnabled
        ? '${settings.workoutReminderHour.toString().padLeft(2, '0')}:'
            '${settings.workoutReminderMinute.toString().padLeft(2, '0')}'
        : null;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.event_note_rounded, color: scheme.primary),
                const SizedBox(width: 8),
                Text(
                  '予定とリマインド',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (todaysRoutines.isEmpty)
              Text(
                '今日のルーティンはありません',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              )
            else
              ...todaysRoutines.map((r) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.check_circle_outline_rounded,
                          size: 18, color: scheme.tertiary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              r.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (r.note.isNotEmpty)
                              Text(
                                r.note,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                    ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
            const Divider(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  settings.workoutReminderEnabled
                      ? Icons.notifications_active_rounded
                      : Icons.notifications_off_outlined,
                  size: 20,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        settings.workoutReminderEnabled
                            ? 'ワークアウト通知 · 毎日 $timeStr'
                            : 'ワークアウト通知はオフです',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.tonal(
                            onPressed: onOpenMealSettings,
                            child: const Text('通知は食事タブの設定'),
                          ),
                          OutlinedButton(
                            onPressed: onOpenRoutine,
                            child: const Text('ルーティンを編集'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodSummarySection(
    BuildContext context,
    ColorScheme scheme,
    WidgetRef ref,
  ) {
    final ps = ref.watch(periodSummaryProvider);
    final summary = ps.summary;
    final ev = summary?.evaluation;

    return Card(
      elevation: 0,
      color: scheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.lgAll,
        side: BorderSide(
          color: scheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.insights_rounded, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '期間サマリ',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '食事・トレ・体重記録をもとに、目標との距離感をざっくり評価します',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.35,
                  ),
            ),
            const SizedBox(height: 14),
            SegmentedButton<SummaryPeriodKind>(
              segments: const [
                ButtonSegment(
                  value: SummaryPeriodKind.week,
                  label: Text('1週間'),
                ),
                ButtonSegment(
                  value: SummaryPeriodKind.month,
                  label: Text('1ヶ月'),
                ),
                ButtonSegment(
                  value: SummaryPeriodKind.quarter,
                  label: Text('3ヶ月'),
                ),
              ],
              selected: {ps.preset},
              onSelectionChanged: (Set<SummaryPeriodKind> next) {
                ref
                    .read(periodSummaryProvider.notifier)
                    .setPreset(next.first);
              },
            ),
            const SizedBox(height: 16),
            if (ps.isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (summary != null && ev != null) ...[
              if (ev.score > 0 && ev.grade != '—')
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        ev.grade,
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: scheme.onPrimaryContainer,
                            ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '総合 ${ev.score} 点',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            ev.headline,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              else
                Text(
                  ev.headline,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              const SizedBox(height: 8),
              Text(
                '${DateFormat('M/d', 'ja').format(summary.rangeStart)} 〜 '
                '${DateFormat('M/d', 'ja').format(summary.rangeEnd)} · '
                '${summary.kind.label}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
              if (summary.hasAnyData) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _periodStatChip(
                      context,
                      scheme,
                      '平均摂取',
                      '${summary.avgDailyCalories.round()} kcal/日',
                    ),
                    _periodStatChip(
                      context,
                      scheme,
                      'トレ記録',
                      '${summary.trainingLogCount} 件',
                    ),
                    if (summary.trainingEstimatedKcal > 0)
                      _periodStatChip(
                        context,
                        scheme,
                        '推定消費',
                        '${summary.trainingEstimatedKcal.round()} kcal',
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              ...ev.bullets.map(
                (line) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Icon(
                          Icons.circle,
                          size: 6,
                          color: scheme.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          line,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    height: 1.45,
                                  ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static Widget _periodStatChip(
    BuildContext context,
    ColorScheme scheme,
    String label,
    String value,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyCalorieChart(
    BuildContext context,
    ColorScheme scheme,
    DashboardState state,
    int calorieGoal,
  ) {
    const weekdayLabels = ['月', '火', '水', '木', '金', '土', '日'];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '今週のカロリー',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 16),
            state.isLoading
                ? const SizedBox(
                    height: 180,
                    child: Center(child: CircularProgressIndicator()),
                  )
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
                          final calories = entry.value.value.toDouble();
                          final isEmpty = calories == 0;
                          final isOver = calories > calorieGoal;
                          return BarChartGroupData(
                            x: i,
                            barRods: [
                              BarChartRodData(
                                toY: isEmpty ? 0.5 : calories,
                                color: isEmpty
                                    ? scheme.outline.withValues(alpha: 0.2)
                                    : isOver
                                        ? scheme.error.withValues(alpha: 0.85)
                                        : scheme.primary.withValues(alpha: 0.85),
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
                                final dates = state.weeklyCalories.keys.toList();
                                if (value.toInt() < dates.length) {
                                  final wd = dates[value.toInt()].weekday;
                                  final isToday = dates[value.toInt()].day ==
                                      DateTime.now().day;
                                  return Text(
                                    weekdayLabels[wd - 1],
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: isToday
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: isToday ? scheme.primary : null,
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
                              color: scheme.error.withValues(alpha: 0.45),
                              strokeWidth: 1.5,
                              dashArray: [5, 5],
                              label: HorizontalLineLabel(
                                show: true,
                                labelResolver: (_) => '目標',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: scheme.error,
                                ),
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
}

/// SleepDetailScreen への遷移ラッパー（ProviderScope の外でも動作するよう ConsumerWidget を使用）
class _SleepDetailWrapper extends ConsumerWidget {
  const _SleepDetailWrapper();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const SleepDetailScreen();
  }
}
