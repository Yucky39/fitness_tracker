import 'dart:math' show max;
import 'dart:typed_data';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/legacy.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:uuid/uuid.dart';
import '../models/community_food_entry.dart';
import '../models/food_item.dart';
import '../models/meal_preset.dart';
import '../providers/advice_provider.dart';
import '../providers/meal_provider.dart';
import '../providers/nutrition_trend_provider.dart';
import '../providers/preset_provider.dart';
import '../providers/settings_provider.dart';
import '../services/auth_service.dart';
import '../services/barcode_lookup_service.dart';
import '../services/community_food_service.dart';
import '../services/food_search_service.dart';
import '../services/meal_image_analysis_service.dart';
import '../widgets/nutrient_bar.dart';
import '../widgets/recipe_preset_editor_sheet.dart';
import '../widgets/supplement_entry_dialog.dart';

/// 検索結果1行。行全体の水平ドラッグで食品名を横スクロールする。
class _FoodSearchResultTile extends StatefulWidget {
  const _FoodSearchResultTile({
    required this.name,
    required this.subtitle,
    required this.onTap,
    this.leading,
  });

  final String name;
  final Widget subtitle;
  final VoidCallback onTap;
  final Widget? leading;

  @override
  State<_FoodSearchResultTile> createState() => _FoodSearchResultTileState();
}

class _FoodSearchResultTileState extends State<_FoodSearchResultTile> {
  final ScrollController _nameHScroll = ScrollController();

  @override
  void dispose() {
    _nameHScroll.dispose();
    super.dispose();
  }

