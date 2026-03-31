import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../models/food_item.dart';
import '../providers/advice_provider.dart';
import '../providers/meal_provider.dart';
import '../providers/settings_provider.dart';
import '../services/meal_image_analysis_service.dart';
import '../widgets/nutrient_bar.dart';

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
                  _buildSummaryCard(mealState),
                  const SizedBox(height: 16),
                  _buildAdviceCard(context, ref, mealState),
                  const SizedBox(height: 8),
                  _buildFoodList(context, mealState, mealNotifier),
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

  Widget _buildSummaryCard(MealState state) {
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
                    '${settings.selectedProvider.label} · ${settings.adviceLevelLabel}',
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
                        tooltip: 'アドバイスを取得',
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

  Widget _buildFoodList(BuildContext context, MealState state, MealNotifier notifier) {
    if (state.todayItems.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Text('まだ記録がありません\n右下の + ボタンで追加できます',
              textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    // Group by meal type in display order
    final grouped = <MealType, List<FoodItem>>{};
    for (final item in state.todayItems) {
      grouped.putIfAbsent(item.mealType, () => []).add(item);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final type in MealType.values)
          if (grouped.containsKey(type)) ...[
            _buildMealTypeHeader(type, grouped[type]!),
            for (final item in grouped[type]!)
              _buildFoodTile(context, item, state, notifier),
          ],
      ],
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
    );
  }

  // ── Goal & settings dialog ─────────────────────────────────────────────────

  void _showGoalSettingDialog(
    BuildContext context,
    WidgetRef ref,
    MealState state,
    MealNotifier notifier,
  ) {
    final calorieController = TextEditingController(text: state.calorieGoal.toString());
    final proteinController = TextEditingController(text: state.proteinGoal.toString());
    final fatController = TextEditingController(text: state.fatGoal.toString());
    final carbsController = TextEditingController(text: state.carbsGoal.toString());

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
                  const Text('栄養目標', style: TextStyle(fontWeight: FontWeight.bold)),
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
                        child: Row(
                          children: [
                            Text(p.label),
                            const SizedBox(width: 8),
                            Text(p.modelLabel,
                                style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (p) {
                      if (p == null) return;
                      ref.read(settingsProvider.notifier).updateSelectedProvider(p);
                      setDialogState(() => currentProvider = p);
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
                  const Text('APIキーはデバイス内にのみ保存されます',
                      style: TextStyle(fontSize: 11, color: Colors.grey)),
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
            ],
          ),
        ),
      ),
    );
  }

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

// ── Photo Analysis Dialog ─────────────────────────────────────────────────

class _PhotoAnalysisDialog extends StatefulWidget {
  final XFile imageFile;
  final String apiKey;
  final AiProviderType provider;
  final void Function(List<AnalyzedFoodItem> items, MealType mealType) onAdd;

  const _PhotoAnalysisDialog({
    required this.imageFile,
    required this.apiKey,
    required this.provider,
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

  @override
  void initState() {
    super.initState();
    _loadAndAnalyze();
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
      constraints: const BoxConstraints(maxHeight: 280),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${_items.length}品目を検出しました',
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 4),
            ..._items.map(_buildItemTile),
          ],
        ),
      ),
    );
  }

  Widget _buildItemTile(AnalyzedFoodItem item) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 3),
      child: CheckboxListTile(
        value: item.selected,
        onChanged: (v) => setState(() => item.selected = v ?? false),
        controlAffinity: ListTileControlAffinity.leading,
        title: Row(
          children: [
            Expanded(
              child: Text(item.name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ),
            Text('${item.calories} kcal', style: const TextStyle(fontSize: 13)),
          ],
        ),
        subtitle: Column(
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
        isThreeLine: true,
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
