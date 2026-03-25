import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/meal_provider.dart';
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
            onPressed: () => _showGoalSettingDialog(context, mealState, mealNotifier),
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
                  _buildSummaryCard(mealState),
                  const SizedBox(height: 24),
                  const Text(
                    '今日の食事',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  _buildFoodList(mealState, mealNotifier),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddFoodDialog(context, mealNotifier),
        child: const Icon(Icons.add),
      ),
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

  Widget _buildFoodList(MealState state, MealNotifier notifier) {
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

  void _showGoalSettingDialog(BuildContext context, MealState state, MealNotifier notifier) {
    final calorieController = TextEditingController(text: state.calorieGoal.toString());
    final proteinController = TextEditingController(text: state.proteinGoal.toString());
    final fatController = TextEditingController(text: state.fatGoal.toString());
    final carbsController = TextEditingController(text: state.carbsGoal.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('目標設定'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
      ),
    );
  }

  void _showAddFoodDialog(BuildContext context, MealNotifier notifier) {
    final nameController = TextEditingController();
    final calorieController = TextEditingController();
    final proteinController = TextEditingController();
    final fatController = TextEditingController();
    final carbsController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('食事を記録'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
      ),
    );
  }
}