  void _onHorizontalDrag(DragUpdateDetails details) {
    if (!_nameHScroll.hasClients) return;
    final p = _nameHScroll.position;
    final next = (p.pixels - details.delta.dx).clamp(0.0, p.maxScrollExtent);
    _nameHScroll.jumpTo(next);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleStyle =
        theme.listTileTheme.titleTextStyle ?? theme.textTheme.bodyLarge;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onTap,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragUpdate: _onHorizontalDrag,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.leading != null) ...[
                  SizedBox(
                    width: 40,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: widget.leading,
                    ),
                  ),
                  const SizedBox(width: 16),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Builder(
                        builder: (context) {
                          final h = (24 * MediaQuery.textScalerOf(context).scale(1))
                              .clamp(22.0, 56.0)
                              .toDouble();
                          return SizedBox(
                            height: h,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: SingleChildScrollView(
                                controller: _nameHScroll,
                                scrollDirection: Axis.horizontal,
                                physics: const NeverScrollableScrollPhysics(),
                                child: Text(
                                  widget.name,
                                  maxLines: 1,
                                  softWrap: false,
                                  style: titleStyle,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 2),
                      widget.subtitle,
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
}

// View-mode toggle: false = grouped list, true = timeline
final _timelineViewProvider = StateProvider<bool>((ref) => false);

class MealScreen extends ConsumerWidget {
  const MealScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mealState = ref.watch(mealProvider);
    final mealNotifier = ref.read(mealProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('食事管理'),
      ),
      body: mealState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDateNavigation(context, mealState, mealNotifier),
                  const SizedBox(height: 16),
                  _buildSummaryCard(context, mealState),
                  const SizedBox(height: 8),
                  _buildTrendCard(context, ref, mealState),
                  const SizedBox(height: 8),
                  _buildAdviceCard(context, ref, mealState),
                  const SizedBox(height: 8),
                  _buildFoodList(context, ref, mealState, mealNotifier),
                  const SizedBox(height: 80),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddMethodSheet(context, ref, mealState, mealNotifier),
        child: const Icon(Icons.add),
      ),
    );
  }

  // ── Date navigation ────────────────────────────────────────────────────────

  Widget _buildDateNavigation(BuildContext context, MealState state, MealNotifier notifier) {
    final today = DateTime.now();
    final isToday = state.selectedDate.year == today.year &&
        state.selectedDate.month == today.month &&
        state.selectedDate.day == today.day;

    String dateLabel;
    if (isToday) {
      dateLabel = '今日 (${DateFormat('M/d').format(state.selectedDate)})';
    } else {
      final yesterday = DateTime(today.year, today.month, today.day - 1);
      final isYesterday = state.selectedDate.year == yesterday.year &&
          state.selectedDate.month == yesterday.month &&
          state.selectedDate.day == yesterday.day;
      dateLabel = isYesterday
          ? '昨日 (${DateFormat('M/d').format(state.selectedDate)})'
          : DateFormat('yyyy/M/d').format(state.selectedDate);
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => notifier.changeDate(
            state.selectedDate.subtract(const Duration(days: 1)),
          ),
        ),
        TextButton(
          onPressed: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: state.selectedDate,
              firstDate: DateTime(2020),
              lastDate: today,
            );
            if (picked != null) notifier.changeDate(picked);
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
              : () => notifier.changeDate(
                    state.selectedDate.add(const Duration(days: 1)),
                  ),
        ),
      ],
    );
  }

  // ── Summary card ───────────────────────────────────────────────────────────

  Widget _buildSummaryCard(BuildContext context, MealState state) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'カロリー収支',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${state.totalCalories} / ${state.calorieGoal} kcal',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: state.totalCalories > state.calorieGoal ? Colors.red : Colors.green,
                  ),
                ),
              ],
            ),
            if (state.todayItems.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Text(
                '食事タイプ別',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (final type in MealType.values)
                    if ((state.caloriesByMealType[type] ?? 0) > 0)
                      Chip(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        label: Text(
                          '${type.label} ${state.caloriesByMealType[type]} kcal',
                          style: const TextStyle(fontSize: 12),
                        ),
                        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                      ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            NutrientBar(
              label: 'タンパク質 (P)',
              current: state.totalProtein,
              goal: state.proteinGoal,
              color: Colors.blue,
            ),
            const SizedBox(height: 8),
            NutrientBar(
              label: '脂質 (F)',
              current: state.totalFat,
              goal: state.fatGoal,
              color: Colors.orange,
            ),
            const SizedBox(height: 8),
            NutrientBar(
              label: '炭水化物 (C)',
              current: state.totalCarbs,
              goal: state.carbsGoal,
              color: Colors.purple,
            ),
            // 食物繊維・ナトリウム（目標付きバー表示）
            const SizedBox(height: 8),
            NutrientBar(
              label: '食物繊維',
              current: state.totalFiber,
              goal: state.fiberGoal,
              color: Colors.green,
            ),
            const SizedBox(height: 8),
            NutrientBar(
              label: 'ナトリウム (Na)',
              current: state.totalSodium,
              goal: state.sodiumGoal,
              color: Colors.blueGrey,
              unit: 'mg',
            ),
            // Micronutrient summary (shown only when sugar data exists)
            if (state.totalSugar > 0) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  _microNutrientChip('糖質', '${state.totalSugar.toStringAsFixed(1)}g', Colors.amber),
                ],
              ),
            ],
            if (state.totalMicronutrients.hasAnyPositive) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                dense: true,
                title: const Text(
                  'ビタミン・ミネラル（合計）',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final line in state.totalMicronutrients.summaryLines())
                            Text(line, style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (state.totalDetailedNutrients.hasAnyPositive) ...[
              const SizedBox(height: 8),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                dense: true,
                title: const Text(
                  '詳細栄養：脂肪酸・アミノ酸（合計）',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final line in state.totalDetailedNutrients.summaryLines())
                            Text(line, style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Weekly calorie trend card ───────────────────────────────────────────────

  Widget _buildTrendCard(BuildContext context, WidgetRef ref, MealState mealState) {
    final trendAsync = ref.watch(nutritionTrendProvider);

    return trendAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (summaries) {
        // Only show last 7 days
        final last7 = summaries.length >= 7
            ? summaries.sublist(summaries.length - 7)
            : summaries;

        // Hide card when there is no data at all
        if (last7.every((s) => s.calories == 0)) return const SizedBox.shrink();

        final maxCal = last7
            .map((s) => s.calories.toDouble())
            .fold(0.0, max)
            .clamp(mealState.calorieGoal * 0.5, double.infinity) *
            1.25;

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.bar_chart, color: Colors.indigo, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        '週間カロリートレンド',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Text(
                      '目標 ${mealState.calorieGoal} kcal',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 130,
                  child: BarChart(
                    BarChartData(
                      maxY: maxCal,
                      barTouchData: BarTouchData(
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipItem: (group, _, rod, __) {
                            final cal = rod.toY.toInt();
                            return BarTooltipItem(
                              '$cal kcal',
                              const TextStyle(color: Colors.white, fontSize: 12),
                            );
                          },
                        ),
                      ),
                      barGroups: last7.asMap().entries.map((e) {
                        final i = e.key;
                        final s = e.value;
                        final isToday = i == last7.length - 1;
                        final over = s.calories > mealState.calorieGoal;
                        return BarChartGroupData(
                          x: i,
                          barRods: [
                            BarChartRodData(
                              toY: s.calories.toDouble(),
                              color: s.calories == 0
                                  ? Colors.grey.shade200
                                  : over
                                      ? Colors.red.withValues(alpha: isToday ? 1.0 : 0.7)
                                      : Colors.indigo.withValues(alpha: isToday ? 1.0 : 0.7),
                              width: 22,
                              borderRadius:
                                  const BorderRadius.vertical(top: Radius.circular(4)),
                            ),
                          ],
                        );
                      }).toList(),
                      titlesData: FlTitlesData(
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 22,
                            getTitlesWidget: (value, _) {
                              final i = value.toInt();
                              if (i < 0 || i >= last7.length) return const Text('');
                              final isToday = i == last7.length - 1;
                              return Text(
                                isToday ? '今日' : DateFormat('M/d').format(last7[i].date),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight:
                                      isToday ? FontWeight.bold : FontWeight.normal,
                                  color: isToday ? Colors.indigo : Colors.grey,
                                ),
                              );
                            },
                          ),
                        ),
                        leftTitles:
                            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles:
                            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles:
                            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      gridData: const FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      extraLinesData: ExtraLinesData(
                        horizontalLines: [
                          HorizontalLine(
                            y: mealState.calorieGoal.toDouble(),
                            color: Colors.red.withValues(alpha: 0.5),
                            strokeWidth: 1.5,
                            dashArray: [6, 4],
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
      },
    );
  }

  Widget _microNutrientChip(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  // ── AI Advice card ─────────────────────────────────────────────────────────

  Widget _buildAdviceCard(BuildContext context, WidgetRef ref, MealState mealState) {
    final adviceState = ref.watch(adviceProvider);
    final settings = ref.watch(settingsProvider);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 長いモデル名と同一行に置かない（横幅が潰れてタイトルが縦書きになるのを防ぐ）
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(Icons.psychology, color: Colors.teal),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'AIアドバイス',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (adviceState.isLoading)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: adviceState.adviceText != null ? '再取得（更新）' : 'アドバイスを取得',
                    onPressed: () => ref.read(adviceProvider.notifier).fetchAdvice(
                          items: mealState.todayItems,
                          date: mealState.selectedDate,
                          calorieGoal: mealState.calorieGoal,
                          proteinGoal: mealState.proteinGoal,
                          fatGoal: mealState.fatGoal,
                          carbsGoal: mealState.carbsGoal,
                          fiberGoal: mealState.fiberGoal,
                          sodiumGoal: mealState.sodiumGoal,
                          adviceLevel: settings.adviceLevel,
                          apiKey: settings.currentApiKey,
                          provider: settings.selectedProvider,
                          model: settings.currentModel,
                          forceRefresh: true,
                        ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.teal.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${settings.selectedProvider.label} · ${settings.currentModelLabel} · ${settings.adviceLevelLabel}',
                style: const TextStyle(fontSize: 12, color: Colors.teal, height: 1.35),
              ),
            ),
            if (adviceState.error != null) ...[
              const SizedBox(height: 8),
              Text(adviceState.error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
            ],
            if (adviceState.adviceText != null) ...[
              const SizedBox(height: 8),
              const Divider(),
              const SizedBox(height: 4),
              Text(adviceState.adviceText!, style: const TextStyle(fontSize: 14, height: 1.6)),
            ],
            if (adviceState.adviceText == null && adviceState.error == null && !adviceState.isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  '↑ ボタンを押してアドバイスを取得',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Food list grouped by meal type ─────────────────────────────────────────

  Widget _buildFoodList(
      BuildContext context, WidgetRef ref, MealState state, MealNotifier notifier) {
    if (state.todayItems.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Text('まだ記録がありません\n右下の + ボタンで追加できます',
              textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    final isTimeline = ref.watch(_timelineViewProvider);

    // Group by meal type in display order (used only in list mode)
    final grouped = <MealType, List<FoodItem>>{};
    for (final item in state.todayItems) {
      grouped.putIfAbsent(item.mealType, () => []).add(item);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── View toggle header ─────────────────────────────────────────
        Row(
          children: [
            Text(
              '今日の記録 (${state.todayItems.length}件)',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const Spacer(),
            Tooltip(
              message: isTimeline ? 'グループ表示に切替' : 'タイムライン表示に切替',
              child: IconButton(
                icon: Icon(
                  isTimeline ? Icons.view_list_outlined : Icons.view_timeline_outlined,
                  size: 20,
                ),
                onPressed: () =>
                    ref.read(_timelineViewProvider.notifier).state = !isTimeline,
              ),
            ),
          ],
        ),

        if (isTimeline) ...[
          _buildTimelineView(context, ref, state, notifier),
        ] else ...[
          for (final type in MealType.values)
            if (grouped.containsKey(type)) ...[
              _buildMealTypeHeader(type, grouped[type]!),
              for (final item in grouped[type]!)
                _buildFoodTile(context, ref, item, state, notifier),
            ],
        ],

        // Save preset button
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.bookmark_add, size: 18),
              label: const Text('今日の食事をプリセット保存'),
              onPressed: () => _showSavePresetDialog(context, ref, state.todayItems),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.restaurant_menu, size: 18),
              label: const Text('レシピを計算して保存'),
              onPressed: () => _showRecipePresetEditor(context, ref),
            ),
          ],
        ),
      ],
    );
  }

  // ── Timeline view ──────────────────────────────────────────────────────────

  Widget _buildTimelineView(
      BuildContext context, WidgetRef ref, MealState state, MealNotifier notifier) {
    final sorted = List<FoodItem>.from(state.todayItems)
      ..sort((a, b) => a.date.compareTo(b.date));

    return Column(
      children: List.generate(sorted.length, (i) {
        final item = sorted[i];
        final isLast = i == sorted.length - 1;
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Time column
              SizedBox(
                width: 44,
                child: Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Text(
                    DateFormat('HH:mm').format(item.date),
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                    textAlign: TextAlign.right,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Timeline line + dot
              Column(
                children: [
                  if (i > 0)
                    Container(width: 1.5, height: 14, color: Colors.grey.shade300),
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: Colors.indigo.withValues(alpha: 0.8),
                      shape: BoxShape.circle,
                    ),
                  ),
                  if (!isLast)
                    Expanded(
                        child: Container(width: 1.5, color: Colors.grey.shade300)),
                ],
              ),
              const SizedBox(width: 10),
              // Content
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    if (item.mealType == MealType.supplement) {
                      showSupplementEntryDialog(
                        context: context,
                        notifier: notifier,
                        existingItem: item,
                      );
                    } else {
                      _showFoodDialog(
                        context: context,
                        ref: ref,
                        mealState: state,
                        notifier: notifier,
                        existingItem: item,
                      );
                    }
                  },
                  child: Padding(
                    padding: EdgeInsets.only(bottom: isLast ? 0 : 12, top: 4),
                    child: Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 5, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: Colors.indigo
                                              .withValues(alpha: 0.1),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          item.mealType.label,
                                          style: const TextStyle(
                                              fontSize: 10,
                                              color: Colors.indigo),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          item.name,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'P: ${item.protein}g  F: ${item.fat}g  C: ${item.carbs}g',
                                    style: const TextStyle(
                                        fontSize: 11, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('${item.calories}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15)),
                                const Text('kcal',
                                    style: TextStyle(
                                        fontSize: 10, color: Colors.grey)),
                              ],
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  size: 18, color: Colors.red),
                              constraints: const BoxConstraints(
                                  minWidth: 32, minHeight: 32),
                              padding: EdgeInsets.zero,
                              onPressed: () async {
                                final ok = await showDialog<bool>(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                    title: const Text('削除の確認'),
                                    content:
                                        Text('「${item.name}」を削除しますか？'),
                                    actions: [
                                      TextButton(
                                          onPressed: () =>
                                              Navigator.pop(_, false),
                                          child: const Text('キャンセル')),
                                      TextButton(
                                          onPressed: () =>
                                              Navigator.pop(_, true),
                                          child: const Text('削除',
                                              style: TextStyle(
                                                  color: Colors.red))),
                                    ],
                                  ),
                                );
                                if (ok == true) notifier.deleteFoodItem(item.id);
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildMealTypeHeader(MealType type, List<FoodItem> items) {
    final totalCal = items.fold(0, (sum, i) => sum + i.calories);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 4),
      child: Row(
        children: [
          Text(type.label,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(width: 8),
          Text('$totalCal kcal', style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildFoodTile(
      BuildContext context, WidgetRef ref, FoodItem item, MealState mealState, MealNotifier notifier) {
    final hasMicro = item.sugar > 0 ||
        item.fiber > 0 ||
        item.sodium > 0 ||
        item.micronutrients.hasAnyPositive ||
        item.detailedNutrients.hasAnyPositive;
    final isSupplement = item.mealType == MealType.supplement;
    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('削除の確認'),
            content: Text('「${item.name}」を削除しますか？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('キャンセル'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('削除', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ) ??
            false;
      },
      onDismissed: (_) => notifier.deleteFoodItem(item.id),
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 3),
        child: Tooltip(
          message: 'タップして編集',
          child: ListTile(
            onTap: () {
              if (isSupplement) {
                showSupplementEntryDialog(
                  context: context,
                  notifier: notifier,
                  existingItem: item,
                );
              } else {
                _showFoodDialog(
                  context: context,
                  ref: ref,
                  mealState: mealState,
                  notifier: notifier,
                  existingItem: item,
                );
              }
            },
            leading: isSupplement
                ? Icon(Icons.medication_outlined, color: Theme.of(context).colorScheme.primary, size: 22)
                : null,
            title: Text(isSupplement ? '[サプリ] ${item.name}' : item.name),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('P: ${item.protein}g  F: ${item.fat}g  C: ${item.carbs}g',
                    style: const TextStyle(fontSize: 12)),
                if (hasMicro)
                  Text(
                    [
                      if (item.sugar > 0) '糖質: ${item.sugar}g',
                      if (item.fiber > 0) '食物繊維: ${item.fiber}g',
                      if (item.sodium > 0) 'Na: ${item.sodium.toInt()}mg',
                    ].join('  '),
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
              ],
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${item.calories}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const Text('kcal', style: TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            ),
            isThreeLine: hasMicro,
          ),
        ),
      ),
    );
  }

  // ── Unified add / edit food dialog ────────────────────────────────────────

  void _showFoodDialog({
    required BuildContext context,
    required WidgetRef ref,
    required MealState mealState,
    required MealNotifier notifier,
    FoodItem? existingItem,
  }) {
    final isEdit = existingItem != null;
    final nameController = TextEditingController(text: existingItem?.name ?? '');
    final calorieController =
        TextEditingController(text: existingItem != null ? existingItem.calories.toString() : '');
    final proteinController =
        TextEditingController(text: existingItem != null ? existingItem.protein.toString() : '');
    final fatController =
        TextEditingController(text: existingItem != null ? existingItem.fat.toString() : '');
    final carbsController =
        TextEditingController(text: existingItem != null ? existingItem.carbs.toString() : '');
    final sugarController = TextEditingController(
        text: existingItem != null && existingItem.sugar > 0
            ? existingItem.sugar.toString()
            : '');
    final fiberController = TextEditingController(
        text: existingItem != null && existingItem.fiber > 0
            ? existingItem.fiber.toString()
            : '');
    final sodiumController = TextEditingController(
        text: existingItem != null && existingItem.sodium > 0
            ? existingItem.sodium.toString()
            : '');

    MealType selectedMealType =
        existingItem?.mealType ?? MealType.detectFromTime(DateTime.now());

    void fillFromSearch(FoodSearchResult result, int grams) {
      final ratio = grams / 100.0;
      nameController.text = result.name;
      calorieController.text =
          (result.caloriesPer100g * ratio).round().toString();
      proteinController.text =
          (result.proteinPer100g * ratio).toStringAsFixed(1);
      fatController.text = (result.fatPer100g * ratio).toStringAsFixed(1);
      carbsController.text =
          (result.carbsPer100g * ratio).toStringAsFixed(1);
    }

    void fillFromCommunity(CommunityFoodEntry entry) {
      nameController.text = entry.name;
      calorieController.text = entry.calories.toString();
      proteinController.text = entry.protein.toStringAsFixed(1);
      fatController.text = entry.fat.toStringAsFixed(1);
      carbsController.text = entry.carbs.toStringAsFixed(1);
      if (entry.sugar > 0) sugarController.text = entry.sugar.toStringAsFixed(1);
      if (entry.fiber > 0) fiberController.text = entry.fiber.toStringAsFixed(1);
      if (entry.sodium > 0) sodiumController.text = entry.sodium.toStringAsFixed(0);
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(isEdit ? '食事を編集' : '食事を記録'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Meal type selector ─────────────────────────────────
                  const Text('食事の種類', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: MealType.values
                        .where((t) => t != MealType.supplement)
                        .map((t) {
                      final selected = selectedMealType == t;
                      return ChoiceChip(
                        label: Text(t.label),
                        selected: selected,
                        onSelected: (_) => setDialogState(() => selectedMealType = t),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),

                  // ── Recent foods (add mode only) ───────────────────────
                  if (!isEdit && mealState.recentFoods.isNotEmpty) ...[
                    const Text('最近使った食品',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 40,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: mealState.recentFoods.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, i) {
                          final food = mealState.recentFoods[i];
                          return ActionChip(
                            label: Text(food.name),
                            onPressed: () {
                              setDialogState(() {
                                nameController.text = food.name;
                                calorieController.text = food.calories.toString();
                                proteinController.text = food.protein.toString();
                                fatController.text = food.fat.toString();
                                carbsController.text = food.carbs.toString();
                                sugarController.text =
                                    food.sugar > 0 ? food.sugar.toString() : '';
                                fiberController.text =
                                    food.fiber > 0 ? food.fiber.toString() : '';
                                sodiumController.text =
                                    food.sodium > 0 ? food.sodium.toString() : '';
                                selectedMealType = food.mealType;
                              });
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  if (!isEdit) ...[
                    OutlinedButton.icon(
                      icon: const Icon(Icons.search, size: 16),
                      label: const Text('食品を検索'),
                      onPressed: () => _showUnifiedFoodSearchDialog(
                        context,
                        onSelectStandard: (result, grams) {
                          setDialogState(() => fillFromSearch(result, grams));
                        },
                        onSelectCommunity: (entry) {
                          setDialogState(() => fillFromCommunity(entry));
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],

                  // ── Main fields ────────────────────────────────────────
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: '食品名'),
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  TextField(
                    controller: calorieController,
                    decoration: const InputDecoration(labelText: 'カロリー (kcal)'),
                    keyboardType: TextInputType.number,
                  ),
                  TextField(
                    controller: proteinController,
                    decoration: const InputDecoration(labelText: 'タンパク質 (g)'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                  TextField(
                    controller: fatController,
                    decoration: const InputDecoration(labelText: '脂質 (g)'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                  TextField(
                    controller: carbsController,
                    decoration: const InputDecoration(labelText: '炭水化物 (g)'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 4),

                  // ── Micronutrients (expandable) ────────────────────────
                  Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: const Text('その他栄養素',
                          style: TextStyle(fontSize: 13, color: Colors.grey)),
                      children: [
                        TextField(
                          controller: sugarController,
                          decoration: const InputDecoration(labelText: '糖質 (g)'),
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                        ),
                        TextField(
                          controller: fiberController,
                          decoration: const InputDecoration(labelText: '食物繊維 (g)'),
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                        ),
                        TextField(
                          controller: sodiumController,
                          decoration: const InputDecoration(labelText: 'ナトリウム (mg)'),
                          keyboardType: TextInputType.number,
                        ),
                      ],
                    ),
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
                  if (nameController.text.isEmpty) return;
                  final calories = int.tryParse(calorieController.text) ?? 0;
                  final protein = double.tryParse(proteinController.text) ?? 0;
                  final fat = double.tryParse(fatController.text) ?? 0;
                  final carbs = double.tryParse(carbsController.text) ?? 0;
                  final sugar = double.tryParse(sugarController.text) ?? 0;
                  final fiber = double.tryParse(fiberController.text) ?? 0;
                  final sodium = double.tryParse(sodiumController.text) ?? 0;

                  if (isEdit) {
                    notifier.updateFoodItem(existingItem.copyWith(
                      name: nameController.text,
                      calories: calories,
                      protein: protein,
                      fat: fat,
                      carbs: carbs,
                      sugar: sugar,
                      fiber: fiber,
                      sodium: sodium,
                      micronutrients: existingItem.micronutrients,
                      detailedNutrients: existingItem.detailedNutrients,
                      mealType: selectedMealType,
                    ));
                  } else {
                    notifier.addFoodItem(
                      name: nameController.text,
                      calories: calories,
                      protein: protein,
                      fat: fat,
                      carbs: carbs,
                      sugar: sugar,
                      fiber: fiber,
                      sodium: sodium,
                      mealType: selectedMealType,
                    );

                    // コミュニティDBへの貢献（fire-and-forget）
                    final userId = AuthService().userId;
                    final contributeEnabled = ref
                        .read(settingsProvider)
                        .communityFoodContributeEnabled;
                    if (userId != null && contributeEnabled && calories > 0) {
                      CommunityFoodService().contribute(CommunityFoodEntry(
                        id: const Uuid().v4(),
                        name: nameController.text.trim(),
                        nameSearch: nameController.text.trim().toLowerCase(),
                        calories: calories,
                        protein: protein,
                        fat: fat,
                        carbs: carbs,
                        sugar: sugar,
                        fiber: fiber,
                        sodium: sodium,
                        contributedBy: userId,
                        createdAt: DateTime.now(),
                      ));
                    }
                  }
                  Navigator.pop(context);
                },
                child: Text(isEdit ? '保存' : '追加'),
              ),
            ],
          );
        },
      ),
    );
  }

  /// 標準成分DBとコミュニティ食品をまとめて検索する。
  void _showUnifiedFoodSearchDialog(
    BuildContext context, {
    required void Function(FoodSearchResult result, int grams) onSelectStandard,
    required void Function(CommunityFoodEntry entry) onSelectCommunity,
  }) {
    final searchController = TextEditingController();
    final gramsController = TextEditingController(text: '100');
    final foodSearchService = FoodSearchService();
    final communityService = CommunityFoodService();
    List<FoodSearchResult> standardResults = [];
    List<CommunityFoodEntry> communityResults = [];
    bool isSearching = false;
    String? error;
    bool hasSearched = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> doSearch() async {
            setDialogState(() {
              isSearching = true;
              error = null;
              hasSearched = true;
            });
            final q = searchController.text;
            List<FoodSearchResult> std = [];
            String? err;
            try {
              std = await foodSearchService.search(q);
            } catch (_) {
              err = '食品データベースの検索に失敗しました';
            }
            final community = await communityService.search(q);
            setDialogState(() {
              standardResults = std;
              communityResults = community;
              error = err;
              isSearching = false;
            });
          }

          final showEmpty = hasSearched &&
              !isSearching &&
              error == null &&
              standardResults.isEmpty &&
              communityResults.isEmpty &&
              searchController.text.trim().isNotEmpty;

          final media = MediaQuery.sizeOf(context);
          return AlertDialog(
            scrollable: true,
            constraints: BoxConstraints(
              maxWidth: 560,
              maxHeight: media.height * 0.88,
            ),
            title: const Text('食品検索'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: searchController,
                        decoration: const InputDecoration(
                          labelText: '食品名',
                          hintText: '標準成分表・コミュニティの両方を検索',
                        ),
                        onSubmitted: (_) => doSearch(),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: doSearch,
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Text('摂取量（データベース用）: ',
                        style: TextStyle(fontSize: 13)),
                    SizedBox(
                      width: 70,
                      child: TextField(
                        controller: gramsController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          suffix: Text('g'),
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'コミュニティの項目は登録された分量の数値がそのまま反映されます。',
                  style: TextStyle(fontSize: 10, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                if (isSearching)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else ...[
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(error!,
                          style: const TextStyle(color: Colors.red)),
                    ),
                  if (showEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        '該当する食品が見つかりませんでした',
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    ),
                  if (!isSearching &&
                      (standardResults.isNotEmpty ||
                          communityResults.isNotEmpty)) ...[
                    if (standardResults.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.only(bottom: 4),
                        child: Text(
                          '食品データベース',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                      ...standardResults.map(
                        (r) => _FoodSearchResultTile(
                          name: r.name,
                          subtitle: Text(
                            [
                              '${r.caloriesPer100g}kcal/100g  '
                                  'P:${r.proteinPer100g.toStringAsFixed(1)}g',
                              if (r.dataSourceLabel != null) r.dataSourceLabel!,
                            ].join('\n'),
                            style: const TextStyle(fontSize: 10),
                            maxLines: 4,
                          ),
                          onTap: () {
                            final grams =
                                int.tryParse(gramsController.text) ?? 100;
                            onSelectStandard(r, grams);
                            Navigator.pop(context);
                          },
                        ),
                      ),
                    ],
                    if (standardResults.isNotEmpty &&
                        communityResults.isNotEmpty)
                      const Divider(height: 16),
                    if (communityResults.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.only(bottom: 4, top: 4),
                        child: Text(
                          'コミュニティ食品',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                      ...communityResults.map(
                        (r) => _FoodSearchResultTile(
                          name: r.name,
                          leading: const Icon(Icons.people_outline,
                              size: 18, color: Colors.grey),
                          subtitle: Text(
                            '${r.calories}kcal  P:${r.protein.toStringAsFixed(1)}g  '
                            'F:${r.fat.toStringAsFixed(1)}g  C:${r.carbs.toStringAsFixed(1)}g'
                            '${r.useCount > 0 ? '  （${r.useCount}回使用）' : ''}',
                            style: const TextStyle(fontSize: 10),
                          ),
                          onTap: () {
                            communityService.incrementUseCount(r.id);
                            onSelectCommunity(r);
                            Navigator.pop(context);
                          },
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          'コミュニティの数値は保証されません。',
                          style: TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                      ),
                    ],
                  ],
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('閉じる'),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Add method selection ───────────────────────────────────────────────────

  void _showAddMethodSheet(
    BuildContext context,
    WidgetRef ref,
    MealState mealState,
    MealNotifier notifier,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit_note),
                title: const Text('手動で入力'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showFoodDialog(context: context, ref: ref, mealState: mealState, notifier: notifier);
                },
              ),
              ListTile(
                leading: const Icon(Icons.medication_outlined),
                title: const Text('サプリメントを記録'),
                subtitle: const Text('食事タイプとは別。MCT・アミノ酸など詳細も入力できます'),
                onTap: () {
                  Navigator.pop(ctx);
                  showSupplementEntryDialog(
                    context: context,
                    notifier: notifier,
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('写真で自動分析'),
                subtitle: const Text('AIが食事内容を認識してPFC・栄養素を自動入力します'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showPhotoAnalysisDialog(context, ref, notifier);
                },
              ),
              ListTile(
                leading: const Icon(Icons.qr_code_scanner),
                title: const Text('バーコードスキャン'),
                subtitle: const Text('商品バーコードからOpen Food Factsで栄養素を取得'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showBarcodeScanSheet(context, ref, mealState, notifier);
                },
              ),
              ListTile(
                leading: const Icon(Icons.bookmark_outlined),
                title: const Text('プリセットから追加'),
                subtitle: const Text('保存済みの食事セットをワンタップで追加'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showPresetSheet(context, ref, notifier);
                },
              ),
              ListTile(
                leading: const Icon(Icons.restaurant_menu),
                title: const Text('自分のレシピを保存'),
                subtitle: const Text('食材・分量・調理法から栄養を計算してプリセット化'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showRecipePresetEditor(context, ref);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Barcode scan ───────────────────────────────────────────────────────────

  void _showBarcodeScanSheet(
    BuildContext context,
    WidgetRef ref,
    MealState mealState,
    MealNotifier notifier,
  ) {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('バーコードスキャンはWebでは利用できません')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _BarcodeScanSheet(
        onScanned: (barcode) => _handleBarcodeResult(context, ref, mealState, notifier, barcode),
      ),
    );
  }

  Future<void> _handleBarcodeResult(
    BuildContext context,
    WidgetRef ref,
    MealState mealState,
    MealNotifier notifier,
    String barcode,
  ) async {
    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 12),
              Text('商品情報を検索中...'),
            ],
          ),
        ),
      ),
    );

    final result = await BarcodeLookupService().lookup(barcode);

    if (!context.mounted) return;
    Navigator.pop(context); // close loading dialog

    if (result == null) {
      await showDialog(
        context: context,
        builder: (_) => _BarcodeManualRegisterDialog(
          barcode: barcode,
          onAdd: ({
            required String name,
            required int calories,
            required double protein,
            required double fat,
            required double carbs,
            required MealType mealType,
          }) {
            notifier.addFoodItem(
              name: name,
              calories: calories,
              protein: protein,
              fat: fat,
              carbs: carbs,
              sugar: 0,
              fiber: 0,
              sodium: 0,
              mealType: mealType,
            );
          },
        ),
      );
      return;
    }

    await showDialog(
      context: context,
      builder: (_) => _BarcodeResultDialog(
        result: result,
        onAdd: ({
          required String name,
          required int calories,
          required double protein,
          required double fat,
          required double carbs,
          required double sugar,
          required double fiber,
          required double sodium,
          required MealType mealType,
        }) {
          notifier.addFoodItem(
            name: name,
            calories: calories,
            protein: protein,
            fat: fat,
            carbs: carbs,
            sugar: sugar,
            fiber: fiber,
            sodium: sodium,
            mealType: mealType,
          );
        },
      ),
    );
  }

  // ── Preset sheet ───────────────────────────────────────────────────────────

  void _showPresetSheet(
    BuildContext context,
    WidgetRef ref,
    MealNotifier notifier,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _PresetSheet(
        onApply: (preset) {
          for (final item in preset.items) {
            notifier.addFoodItem(
              name: item.name,
              calories: item.calories,
              protein: item.protein,
              fat: item.fat,
              carbs: item.carbs,
              sugar: item.sugar,
              fiber: item.fiber,
              sodium: item.sodium,
              micronutrients: item.micronutrients,
              detailedNutrients: item.detailedNutrients,
              mealType: item.mealType,
            );
          }
        },
      ),
    );
  }

  void _showRecipePresetEditor(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: RecipePresetEditorSheet(
          onSave: (name, lines, mealType) {
            ref.read(presetProvider.notifier).saveRecipePreset(name, lines, mealType);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('レシピ「$name」をプリセットに保存しました')),
            );
          },
        ),
      ),
    );
  }

  void _showSavePresetDialog(
    BuildContext context,
    WidgetRef ref,
    List<FoodItem> items,
  ) {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('プリセットとして保存'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${items.length}品目・合計${items.fold(0, (s, i) => s + i.calories)} kcal を保存します',
                style: const TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 12),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'プリセット名', hintText: '例：いつもの昼食'),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () {
              if (nameController.text.trim().isEmpty) return;
              ref.read(presetProvider.notifier).savePreset(
                    nameController.text.trim(),
                    items,
                  );
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('「${nameController.text.trim()}」を保存しました')),
              );
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  // ── Photo analysis ─────────────────────────────────────────────────────────

  Future<void> _showPhotoAnalysisDialog(
    BuildContext context,
    WidgetRef ref,
    MealNotifier notifier,
  ) async {
    final settings = ref.read(settingsProvider);

    final source = await showDialog<ImageSource>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('写真を選択'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('カメラで撮影'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('ギャラリーから選択'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null || !context.mounted) return;

    XFile? xFile;
    try {
      xFile = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('画像の取得に失敗しました: $e')),
        );
      }
      return;
    }

    if (xFile == null || !context.mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _PhotoAnalysisDialog(
        imageFile: xFile!,
        apiKey: settings.currentApiKey,
        provider: settings.selectedProvider,
        model: settings.currentModel,
        onAdd: (items, mealType) {
          for (final item in items) {
            notifier.addFoodItem(
              name: item.amount.isNotEmpty ? '${item.name}（${item.amount}）' : item.name,
              calories: item.calories,
              protein: item.protein,
              fat: item.fat,
              carbs: item.carbs,
              sugar: item.sugar,
              fiber: item.fiber,
              sodium: item.sodium,
              mealType: mealType,
            );
          }
        },
      ),
    );
  }
}

// ── Barcode scan sheet ────────────────────────────────────────────────────

class _BarcodeScanSheet extends StatefulWidget {
  final void Function(String barcode) onScanned;
  const _BarcodeScanSheet({required this.onScanned});

  @override
  State<_BarcodeScanSheet> createState() => _BarcodeScanSheetState();
}

class _BarcodeScanSheetState extends State<_BarcodeScanSheet> {
  final MobileScannerController _controller = MobileScannerController();
  bool _scanned = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: 340,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'バーコードをスキャン',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  MobileScanner(
                    controller: _controller,
                    onDetect: (BarcodeCapture capture) {
                      if (_scanned) return;
                      final barcode = capture.barcodes.firstOrNull;
                      if (barcode?.rawValue != null) {
                        _scanned = true;
                        Navigator.pop(context);
                        widget.onScanned(barcode!.rawValue!);
                      }
                    },
                  ),
                  // Scan frame overlay
                  Center(
                    child: Container(
                      width: 260,
                      height: 80,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.green, width: 2.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const Positioned(
                    bottom: 12,
                    left: 0,
                    right: 0,
                    child: Text(
                      'バーコードをフレーム内に合わせてください',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Barcode result dialog ─────────────────────────────────────────────────

class _BarcodeResultDialog extends StatefulWidget {
  final BarcodeResult result;
  final void Function({
    required String name,
    required int calories,
    required double protein,
    required double fat,
    required double carbs,
    required double sugar,
    required double fiber,
    required double sodium,
    required MealType mealType,
  }) onAdd;

  const _BarcodeResultDialog({required this.result, required this.onAdd});

  @override
  State<_BarcodeResultDialog> createState() => _BarcodeResultDialogState();
}

class _BarcodeResultDialogState extends State<_BarcodeResultDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _gramsController;
  MealType _mealType = MealType.detectFromTime(DateTime.now());

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.result.name);
    final defaultGrams = widget.result.defaultServingGrams ?? 100.0;
    _gramsController = TextEditingController(text: defaultGrams.toStringAsFixed(0));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _gramsController.dispose();
    super.dispose();
  }

  Map<String, num> get _nutrients {
    final grams = double.tryParse(_gramsController.text) ?? 100.0;
    return widget.result.forGrams(grams);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('商品が見つかりました'),
      content: SingleChildScrollView(
        child: StatefulBuilder(
          builder: (context, setDialogState) {
            final n = _nutrients;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: '食品名'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _gramsController,
                        decoration: const InputDecoration(
                          labelText: '量 (g)',
                          suffixText: 'g',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (_) => setDialogState(() {}),
                      ),
                    ),
                    if (widget.result.defaultServingGrams != null) ...[
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () {
                          _gramsController.text =
                              widget.result.defaultServingGrams!.toStringAsFixed(0);
                          setDialogState(() {});
                        },
                        child: const Text('1食分'),
                      ),
                    ],
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () {
                        _gramsController.text = '100';
                        setDialogState(() {});
                      },
                      child: const Text('100g'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${n['calories']} kcal',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('P: ${n['protein']}g  F: ${n['fat']}g  C: ${n['carbs']}g',
                          style: const TextStyle(fontSize: 13)),
                      if ((n['sugar'] as num) > 0 ||
                          (n['fiber'] as num) > 0 ||
                          (n['sodium'] as num) > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            [
                              if ((n['sugar'] as num) > 0) '糖質: ${n['sugar']}g',
                              if ((n['fiber'] as num) > 0) '食物繊維: ${n['fiber']}g',
                              if ((n['sodium'] as num) > 0) 'Na: ${n['sodium']}mg',
                            ].join('  '),
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Text('食事の種類', style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: MealType.values.map((t) {
                    return ChoiceChip(
                      label: Text(t.label),
                      selected: _mealType == t,
                      onSelected: (_) => setState(() => _mealType = t),
                    );
                  }).toList(),
                ),
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        TextButton(
          onPressed: () {
            final n = _nutrients;
            widget.onAdd(
              name: _nameController.text.trim().isEmpty
                  ? widget.result.name
                  : _nameController.text.trim(),
              calories: n['calories'] as int,
              protein: (n['protein'] as num).toDouble(),
              fat: (n['fat'] as num).toDouble(),
              carbs: (n['carbs'] as num).toDouble(),
              sugar: (n['sugar'] as num).toDouble(),
              fiber: (n['fiber'] as num).toDouble(),
              sodium: (n['sodium'] as num).toDouble(),
              mealType: _mealType,
            );
            Navigator.pop(context);
          },
          child: const Text('追加'),
        ),
      ],
    );
  }
}

// ── Barcode manual register dialog ────────────────────────────────────────

class _BarcodeManualRegisterDialog extends StatefulWidget {
  final String barcode;
  final void Function({
    required String name,
    required int calories,
    required double protein,
    required double fat,
    required double carbs,
    required MealType mealType,
  }) onAdd;

  const _BarcodeManualRegisterDialog({
    required this.barcode,
    required this.onAdd,
  });

  @override
  State<_BarcodeManualRegisterDialog> createState() =>
      _BarcodeManualRegisterDialogState();
}

class _BarcodeManualRegisterDialogState
    extends State<_BarcodeManualRegisterDialog> {
  final _nameController = TextEditingController();
  final _caloriesController = TextEditingController();
  final _proteinController = TextEditingController();
  final _fatController = TextEditingController();
  final _carbsController = TextEditingController();
  MealType _mealType = MealType.detectFromTime(DateTime.now());

  @override
  void dispose() {
    _nameController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _fatController.dispose();
    _carbsController.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      _nameController.text.trim().isNotEmpty &&
      (int.tryParse(_caloriesController.text) ?? -1) >= 0;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('食品を手動で登録'),
      content: SingleChildScrollView(
        child: StatefulBuilder(
          builder: (context, setDialogState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'バーコード: ${widget.barcode}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: '食品名 *'),
                  onChanged: (_) => setDialogState(() {}),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _caloriesController,
                  decoration: const InputDecoration(
                    labelText: 'カロリー *',
                    suffixText: 'kcal',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setDialogState(() {}),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _proteinController,
                        decoration: const InputDecoration(
                          labelText: 'タンパク質',
                          suffixText: 'g',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _fatController,
                        decoration: const InputDecoration(
                          labelText: '脂質',
                          suffixText: 'g',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _carbsController,
                        decoration: const InputDecoration(
                          labelText: '炭水化物',
                          suffixText: 'g',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text('食事の種類',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: MealType.values.map((t) {
                    return ChoiceChip(
                      label: Text(t.label),
                      selected: _mealType == t,
                      onSelected: (_) => setState(() => _mealType = t),
                    );
                  }).toList(),
                ),
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        TextButton(
          onPressed: _canSubmit
              ? () {
                  widget.onAdd(
                    name: _nameController.text.trim(),
                    calories: int.tryParse(_caloriesController.text) ?? 0,
                    protein: double.tryParse(_proteinController.text) ?? 0,
                    fat: double.tryParse(_fatController.text) ?? 0,
                    carbs: double.tryParse(_carbsController.text) ?? 0,
                    mealType: _mealType,
                  );
                  Navigator.pop(context);
                }
              : null,
          child: const Text('追加'),
        ),
      ],
    );
  }
}

// ── Preset sheet ──────────────────────────────────────────────────────────

class _PresetSheet extends ConsumerWidget {
  final void Function(MealPreset preset) onApply;
  const _PresetSheet({required this.onApply});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presetState = ref.watch(presetProvider);
    final presets = presetState.presets;

    return SafeArea(
      child: DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Expanded(
                    child: Text('プリセットから追加',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            if (presets.isEmpty)
              const Expanded(
                child: Center(
                  child: Text(
                    'プリセットがまだありません\n'
                    '「今日の食事をプリセット保存」または「レシピを計算して保存」で追加できます',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: presets.length,
                  itemBuilder: (ctx, i) {
                    final preset = presets[i];
                    final subtitle = preset.isRecipe && preset.recipeLines != null
                        ? '${preset.recipeLines!.length}材料・${preset.totalCalories} kcal（レシピ）'
                        : '${preset.items.length}品目・${preset.totalCalories} kcal';
                    return ListTile(
                      leading: Icon(preset.isRecipe ? Icons.restaurant_menu : Icons.bookmark),
                      title: Text(preset.name),
                      subtitle: Text(
                        subtitle,
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: ctx,
                            builder: (_) => AlertDialog(
                              title: const Text('削除の確認'),
                              content: Text('「${preset.name}」を削除しますか？'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(_, false),
                                  child: const Text('キャンセル'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(_, true),
                                  child: const Text('削除',
                                      style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            ref.read(presetProvider.notifier).deletePreset(preset.id);
                          }
                        },
                      ),
                      onTap: () {
                        onApply(preset);
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              preset.isRecipe
                                  ? '「${preset.name}」（レシピ）を追加しました'
                                  : '「${preset.name}」の${preset.items.length}品目を追加しました',
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Photo Analysis Dialog ─────────────────────────────────────────────────

class _PhotoAnalysisDialog extends StatefulWidget {
  final XFile imageFile;
  final String apiKey;
  final AiProviderType provider;
  final String model;
  final void Function(List<AnalyzedFoodItem> items, MealType mealType) onAdd;

  const _PhotoAnalysisDialog({
    required this.imageFile,
    required this.apiKey,
    required this.provider,
    required this.model,
    required this.onAdd,
  });

  @override
  State<_PhotoAnalysisDialog> createState() => _PhotoAnalysisDialogState();
}

class _PhotoAnalysisDialogState extends State<_PhotoAnalysisDialog> {
  bool _isLoading = true;
  String? _error;
  List<AnalyzedFoodItem> _items = [];
  Uint8List? _imageBytes;
  MealType _selectedMealType = MealType.detectFromTime(DateTime.now());

  // Inline editing state
  int? _editingIndex;
  Map<String, TextEditingController>? _editControllers;

  @override
  void initState() {
    super.initState();
    _loadAndAnalyze();
  }

  @override
  void dispose() {
    _disposeEditControllers();
    super.dispose();
  }

  void _disposeEditControllers() {
    _editControllers?.values.forEach((c) => c.dispose());
    _editControllers = null;
  }

  void _startEditing(int index) {
    _disposeEditControllers();
    final item = _items[index];
    _editControllers = {
      'name': TextEditingController(text: item.name),
      'calories': TextEditingController(text: item.calories.toString()),
      'protein': TextEditingController(text: item.protein.toString()),
      'fat': TextEditingController(text: item.fat.toString()),
      'carbs': TextEditingController(text: item.carbs.toString()),
      'sugar': TextEditingController(
          text: item.sugar > 0 ? item.sugar.toString() : ''),
      'fiber': TextEditingController(
          text: item.fiber > 0 ? item.fiber.toString() : ''),
      'sodium': TextEditingController(
          text: item.sodium > 0 ? item.sodium.toString() : ''),
    };
    setState(() => _editingIndex = index);
  }

  void _confirmEdit(int index) {
    if (_editControllers == null) return;
    final updated = _items[index].copyWith(
      name: _editControllers!['name']!.text.trim().isNotEmpty
          ? _editControllers!['name']!.text.trim()
          : null,
      calories: int.tryParse(_editControllers!['calories']!.text),
      protein: double.tryParse(_editControllers!['protein']!.text),
      fat: double.tryParse(_editControllers!['fat']!.text),
      carbs: double.tryParse(_editControllers!['carbs']!.text),
      sugar: double.tryParse(_editControllers!['sugar']!.text),
      fiber: double.tryParse(_editControllers!['fiber']!.text),
      sodium: double.tryParse(_editControllers!['sodium']!.text),
    );
    _disposeEditControllers();
    setState(() {
      _items[index] = updated;
      _editingIndex = null;
    });
  }

  void _cancelEdit() {
    _disposeEditControllers();
    setState(() => _editingIndex = null);
  }

  Future<void> _loadAndAnalyze() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final bytes = _imageBytes ?? await widget.imageFile.readAsBytes();
      if (_imageBytes == null && mounted) setState(() => _imageBytes = bytes);

      final items = await MealImageAnalysisService().analyzeImage(
        imageBytes: bytes,
        filePath: widget.imageFile.path,
        apiKey: widget.apiKey,
        provider: widget.provider,
        model: widget.model,
      );

      if (mounted) setState(() { _items = items; _isLoading = false; });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('写真で食事を記録'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_imageBytes != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(
                  _imageBytes!,
                  height: 120,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            const SizedBox(height: 12),
            if (!_isLoading && _error == null && _items.isNotEmpty) ...[
              const Text('食事の種類', style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: MealType.values.map((t) {
                  return ChoiceChip(
                    label: Text(t.label),
                    selected: _selectedMealType == t,
                    onSelected: (_) => setState(() => _selectedMealType = t),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
            ],
            _buildBody(),
          ],
        ),
      ),
      actions: _buildActions(context),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 12),
              Text('AIが食事内容を分析中...', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 40),
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13),
                textAlign: TextAlign.center),
          ],
        ),
      );
    }

    if (_items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text('食品を検出できませんでした。別の写真でお試しください。'),
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 320),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text('${_items.length}品目を検出しました',
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(width: 4),
                Text('（タップで編集）',
                    style: TextStyle(fontSize: 11, color: Colors.grey[400])),
              ],
            ),
            const SizedBox(height: 4),
            ...List.generate(_items.length, (i) => _buildItemTile(_items[i], i)),
          ],
        ),
      ),
    );
  }

  Widget _buildItemTile(AnalyzedFoodItem item, int index) {
    final isEditing = _editingIndex == index;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 3),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CheckboxListTile(
            value: item.selected,
            onChanged: (v) => setState(() => item.selected = v ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            title: isEditing
                ? TextField(
                    controller: _editControllers!['name'],
                    decoration: const InputDecoration(isDense: true, labelText: '名前'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  )
                : Row(
                    children: [
                      Expanded(
                        child: Text(item.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14)),
                      ),
                      Text('${item.calories} kcal',
                          style: const TextStyle(fontSize: 13)),
                    ],
                  ),
            subtitle: isEditing
                ? null
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (item.amount.isNotEmpty)
                        Text(item.amount,
                            style: const TextStyle(color: Colors.grey, fontSize: 11)),
                      Text('P: ${item.protein}g  F: ${item.fat}g  C: ${item.carbs}g',
                          style: const TextStyle(fontSize: 12)),
                      if (item.sugar > 0 || item.fiber > 0 || item.sodium > 0)
                        Text(
                          [
                            if (item.sugar > 0) '糖質: ${item.sugar}g',
                            if (item.fiber > 0) '食物繊維: ${item.fiber}g',
                            if (item.sodium > 0) 'Na: ${item.sodium.toInt()}mg',
                          ].join('  '),
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                    ],
                  ),
            isThreeLine: !isEditing &&
                (item.amount.isNotEmpty ||
                    item.sugar > 0 ||
                    item.fiber > 0 ||
                    item.sodium > 0),
            secondary: isEditing
                ? null
                : IconButton(
                    icon: const Icon(Icons.edit, size: 18),
                    tooltip: '編集',
                    onPressed: () => _startEditing(index),
                  ),
          ),
          // Inline edit form
          if (isEditing)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _editControllers!['calories'],
                          decoration: const InputDecoration(
                              isDense: true, labelText: 'kcal'),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _editControllers!['protein'],
                          decoration: const InputDecoration(
                              isDense: true, labelText: 'P (g)'),
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _editControllers!['fat'],
                          decoration: const InputDecoration(
                              isDense: true, labelText: 'F (g)'),
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _editControllers!['carbs'],
                          decoration: const InputDecoration(
                              isDense: true, labelText: 'C (g)'),
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _editControllers!['sugar'],
                          decoration: const InputDecoration(
                              isDense: true, labelText: '糖質 (g)'),
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _editControllers!['fiber'],
                          decoration: const InputDecoration(
                              isDense: true, labelText: '繊維 (g)'),
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _editControllers!['sodium'],
                          decoration: const InputDecoration(
                              isDense: true, labelText: 'Na (mg)'),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _cancelEdit,
                        child: const Text('キャンセル'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () => _confirmEdit(index),
                        child: const Text('確定'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildActions(BuildContext context) {
    if (_isLoading) {
      return [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
      ];
    }

    if (_error != null) {
      return [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        TextButton(onPressed: _loadAndAnalyze, child: const Text('再試行')),
      ];
    }

    final selected = _items.where((i) => i.selected).toList();
    return [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('キャンセル'),
      ),
      TextButton(
        onPressed: selected.isEmpty
            ? null
            : () {
                widget.onAdd(selected, _selectedMealType);
                Navigator.pop(context);
              },
        child: Text('${selected.length}品目を追加'),
      ),
    ];
  }
}
