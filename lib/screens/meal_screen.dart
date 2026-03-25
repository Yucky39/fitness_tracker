import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/advice_provider.dart';
import '../providers/meal_provider.dart';
import '../providers/settings_provider.dart';
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
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddFoodDialog(context, mealState, mealNotifier),
        child: const Icon(Icons.add),
      ),
    );
  }

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
            if (picked != null) {
              notifier.changeDate(picked);
            }
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
          ],
        ),
      ),
    );
  }

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
                    color: Colors.teal.withOpacity(0.1),
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
              Text(
                adviceState.error!,
                style: const TextStyle(color: Colors.red, fontSize: 13),
              ),
            ],
            if (adviceState.adviceText != null) ...[
              const SizedBox(height: 8),
              const Divider(),
              const SizedBox(height: 4),
              Text(
                adviceState.adviceText!,
                style: const TextStyle(fontSize: 14, height: 1.6),
              ),
            ],
            if (adviceState.adviceText == null &&
                adviceState.error == null &&
                !adviceState.isLoading)
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

  Widget _buildFoodList(BuildContext context, MealState state, MealNotifier notifier) {
    if (state.todayItems.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Text('まだ記録がありません'),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: state.todayItems.length,
      itemBuilder: (context, index) {
        final item = state.todayItems[index];
        return Dismissible(
          key: Key(item.id),
          confirmDismiss: (_) async {
            return await showDialog<bool>(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('削除の確認'),
                content: const Text('この記録を削除しますか？'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('キャンセル'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('削除'),
                  ),
                ],
              ),
            ) ??
                false;
          },
          onDismissed: (_) => notifier.deleteFoodItem(item.id),
          background: Container(color: Colors.red),
          child: Card(
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: ListTile(
              title: Text(item.name),
              subtitle: Text('P: ${item.protein}g, F: ${item.fat}g, C: ${item.carbs}g'),
              trailing: Text('${item.calories} kcal'),
            ),
          ),
        );
      },
    );
  }

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

                  // ── Provider selector ──────────────────────────────────
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
                            Text(
                              p.modelLabel,
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
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

                  // ── Advice level ───────────────────────────────────────
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

                  // ── API keys (all providers) ───────────────────────────
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

  void _showAddFoodDialog(BuildContext context, MealState mealState, MealNotifier notifier) {
    final nameController = TextEditingController();
    final calorieController = TextEditingController();
    final proteinController = TextEditingController();
    final fatController = TextEditingController();
    final carbsController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('食事を記録'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (mealState.recentFoods.isNotEmpty) ...[
                    const Text(
                      '最近使った食品',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
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
                              });
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: '食品名'),
                  ),
                  TextField(
                    controller: calorieController,
                    decoration: const InputDecoration(labelText: 'カロリー (kcal)'),
                    keyboardType: TextInputType.number,
                  ),
                  TextField(
                    controller: proteinController,
                    decoration: const InputDecoration(labelText: 'タンパク質 (g)'),
                    keyboardType: TextInputType.number,
                  ),
                  TextField(
                    controller: fatController,
                    decoration: const InputDecoration(labelText: '脂質 (g)'),
                    keyboardType: TextInputType.number,
                  ),
                  TextField(
                    controller: carbsController,
                    decoration: const InputDecoration(labelText: '炭水化物 (g)'),
                    keyboardType: TextInputType.number,
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
                  if (nameController.text.isNotEmpty) {
                    notifier.addFoodItem(
                      name: nameController.text,
                      calories: int.tryParse(calorieController.text) ?? 0,
                      protein: double.tryParse(proteinController.text) ?? 0,
                      fat: double.tryParse(fatController.text) ?? 0,
                      carbs: double.tryParse(carbsController.text) ?? 0,
                    );
                    Navigator.pop(context);
                  }
                },
                child: const Text('追加'),
              ),
            ],
          );
        },
      ),
    );
  }
}
