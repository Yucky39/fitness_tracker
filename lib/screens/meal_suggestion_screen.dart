import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../models/meal_suggestion.dart';
import '../providers/meal_provider.dart';
import '../providers/meal_suggestion_provider.dart';
import '../providers/settings_provider.dart';
import '../services/ingredient_merge_service.dart';
import '../services/meal_suggestion_service.dart';
import '../utils/suggestion_shopping_list.dart';

/// 1日の食事提案を表示する画面
class MealSuggestionScreen extends ConsumerWidget {
  const MealSuggestionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(mealSuggestionProvider);
    final mealState = ref.watch(mealProvider);
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(mealSuggestionProvider.notifier);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final hasWeekly = state.weeklySuggestion != null;
    final hasDaily = state.suggestion != null;
    final hasContentForPeriod = switch (state.period) {
      SuggestionPeriod.week => hasWeekly,
      SuggestionPeriod.today || SuggestionPeriod.tomorrow => hasDaily,
    };
    final anyCached = hasWeekly || hasDaily;

    return Scaffold(
      appBar: AppBar(
        title: const Text('食事メニュー提案'),
        actions: const [],
      ),
      body: CustomScrollView(
        slivers: [
          // ── 目標サマリーヘッダー ──────────────────────────────────────────
          SliverToBoxAdapter(
            child: _GoalSummaryBanner(
              mealState: mealState,
              suggestion: state.suggestion,
            ),
          ),

          // ── 期間セレクタ ──────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: SegmentedButton<SuggestionPeriod>(
                segments: const [
                  ButtonSegment(
                    value: SuggestionPeriod.today,
                    label: Text('今日'),
                    icon: Icon(Icons.today),
                  ),
                  ButtonSegment(
                    value: SuggestionPeriod.tomorrow,
                    label: Text('明日'),
                    icon: Icon(Icons.event),
                  ),
                  ButtonSegment(
                    value: SuggestionPeriod.week,
                    label: Text('1週間'),
                    icon: Icon(Icons.date_range),
                  ),
                ],
                selected: {state.period},
                onSelectionChanged: (s) => notifier.setPeriod(s.first),
              ),
            ),
          ),

          // ── 生成日時バッジ ────────────────────────────────────────────────
          if (!state.isLoading && hasContentForPeriod)
            SliverToBoxAdapter(
              child: _GeneratedAtBadge(
                generatedAt: state.period == SuggestionPeriod.week
                    ? state.weeklySuggestion?.generatedAt
                    : state.suggestion?.generatedAt,
                onRegenerate: () => notifier.generate(),
              ),
            ),

          if (!state.isLoading &&
              anyCached &&
              state.error == null &&
              (state.weeklySuggestion != null || state.suggestion != null))
            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.shopping_basket_outlined, size: 20),
                  label: const Text('食材の買い物リスト（任意）'),
                  onPressed: () => _openShoppingListBottomSheet(context, state),
                ),
              ),
            ),

          // ── コンテンツ ────────────────────────────────────────────────────
          if (state.isLoading)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(state.period == SuggestionPeriod.week
                        ? 'AIが1週間の食事メニューを考えています...'
                        : 'AIが食事メニューを考えています...'),
                  ],
                ),
              ),
            )
          else if (state.error != null)
            SliverFillRemaining(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline,
                          size: 48, color: colorScheme.error),
                      const SizedBox(height: 12),
                      Text(
                        state.error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: colorScheme.error),
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        icon: const Icon(Icons.refresh),
                        label: const Text('再試行'),
                        onPressed: () => notifier.generate(),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else if (!hasContentForPeriod)
            SliverFillRemaining(
              child: _EmptyState(
                hasApiKey: settings.currentApiKey.isNotEmpty,
                period: state.period,
                hasWeeklyPlanCached: hasWeekly,
                onGenerate: () => notifier.generate(),
              ),
            )
          // 週間プラン表示
          else if (state.period == SuggestionPeriod.week &&
              state.weeklySuggestion != null) ...[
            if ((state.weeklySuggestion!.supplementNote ?? '').isNotEmpty)
              SliverToBoxAdapter(
                child: _SupplementNoteCard(
                    note: state.weeklySuggestion!.supplementNote!),
              ),
            _WeeklyView(weekly: state.weeklySuggestion!),
            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ]
          // 日次プラン表示（今日・明日）
          else if (state.suggestion != null) ...[
            if ((state.suggestion!.supplementNote ?? '').isNotEmpty)
              SliverToBoxAdapter(
                child: _SupplementNoteCard(
                    note: state.suggestion!.supplementNote!),
              ),
            SliverList.separated(
              itemCount: state.suggestion!.meals.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final meal = state.suggestion!.meals[i];
                return _MealSection(meal: meal);
              },
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ],
      ),
    );
  }
}

