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
import '../models/energy_profile.dart';
import '../models/food_item.dart';
import '../models/meal_preset.dart';
import '../providers/advice_provider.dart';
import '../providers/energy_profile_provider.dart';
import '../providers/meal_provider.dart';
import '../providers/nutrition_trend_provider.dart';
import '../providers/preset_provider.dart';
import '../providers/settings_provider.dart';
import '../services/barcode_lookup_service.dart';
import '../services/energy_goal_calculator.dart';
import '../services/meal_image_analysis_service.dart';
import '../services/export_service.dart';
import '../services/food_search_service.dart';
import '../services/notification_service.dart';
import '../widgets/nutrient_bar.dart';

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
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _showGoalSettingDialog(context, ref, mealState, mealNotifier),
          ),
        ],
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
            // Micronutrient summary (shown only when data exists)
            if (state.totalSugar > 0 || state.totalFiber > 0 || state.totalSodium > 0) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  if (state.totalSugar > 0)
                    _microNutrientChip('糖質', '${state.totalSugar.toStringAsFixed(1)}g', Colors.amber),
                  if (state.totalFiber > 0)
                    _microNutrientChip('食物繊維', '${state.totalFiber.toStringAsFixed(1)}g', Colors.green),
                  if (state.totalSodium > 0)
                    _microNutrientChip(
                        'Na', '${state.totalSodium.toInt()}mg', Colors.blueGrey),
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
            Row(
              children: [
                const Icon(Icons.psychology, color: Colors.teal),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'AIアドバイス',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.teal.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${settings.selectedProvider.label} · ${settings.currentModelLabel} · ${settings.adviceLevelLabel}',
                    style: const TextStyle(fontSize: 12, color: Colors.teal),
                  ),
                ),
                const SizedBox(width: 4),
                adviceState.isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : IconButton(
                        icon: const Icon(Icons.refresh),
                        tooltip: adviceState.adviceText != null ? '再取得（更新）' : 'アドバイスを取得',
                        onPressed: () => ref.read(adviceProvider.notifier).fetchAdvice(
                              items: mealState.todayItems,
                              date: mealState.selectedDate,
                              calorieGoal: mealState.calorieGoal,
                              proteinGoal: mealState.proteinGoal,
                              fatGoal: mealState.fatGoal,
                              carbsGoal: mealState.carbsGoal,
                              adviceLevel: settings.adviceLevel,
                              apiKey: settings.currentApiKey,
                              provider: settings.selectedProvider,
                              model: settings.currentModel,
                              forceRefresh: true,
                            ),
                      ),
              ],
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
              '今日の食事 (${state.todayItems.length}品目)',
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
          _buildTimelineView(context, state, notifier),
        ] else ...[
          for (final type in MealType.values)
            if (grouped.containsKey(type)) ...[
              _buildMealTypeHeader(type, grouped[type]!),
              for (final item in grouped[type]!)
                _buildFoodTile(context, item, state, notifier),
            ],
        ],

        // Save preset button
        const SizedBox(height: 12),
        Center(
          child: OutlinedButton.icon(
            icon: const Icon(Icons.bookmark_add, size: 18),
            label: const Text('今日の食事をプリセット保存'),
            onPressed: () => _showSavePresetDialog(context, ref, state.todayItems),
          ),
        ),
      ],
    );
  }

  // ── Timeline view ──────────────────────────────────────────────────────────

  Widget _buildTimelineView(
      BuildContext context, MealState state, MealNotifier notifier) {
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
                  onTap: () => _showFoodDialog(
                    context: context,
                    mealState: state,
                    notifier: notifier,
                    existingItem: item,
                  ),
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
      BuildContext context, FoodItem item, MealState mealState, MealNotifier notifier) {
    final hasMicro = item.sugar > 0 || item.fiber > 0 || item.sodium > 0;
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
            onTap: () => _showFoodDialog(
              context: context,
              mealState: mealState,
              notifier: notifier,
              existingItem: item,
            ),
            title: Text(item.name),
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

  // ── Goal & settings dialog ─────────────────────────────────────────────────

  void _showGoalSettingDialog(
    BuildContext context,
    WidgetRef ref,
    MealState state,
    MealNotifier notifier,
  ) {
    final ep = ref.read(energyProfileProvider);
    var dialogSex = ep.sex;
    var dialogActivity = ep.activityLevel;
    ComputedNutritionGoals? lastComputed;

    final calorieController = TextEditingController(text: state.calorieGoal.toString());
    final proteinController = TextEditingController(text: state.proteinGoal.toString());
    final fatController = TextEditingController(text: state.fatGoal.toString());
    final carbsController = TextEditingController(text: state.carbsGoal.toString());

    final ageController =
        TextEditingController(text: ep.age > 0 ? ep.age.toString() : '');
    final heightController =
        TextEditingController(text: ep.heightCm > 0 ? ep.heightCm.toString() : '');
    final weightController =
        TextEditingController(text: ep.weightKg > 0 ? ep.weightKg.toString() : '');
    final targetWeightController =
        TextEditingController(text: ep.targetWeightKg > 0 ? ep.targetWeightKg.toString() : '');
    final weeksController =
        TextEditingController(text: ep.goalWeeks > 0 ? ep.goalWeeks.toString() : '12');

    final initialSettings = ref.read(settingsProvider);
    final anthropicKeyCtrl = TextEditingController(text: initialSettings.anthropicApiKey);
    final openAiKeyCtrl = TextEditingController(text: initialSettings.openAiApiKey);
    final geminiKeyCtrl = TextEditingController(text: initialSettings.geminiApiKey);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          String currentLevel = ref.read(settingsProvider).adviceLevel;
          AiProviderType currentProvider = ref.read(settingsProvider).selectedProvider;
          String currentModel = ref.read(settingsProvider).currentModel;

          Widget apiKeyField(AiProviderType provider, TextEditingController ctrl) {
            bool obscure = true;
            return StatefulBuilder(
              builder: (context, setFieldState) => TextField(
                controller: ctrl,
                obscureText: obscure,
                decoration: InputDecoration(
                  labelText: '${provider.label} APIキー',
                  hintText: provider.apiKeyHint,
                  suffixIcon: IconButton(
                    icon: Icon(obscure ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setFieldState(() => obscure = !obscure),
                  ),
                ),
                onChanged: (v) =>
                    ref.read(settingsProvider.notifier).updateApiKey(provider, v),
              ),
            );
          }

          return AlertDialog(
            title: const Text('目標・設定'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('カロリー目標の算出',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(
                    '身長・体重・年齢・性別から基礎代謝（Mifflin–St Jeor）、活動量から1日の推定消費カロリー（TDEE）を求め、目標体重までの期間に応じて1日の摂取目標を割り出します（体重1kgあたり約${EnergyGoalCalculator.kcalPerKgBodyChange.toInt()}kcal換算）。',
                    style: TextStyle(fontSize: 11, color: Colors.grey[700], height: 1.35),
                  ),
                  const SizedBox(height: 10),
                  const Text('性別', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    children: BiologicalSex.values.map((s) {
                      return ChoiceChip(
                        label: Text(s.label),
                        selected: dialogSex == s,
                        onSelected: (_) => setDialogState(() => dialogSex = s),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: ageController,
                    decoration: const InputDecoration(labelText: '年齢（歳）'),
                    keyboardType: TextInputType.number,
                  ),
                  TextField(
                    controller: heightController,
                    decoration: const InputDecoration(labelText: '身長 (cm)'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                  TextField(
                    controller: weightController,
                    decoration: const InputDecoration(labelText: '現在の体重 (kg)'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                  TextField(
                    controller: targetWeightController,
                    decoration: const InputDecoration(labelText: '目標体重 (kg)'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                  TextField(
                    controller: weeksController,
                    decoration: const InputDecoration(
                      labelText: '達成までの期間（週）',
                      helperText: '例：12週 ≒ 約3か月',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 8),
                  const Text('1日の活動レベル',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<ActivityLevel>(
                    value: dialogActivity,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    isExpanded: true,
                    items: ActivityLevel.values.map((e) {
                      return DropdownMenuItem(
                        value: e,
                        child: Text(e.label, style: const TextStyle(fontSize: 13)),
                      );
                    }).toList(),
                    onChanged: (v) {
                      if (v != null) setDialogState(() => dialogActivity = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    icon: const Icon(Icons.calculate_outlined, size: 20),
                    label: const Text('この条件で栄養目標を自動計算'),
                    onPressed: () {
                      if (dialogSex == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('性別を選択してください')),
                        );
                        return;
                      }
                      final age = int.tryParse(ageController.text);
                      final height = double.tryParse(heightController.text);
                      final weight = double.tryParse(weightController.text);
                      final targetW = double.tryParse(targetWeightController.text);
                      final weeks = int.tryParse(weeksController.text);
                      if (age == null || age <= 0 || age > 120) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('有効な年齢を入力してください')),
                        );
                        return;
                      }
                      if (height == null || height < 50 || height > 250) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('身長は50〜250cmの範囲で入力してください')),
                        );
                        return;
                      }
                      if (weight == null || weight < 20 || weight > 300) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('現在体重は20〜300kgの範囲で入力してください')),
                        );
                        return;
                      }
                      if (targetW == null || targetW < 20 || targetW > 300) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('目標体重は20〜300kgの範囲で入力してください')),
                        );
                        return;
                      }
                      if (weeks == null || weeks < 1 || weeks > 520) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('達成期間は1〜520週の範囲で入力してください')),
                        );
                        return;
                      }
                      final profile = EnergyProfile(
                        sex: dialogSex!,
                        age: age,
                        heightCm: height,
                        weightKg: weight,
                        targetWeightKg: targetW,
                        goalWeeks: weeks,
                        activityLevel: dialogActivity,
                      );
                      final result = EnergyGoalCalculator.compute(profile);
                      calorieController.text = result.calories.toString();
                      proteinController.text = result.proteinG.toString();
                      fatController.text = result.fatG.toString();
                      carbsController.text = result.carbsG.toString();
                      setDialogState(() => lastComputed = result);
                      if (result.notes.isNotEmpty && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(result.notes.first),
                            duration: const Duration(seconds: 5),
                          ),
                        );
                      }
                    },
                  ),
                  if (lastComputed != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '基礎代謝 ${lastComputed!.bmr.round()} kcal/日 ・ 推定消費（TDEE） ${lastComputed!.tdee.round()} kcal/日',
                            style: const TextStyle(fontSize: 12),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _appliedEnergyBalanceLabel(lastComputed!.appliedDailyDelta),
                            style: TextStyle(fontSize: 12, color: Colors.grey[800]),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '理論上の体重変化ペース: 1日あたり約 ${lastComputed!.dailyEnergyBalance.round()} kcal相当',
                            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                          ),
                          if (lastComputed!.notes.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            ...lastComputed!.notes.map(
                              (n) => Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(
                                  n,
                                  style: const TextStyle(
                                      fontSize: 11, color: Colors.deepOrange),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  const Text('栄養目標（自動計算後も手動で微調整できます）',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: calorieController,
                    decoration: const InputDecoration(labelText: '目標カロリー (kcal)'),
                    keyboardType: TextInputType.number,
                  ),
                  TextField(
                    controller: proteinController,
                    decoration: const InputDecoration(labelText: '目標タンパク質 (g)'),
                    keyboardType: TextInputType.number,
                  ),
                  TextField(
                    controller: fatController,
                    decoration: const InputDecoration(labelText: '目標脂質 (g)'),
                    keyboardType: TextInputType.number,
                  ),
                  TextField(
                    controller: carbsController,
                    decoration: const InputDecoration(labelText: '目標炭水化物 (g)'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 8),
                  const Text('AIアドバイス設定', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  const Text('使用するAI', style: TextStyle(fontSize: 13)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<AiProviderType>(
                    value: currentProvider,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: AiProviderType.values.map((p) {
                      return DropdownMenuItem(
                        value: p,
                        child: Text(p.label),
                      );
                    }).toList(),
                    onChanged: (p) {
                      if (p == null) return;
                      ref.read(settingsProvider.notifier).updateSelectedProvider(p);
                      setDialogState(() {
                        currentProvider = p;
                        currentModel = ref.read(settingsProvider).currentModel;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  const Text('使用するモデル', style: TextStyle(fontSize: 13)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: currentModel,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: currentProvider.availableModels.map((m) {
                      return DropdownMenuItem(
                        value: m.id,
                        child: Text(m.label, style: const TextStyle(fontSize: 13)),
                      );
                    }).toList(),
                    onChanged: (m) {
                      if (m == null) return;
                      ref.read(settingsProvider.notifier).updateModel(currentProvider, m);
                      setDialogState(() => currentModel = m);
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text('アドバイスのレベル', style: TextStyle(fontSize: 13)),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'strict', label: Text('厳しめ')),
                      ButtonSegment(value: 'normal', label: Text('普通')),
                      ButtonSegment(value: 'gentle', label: Text('優しめ')),
                    ],
                    selected: {currentLevel},
                    onSelectionChanged: (selection) {
                      ref.read(settingsProvider.notifier).updateAdviceLevel(selection.first);
                      setDialogState(() => currentLevel = selection.first);
                    },
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _adviceLevelDescription(currentLevel),
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  const Text('APIキー', style: TextStyle(fontSize: 13)),
                  const SizedBox(height: 8),
                  apiKeyField(AiProviderType.anthropic, anthropicKeyCtrl),
                  const SizedBox(height: 8),
                  apiKeyField(AiProviderType.openai, openAiKeyCtrl),
                  const SizedBox(height: 8),
                  apiKeyField(AiProviderType.gemini, geminiKeyCtrl),
                  const SizedBox(height: 4),
                  const Text(
                    'APIキーはデバイス内にのみ保存されます',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 8),
                  const Text('トレーニングAIアドバイス',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Switch(
                        value: ref.read(settingsProvider).trainingAdviceEnabled,
                        onChanged: (v) {
                          ref
                              .read(settingsProvider.notifier)
                              .updateTrainingAdviceEnabled(v);
                          setDialogState(() {});
                        },
                      ),
                      const Expanded(
                        child: Text(
                          'トレーニング画面でAI評価を表示する',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 8),
                  const Text('リマインダー通知',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _buildReminderRow(
                    context,
                    ref,
                    label: '食事記録リマインダー',
                    enabled: ref.read(settingsProvider).mealReminderEnabled,
                    hour: ref.read(settingsProvider).mealReminderHour,
                    minute: ref.read(settingsProvider).mealReminderMinute,
                    onChanged: (enabled, hour, minute) async {
                      await ref
                          .read(settingsProvider.notifier)
                          .updateNotificationSettings(
                            mealEnabled: enabled,
                            mealHour: hour,
                            mealMinute: minute,
                          );
                      await NotificationService().rescheduleFromSettings();
                      setDialogState(() {});
                    },
                  ),
                  const SizedBox(height: 8),
                  _buildReminderRow(
                    context,
                    ref,
                    label: 'トレーニングリマインダー',
                    enabled: ref.read(settingsProvider).workoutReminderEnabled,
                    hour: ref.read(settingsProvider).workoutReminderHour,
                    minute: ref.read(settingsProvider).workoutReminderMinute,
                    onChanged: (enabled, hour, minute) async {
                      await ref
                          .read(settingsProvider.notifier)
                          .updateNotificationSettings(
                            workoutEnabled: enabled,
                            workoutHour: hour,
                            workoutMinute: minute,
                          );
                      await NotificationService().rescheduleFromSettings();
                      setDialogState(() {});
                    },
                  ),
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 8),
                  const Text('データ管理',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.download),
                    label: const Text('全データをCSVでエクスポート'),
                    onPressed: () async {
                      Navigator.pop(context);
                      try {
                        await ExportService().exportAll();
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('エクスポートに失敗しました: $e')),
                          );
                        }
                      }
                    },
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
                onPressed: () async {
                  await ref.read(energyProfileProvider.notifier).save(
                        EnergyProfileState(
                          sex: dialogSex,
                          age: int.tryParse(ageController.text) ?? 0,
                          heightCm: double.tryParse(heightController.text) ?? 0,
                          weightKg: double.tryParse(weightController.text) ?? 0,
                          targetWeightKg:
                              double.tryParse(targetWeightController.text) ?? 0,
                          goalWeeks: int.tryParse(weeksController.text) ?? 12,
                          activityLevel: dialogActivity,
                        ),
                      );
                  if (!context.mounted) return;
                  notifier.updateGoals(
                    calories: int.tryParse(calorieController.text) ?? 2000,
                    protein: double.tryParse(proteinController.text) ?? 150,
                    fat: double.tryParse(fatController.text) ?? 60,
                    carbs: double.tryParse(carbsController.text) ?? 200,
                  );
                  Navigator.pop(context);
                },
                child: const Text('保存'),
              ),
            ],
          );
        },
      ),
    );
  }

  String _appliedEnergyBalanceLabel(int delta) {
    if (delta.abs() < 8) {
      return '目標摂取は推定消費とほぼ同水準（体重維持寄り）です';
    }
    if (delta > 0) {
      return '目標摂取は推定消費より +$delta kcal/日（増量寄り）';
    }
    return '目標摂取は推定消費より $delta kcal/日（減量寄り）';
  }

  String _adviceLevelDescription(String level) {
    switch (level) {
      case 'strict':
        return '目標からの乖離を詳細に指摘し、具体的な改善計画を提示します';
      case 'gentle':
        return '良い点を中心に励ましながら、重大な問題のみ優しく提案します';
      default:
        return '良い点と改善点のバランスよく、実践しやすい提案をします';
    }
  }

  Widget _buildReminderRow(
    BuildContext context,
    WidgetRef ref, {
    required String label,
    required bool enabled,
    required int hour,
    required int minute,
    required void Function(bool enabled, int hour, int minute) onChanged,
  }) {
    return Row(
      children: [
        Switch(
          value: enabled,
          onChanged: (v) => onChanged(v, hour, minute),
        ),
        Expanded(
          child: Text(label, style: const TextStyle(fontSize: 13)),
        ),
        TextButton(
          onPressed: () async {
            final t = await showTimePicker(
              context: context,
              initialTime: TimeOfDay(hour: hour, minute: minute),
            );
            if (t != null) onChanged(enabled, t.hour, t.minute);
          },
          child: Text(
            '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  // ── Unified add / edit food dialog ────────────────────────────────────────

  void _showFoodDialog({
    required BuildContext context,
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
                    children: MealType.values.map((t) {
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
                      label: const Text('食品データベースから検索'),
                      onPressed: () => _showFoodSearchDialog(
                        context,
                        (result, grams) {
                          setDialogState(() => fillFromSearch(result, grams));
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

  void _showFoodSearchDialog(
    BuildContext context,
    void Function(FoodSearchResult result, int grams) onSelect,
  ) {
    final searchController = TextEditingController();
    final gramsController = TextEditingController(text: '100');
    final service = FoodSearchService();
    List<FoodSearchResult> results = [];
    bool isSearching = false;
    String? error;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('食品データベース検索'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: searchController,
                          decoration: const InputDecoration(
                            labelText: '食品名（英語が精度高）',
                            hintText: 'chicken breast, rice...',
                          ),
                          onSubmitted: (_) async {
                            setDialogState(() {
                              isSearching = true;
                              error = null;
                            });
                            try {
                              final r =
                                  await service.search(searchController.text);
                              setDialogState(() {
                                results = r;
                                isSearching = false;
                              });
                            } catch (_) {
                              setDialogState(() {
                                error = '検索に失敗しました';
                                isSearching = false;
                              });
                            }
                          },
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.search),
                        onPressed: () async {
                          setDialogState(() {
                            isSearching = true;
                            error = null;
                          });
                          try {
                            final r =
                                await service.search(searchController.text);
                            setDialogState(() {
                              results = r;
                              isSearching = false;
                            });
                          } catch (_) {
                            setDialogState(() {
                              error = '検索に失敗しました';
                              isSearching = false;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Text('摂取量: ', style: TextStyle(fontSize: 13)),
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
                  const SizedBox(height: 8),
                  if (isSearching)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(),
                    )
                  else if (error != null)
                    Text(error!, style: const TextStyle(color: Colors.red))
                  else if (results.isNotEmpty)
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 250),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: results.length,
                        itemBuilder: (context, i) {
                          final r = results[i];
                          return ListTile(
                            dense: true,
                            title: Text(
                              r.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '${r.caloriesPer100g}kcal/100g  '
                              'P:${r.proteinPer100g.toStringAsFixed(1)}g',
                            ),
                            onTap: () {
                              final grams =
                                  int.tryParse(gramsController.text) ?? 100;
                              onSelect(r, grams);
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
                    ),
                ],
              ),
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
                  _showFoodDialog(context: context, mealState: mealState, notifier: notifier);
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('バーコード「$barcode」の商品が見つかりませんでした')),
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
              mealType: item.mealType,
            );
          }
        },
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
                    'プリセットがまだありません\n食事一覧の「プリセット保存」ボタンで追加できます',
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
                    return ListTile(
                      leading: const Icon(Icons.bookmark),
                      title: Text(preset.name),
                      subtitle: Text(
                        '${preset.items.length}品目・${preset.totalCalories} kcal',
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
                                '「${preset.name}」の${preset.items.length}品目を追加しました'),
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
