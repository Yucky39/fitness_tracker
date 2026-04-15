import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/meal_suggestion.dart';
import '../providers/meal_provider.dart';
import '../providers/meal_suggestion_provider.dart';
import '../providers/settings_provider.dart';

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

    return Scaffold(
      appBar: AppBar(
        title: const Text('食事メニュー提案'),
        actions: [
          if (state.suggestion != null && !state.isLoading)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: '再提案',
              onPressed: () => notifier.generate(),
            ),
        ],
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

          // ── コンテンツ ────────────────────────────────────────────────────
          if (state.isLoading)
            const SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('AIが食事メニューを考えています...'),
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
          else if (state.suggestion == null)
            SliverFillRemaining(
              child: _EmptyState(
                hasApiKey: settings.currentApiKey.isNotEmpty,
                onGenerate: () => notifier.generate(),
              ),
            )
          else ...[
            // サプリコメント
            if ((state.suggestion!.supplementNote ?? '').isNotEmpty)
              SliverToBoxAdapter(
                child: _SupplementNoteCard(
                    note: state.suggestion!.supplementNote!),
              ),

            // 各食事セクション
            SliverList.separated(
              itemCount: state.suggestion!.meals.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final meal = state.suggestion!.meals[i];
                return _MealSection(meal: meal);
              },
            ),

            // 下余白
            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ],
      ),
      // 提案がない・エラーでもない場合の生成ボタン（初回）
      floatingActionButton:
          (state.suggestion == null && !state.isLoading && state.error == null)
              ? null // EmptyState 内に表示
              : null,
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
            _DishCard(dish: dish),
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
  const _DishCard({required this.dish});
  final SuggestedDish dish;

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

// ── 初期状態（未生成） ────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasApiKey, required this.onGenerate});
  final bool hasApiKey;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
              'カロリー目標とPFCバランスに合わせた\n1日分の献立・レシピをAIが提案します。\nサプリ・プロテインの記録も自動で考慮します。',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
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
                label: const Text('メニューを提案する'),
                onPressed: onGenerate,
              ),
          ],
        ),
      ),
    );
  }
}