// ── 生成日時バッジ ────────────────────────────────────────────────────────────

class _GeneratedAtBadge extends StatelessWidget {
  const _GeneratedAtBadge({required this.generatedAt, required this.onRegenerate});
  final DateTime? generatedAt;
  final VoidCallback onRegenerate;

  String _format(DateTime dt) {
    final now = DateTime.now();
    final isToday = dt.year == now.year && dt.month == now.month && dt.day == now.day;
    final time = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    if (isToday) return '本日 $time 生成';
    return '${dt.month}/${dt.day} $time 生成';
  }

  @override
  Widget build(BuildContext context) {
    if (generatedAt == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Row(
        children: [
          Icon(Icons.save_outlined, size: 14, color: cs.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            _format(generatedAt!),
            style: theme.textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          const Spacer(),
          TextButton.icon(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            icon: const Icon(Icons.refresh, size: 14),
            label: const Text('再生成', style: TextStyle(fontSize: 12)),
            onPressed: onRegenerate,
          ),
        ],
      ),
    );
  }
}

// ── 目標 vs 提案サマリー ─────────────────────────────────────────────────────

class _GoalSummaryBanner extends StatelessWidget {
  const _GoalSummaryBanner({required this.mealState, required this.suggestion});

  final MealState mealState;
  final DailyMealSuggestion? suggestion;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      color: cs.surfaceContainerLow,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('1日の栄養目標', style: theme.textTheme.labelMedium),
          const SizedBox(height: 8),
          Row(
            children: [
              _NutritionChip(
                label: 'カロリー',
                goal: '${mealState.calorieGoal}kcal',
                suggested: suggestion != null
                    ? '${suggestion!.totalCalories}kcal'
                    : null,
                color: cs.primary,
              ),
              const SizedBox(width: 8),
              _NutritionChip(
                label: 'P',
                goal: '${mealState.proteinGoal.toStringAsFixed(0)}g',
                suggested: suggestion != null
                    ? '${suggestion!.totalProtein.toStringAsFixed(1)}g'
                    : null,
                color: Colors.blue,
              ),
              const SizedBox(width: 8),
              _NutritionChip(
                label: 'F',
                goal: '${mealState.fatGoal.toStringAsFixed(0)}g',
                suggested: suggestion != null
                    ? '${suggestion!.totalFat.toStringAsFixed(1)}g'
                    : null,
                color: Colors.orange,
              ),
              const SizedBox(width: 8),
              _NutritionChip(
                label: 'C',
                goal: '${mealState.carbsGoal.toStringAsFixed(0)}g',
                suggested: suggestion != null
                    ? '${suggestion!.totalCarbs.toStringAsFixed(1)}g'
                    : null,
                color: Colors.purple,
              ),
            ],
          ),
          if (suggestion != null) ...[
            const SizedBox(height: 6),
            Text(
              '提案値 / 目標値',
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

class _NutritionChip extends StatelessWidget {
  const _NutritionChip({
    required this.label,
    required this.goal,
    this.suggested,
    required this.color,
  });

  final String label;
  final String goal;
  final String? suggested;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        decoration: BoxDecoration(
          color: color.withAlpha(24),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withAlpha(60)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(label,
                style: theme.textTheme.labelSmall?.copyWith(color: color)),
            if (suggested != null) ...[
              Text(suggested!,
                  style: theme.textTheme.labelMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              Text('/ $goal',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ] else
              Text(goal,
                  style: theme.textTheme.labelMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

// ── サプリ考慮コメント ────────────────────────────────────────────────────────

class _SupplementNoteCard extends StatelessWidget {
  const _SupplementNoteCard({required this.note});
  final String note;

  @override
  Widget build(BuildContext context) {
    if (note.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Card(
        color: Theme.of(context).colorScheme.tertiaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.science_outlined,
                size: 20,
                color: Theme.of(context).colorScheme.onTertiaryContainer,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  note,
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onTertiaryContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 食事セクション ───────────────────────────────────────────────────────────

class _MealSection extends StatelessWidget {
  const _MealSection({required this.meal});
  final SuggestedMeal meal;

  static const _mealIcons = {
    'breakfast': Icons.wb_sunny_outlined,
    'lunch': Icons.wb_twilight,
    'dinner': Icons.nightlight_round,
    'snack': Icons.cookie_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final icon = _mealIcons[meal.mealType] ?? Icons.restaurant_outlined;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 食事タイミングヘッダー
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 8),
            child: Row(
              children: [
                Icon(icon, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 6),
                Text(
                  meal.mealTypeLabel,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                _PfcMiniLabel(
                  calories: meal.totalCalories,
                  protein: meal.totalProtein,
                  fat: meal.totalFat,
                  carbs: meal.totalCarbs,
                ),
              ],
            ),
          ),

          // 料理リスト
          for (final dish in meal.dishes) ...[
            _DishCard(dish: dish, initiallyExpanded: dish.ingredients.isNotEmpty),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _PfcMiniLabel extends StatelessWidget {
  const _PfcMiniLabel({
    required this.calories,
    required this.protein,
    required this.fat,
    required this.carbs,
  });

  final int calories;
  final double protein;
  final double fat;
  final double carbs;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context)
        .textTheme
        .labelSmall
        ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);
    return Text(
      '${calories}kcal  P${protein.toStringAsFixed(1)}g F${fat.toStringAsFixed(1)}g C${carbs.toStringAsFixed(1)}g',
      style: style,
    );
  }
}

// ── 料理カード ───────────────────────────────────────────────────────────────

class _DishCard extends StatelessWidget {
  const _DishCard({required this.dish, this.initiallyExpanded = false});
  final SuggestedDish dish;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          collapsedShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                dish.name,
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              if ((dish.note ?? '').isNotEmpty)
                Text(
                  dish.note!,
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: cs.onSurfaceVariant),
                ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: _PfcMiniLabel(
              calories: dish.calories,
              protein: dish.protein,
              fat: dish.fat,
              carbs: dish.carbs,
            ),
          ),
          children: [
            // 食材
            if (dish.ingredients.isNotEmpty) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '食材',
                  style: theme.textTheme.labelMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 6),
              ...dish.ingredients.map((ing) => _IngredientRow(ing: ing)),
              const SizedBox(height: 12),
            ],

            // 調理手順
            if (dish.steps.isNotEmpty) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '作り方',
                  style: theme.textTheme.labelMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 6),
              ...dish.steps.asMap().entries.map(
                    (e) => _StepRow(index: e.key + 1, text: e.value),
                  ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _IngredientRow extends StatelessWidget {
  const _IngredientRow({required this.ing});
  final SuggestedIngredient ing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          const Icon(Icons.fiber_manual_record, size: 8),
          const SizedBox(width: 8),
          Expanded(
            child: Text('${ing.name}　${ing.amount}',
                style: theme.textTheme.bodySmall),
          ),
          Text(
            '${ing.calories}kcal  P${ing.protein.toStringAsFixed(1)}g',
            style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.index, required this.text});
  final int index;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.colorScheme.primaryContainer,
            ),
            child: Text(
              '$index',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: theme.textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

// ── 週間プラン表示 ────────────────────────────────────────────────────────────

class _WeeklyView extends StatelessWidget {
  const _WeeklyView({required this.weekly});
  final WeeklyMealSuggestion weekly;

  static const _mealIcons = {
    'breakfast': Icons.wb_sunny_outlined,
    'lunch': Icons.wb_twilight,
    'dinner': Icons.nightlight_round,
    'snack': Icons.cookie_outlined,
  };

  static const _mealLabels = {
    'breakfast': '朝食',
    'lunch': '昼食',
    'dinner': '夕食',
    'snack': '間食',
  };

  @override
  Widget build(BuildContext context) {
    return SliverList.separated(
      itemCount: weekly.days.length,
      separatorBuilder: (_, __) => const SizedBox(height: 4),
      itemBuilder: (context, i) => _DayCard(
        day: weekly.days[i],
        generatedAt: weekly.generatedAt,
        mealIcons: _mealIcons,
        mealLabels: _mealLabels,
      ),
    );
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({
    required this.day,
    required this.generatedAt,
    required this.mealIcons,
    required this.mealLabels,
  });

  final WeeklyDayPlan day;
  final DateTime generatedAt;
  final Map<String, IconData> mealIcons;
  final Map<String, String> mealLabels;

  static const _weekdays = ['月', '火', '水', '木', '金', '土', '日'];

  String _buildDateLabel(DateTime actualDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final wd = _weekdays[actualDate.weekday - 1];
    final md = '${actualDate.month}/${actualDate.day}（$wd）';
    if (actualDate == today) return '今日 $md';
    if (actualDate == today.add(const Duration(days: 1))) return '明日 $md';
    return md;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final baseDate =
        DateTime(generatedAt.year, generatedAt.month, generatedAt.day);
    final actualDate = baseDate.add(Duration(days: day.day - 1));
    final now = DateTime.now();
    final isToday =
        actualDate == DateTime(now.year, now.month, now.day);
    final dateLabel = _buildDateLabel(actualDate);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Theme(
          data: theme.copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: isToday,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            collapsedShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            tilePadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            title: Row(
              children: [
                Text(
                  dateLabel,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isToday ? cs.primary : null,
                  ),
                ),
                if (isToday) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '今日',
                      style: TextStyle(
                        fontSize: 10,
                        color: cs.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '${day.totalCalories}kcal  '
                'P${day.totalProtein.toStringAsFixed(1)}g  '
                'F${day.totalFat.toStringAsFixed(1)}g  '
                'C${day.totalCarbs.toStringAsFixed(1)}g',
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
            childrenPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            children: [
              for (final meal in day.meals) ...[
                Row(
                  children: [
                    Icon(
                      mealIcons[meal.mealType] ?? Icons.restaurant_outlined,
                      size: 16,
                      color: cs.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      mealLabels[meal.mealType] ?? meal.mealType,
                      style: theme.textTheme.labelMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                for (final dish in meal.dishes)
                  Padding(
                    padding: const EdgeInsets.only(left: 20, bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(dish.name,
                                  style: theme.textTheme.bodySmall),
                              if ((dish.note ?? '').isNotEmpty)
                                Text(
                                  dish.note!,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                      color: cs.onSurfaceVariant),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${dish.calories}kcal',
                          style: theme.textTheme.labelSmall
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── 初期状態（未生成） ────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.hasApiKey,
    required this.period,
    required this.onGenerate,
    this.hasWeeklyPlanCached = false,
  });
  final bool hasApiKey;
  final SuggestionPeriod period;
  /// 今日／明日タブで日次が未生成でも、週間キャッシュがあるとき true
  final bool hasWeeklyPlanCached;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final description = switch (period) {
      SuggestionPeriod.today =>
        'カロリー目標とPFCバランスに合わせた\n今日1日分の献立・レシピをAIが提案します。\nサプリ・プロテインの記録も自動で考慮します。',
      SuggestionPeriod.tomorrow =>
        'カロリー目標とPFCバランスに合わせた\n明日1日分の献立・レシピをAIが提案します。',
      SuggestionPeriod.week =>
        'カロリー目標とPFCバランスに合わせた\n1週間分（7日分）の献立をAIが提案します。\n毎日変化のあるメニューを提案します。',
    };

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.restaurant_menu,
              size: 64,
              color: theme.colorScheme.primary.withAlpha(180),
            ),
            const SizedBox(height: 16),
            Text(
              '食事メニューを提案します',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            if (hasWeeklyPlanCached &&
                (period == SuggestionPeriod.today ||
                    period == SuggestionPeriod.tomorrow)) ...[
              const SizedBox(height: 12),
              Text(
                '1週間プランのキャッシュがあります。「1週間」タブで一覧を確認できます。ここではボタンを押したときだけ、${period.label}の詳細メニューをAIが作成します。',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: 24),
            if (!hasApiKey) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'AIキーが未設定です。\nサイドバー → AIキー設定 から入力してください。',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ] else
              FilledButton.icon(
                icon: const Icon(Icons.auto_awesome),
                label: Text('${period.label}のメニューを提案する'),
                onPressed: onGenerate,
              ),
          ],
        ),
      ),
    );
  }
}

// ── 買い物リスト（任意）────────────────────────────────────────────────────────

void _openShoppingListBottomSheet(
  BuildContext context,
  MealSuggestionState state,
) {
  final weekly = state.weeklySuggestion;
  final daily = state.suggestion;
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (ctx) {
      final h = MediaQuery.sizeOf(ctx).height * 0.78;
      return SizedBox(
        height: h,
        child: _ShoppingListBottomSheetBody(
          weekly: weekly,
          daily: daily,
          period: state.period,
        ),
      );
    },
  );
}

enum _ShoppingScope { week, day }

class _ShoppingListBottomSheetBody extends StatefulWidget {
  const _ShoppingListBottomSheetBody({
    required this.weekly,
    required this.daily,
    required this.period,
  });

  final WeeklyMealSuggestion? weekly;
  final DailyMealSuggestion? daily;
  final SuggestionPeriod period;

  @override
  State<_ShoppingListBottomSheetBody> createState() =>
      _ShoppingListBottomSheetBodyState();
}

class _ShoppingListBottomSheetBodyState
    extends State<_ShoppingListBottomSheetBody> {
  late _ShoppingScope _scope;
  bool _loading = true;
  IngredientMergeContext _ctx = IngredientMergeContext.empty;
  List<AggregatedShoppingItem> _items = const [];

  bool get _hasWeek => widget.weekly != null;
  bool get _hasDay => widget.daily != null;

  @override
  void initState() {
    super.initState();
    if (_hasWeek && !_hasDay) {
      _scope = _ShoppingScope.week;
    } else if (!_hasWeek && _hasDay) {
      _scope = _ShoppingScope.day;
    } else {
      _scope = _ShoppingScope.week;
    }
    _loadMergeAndItems();
  }

  Future<void> _loadMergeAndItems() async {
    setState(() => _loading = true);
    try {
      final userId = ingredientMergeUserKey();
      final ctx = await IngredientMergeService.instance.loadContext(userId);
      if (!mounted) return;
      setState(() {
        _ctx = ctx;
        _items = _computeItems(ctx);
        _loading = false;
      });
      await IngredientMergeService.instance
          .recordSurfacesSeen(userId, _rawSurfacesForScope());
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _ctx = IngredientMergeContext.empty;
        _items = _computeItems(IngredientMergeContext.empty);
        _loading = false;
      });
    }
  }

  List<AggregatedShoppingItem> _computeItems(IngredientMergeContext ctx) {
    switch (_scope) {
      case _ShoppingScope.week:
        return shoppingListFromWeekly(widget.weekly!, ctx);
      case _ShoppingScope.day:
        return shoppingListFromDaily(widget.daily!, ctx);
    }
  }

  Iterable<String> _rawSurfacesForScope() {
    switch (_scope) {
      case _ShoppingScope.week:
        return collectRawIngredientSurfaces(widget.weekly);
      case _ShoppingScope.day:
        return collectRawIngredientSurfacesFromDaily(widget.daily);
    }
  }

  Future<void> _onScopeChanged(_ShoppingScope scope) async {
    setState(() {
      _scope = scope;
      _items = _computeItems(_ctx);
    });
    try {
      await IngredientMergeService.instance.recordSurfacesSeen(
        ingredientMergeUserKey(),
        _rawSurfacesForScope(),
      );
    } catch (_) {}
  }

  String get _heading {
    switch (_scope) {
      case _ShoppingScope.week:
        return '【1週間の買い物メモ】';
      case _ShoppingScope.day:
        return switch (widget.period) {
          SuggestionPeriod.today => '【今日のメニュー・買い物メモ】',
          SuggestionPeriod.tomorrow => '【明日のメニュー・買い物メモ】',
          SuggestionPeriod.week => '【1日分の買い物メモ】',
        };
    }
  }

  String get _shareText => buildPlainTextShoppingList(
        heading: _heading,
        items: _items,
      );

  String _daySegmentLabel() => switch (widget.period) {
        SuggestionPeriod.today => '今日の分',
        SuggestionPeriod.tomorrow => '明日の分',
        SuggestionPeriod.week => '1日分',
      };

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _shareText));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('買い物リストをコピーしました')),
    );
  }

  Future<void> _share() async {
    await SharePlus.instance.share(
      ShareParams(text: _shareText, subject: '買い物リスト'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final items = _items;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
          child: Text(
            '買い物リスト',
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            '提案メニューに出てくる食材をまとめました。同じ食材らしい表記は、この端末に保存した使用回数と別名データで1行に寄せます。',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: cs.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ),
        if (_hasWeek && _hasDay) ...[
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<_ShoppingScope>(
              segments: [
                const ButtonSegment(
                  value: _ShoppingScope.week,
                  label: Text('1週間分'),
                  icon: Icon(Icons.date_range, size: 18),
                ),
                ButtonSegment(
                  value: _ShoppingScope.day,
                  label: Text(_daySegmentLabel()),
                  icon: Icon(
                    widget.period == SuggestionPeriod.tomorrow
                        ? Icons.event
                        : Icons.today,
                    size: 18,
                  ),
                ),
              ],
              selected: {_scope},
              onSelectionChanged: (s) => _onScopeChanged(s.first),
            ),
          ),
        ],
        const SizedBox(height: 8),
        if (_loading)
          const Expanded(
            child: Center(child: CircularProgressIndicator()),
          )
        else if (items.isEmpty)
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '食材の記載がありません',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                    if (_scope == _ShoppingScope.week) ...[
                      const SizedBox(height: 12),
                      Text(
                        '1週間メニューは以前の形式で保存されている可能性があります。「1週間」タブで献立を再生成すると、その週の献立に基づいた買い物リストが表示されます。',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              itemCount: items.length,
              itemBuilder: (context, i) {
                final item = items[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    title: Text(
                      item.name,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(item.amountsLine),
                    ),
                  ),
                );
              },
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _copy,
                  icon: const Icon(Icons.copy, size: 20),
                  label: const Text('コピー'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _share,
                  icon: const Icon(Icons.share, size: 20),
                  label: const Text('共有'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
