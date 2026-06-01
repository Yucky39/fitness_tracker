import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io' show Platform;

import '../models/energy_profile.dart';
import '../providers/energy_profile_provider.dart';
import '../providers/meal_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/water_provider.dart';
import 'achievements_screen.dart';
import 'faq_screen.dart';
import '../providers/subscription_provider.dart';
import '../services/auth_service.dart';
import '../services/energy_goal_calculator.dart';
import '../services/export_service.dart';
import '../services/notification_service.dart';
import '../widgets/paywall_sheet.dart';
import '../widgets/app_update_dialog.dart';
import '../widgets/source_reference_link.dart';

class ProfileSidebar extends ConsumerWidget {
  final GlobalKey<ScaffoldState> scaffoldKey;

  const ProfileSidebar({super.key, required this.scaffoldKey});

  Future<void> _deleteAccount(BuildContext context) async {
    final passwordController = TextEditingController();
    bool obscure = true;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('アカウント削除'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'アカウントを削除すると、すべてのデータが完全に消去されます。この操作は取り消せません。',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 16),
              const Text('確認のため、パスワードを入力してください',
                  style: TextStyle(fontSize: 13)),
              const SizedBox(height: 8),
              TextField(
                controller: passwordController,
                obscureText: obscure,
                decoration: InputDecoration(
                  labelText: 'パスワード',
                  suffixIcon: IconButton(
                    icon:
                        Icon(obscure ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setDialogState(() => obscure = !obscure),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('削除する'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) {
      passwordController.dispose();
      return;
    }
    final password = passwordController.text;
    if (!context.mounted) {
      passwordController.dispose();
      return;
    }

    try {
      await AuthService().reauthenticate(password);
      await AuthService().deleteAccount();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('アカウントを削除しました')),
        );
      }
    } on Exception catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('削除に失敗しました: $e')),
        );
      }
    } finally {
      passwordController.dispose();
    }
  }

  Future<void> _signOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ログアウト'),
        content: const Text('ログアウトしますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ログアウト'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await AuthService().signOut();
    }
  }

  // ── カロリー・栄養目標設定 ────────────────────────────────────────────────

  void _showCalorieGoalDialog(BuildContext context, WidgetRef ref) {
    final ep = ref.read(energyProfileProvider);
    final mealState = ref.read(mealProvider);
    final waterState = ref.read(waterProvider);
    // ドロワーが閉じると ProfileSidebar がアンマウントされ ref が無効になるため、
    // Notifier への参照をダイアログ表示前に取得しておく。
    final energyNotifier = ref.read(energyProfileProvider.notifier);
    final mealNotifier = ref.read(mealProvider.notifier);
    final waterNotifier = ref.read(waterProvider.notifier);
    var dialogSex = ep.sex;
    var dialogActivity = ep.activityLevel;
    ComputedNutritionGoals? lastComputed;

    final calorieController =
        TextEditingController(text: mealState.calorieGoal.toString());
    final proteinController =
        TextEditingController(text: mealState.proteinGoal.toString());
    final fatController =
        TextEditingController(text: mealState.fatGoal.toString());
    final carbsController =
        TextEditingController(text: mealState.carbsGoal.toString());
    final waterGoalController =
        TextEditingController(text: waterState.dailyGoalMl.toString());
    final ageController =
        TextEditingController(text: ep.age > 0 ? ep.age.toString() : '');
    final heightController = TextEditingController(
        text: ep.heightCm > 0 ? ep.heightCm.toString() : '');
    final weightController = TextEditingController(
        text: ep.weightKg > 0 ? ep.weightKg.toString() : '');
    final targetWeightController = TextEditingController(
        text: ep.targetWeightKg > 0 ? ep.targetWeightKg.toString() : '');
    final weeksController = TextEditingController(
        text: ep.goalWeeks > 0 ? ep.goalWeeks.toString() : '12');

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('カロリー・栄養目標設定'),
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
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey[700], height: 1.35),
                  ),
                  const SourceReferenceLink(compact: true),
                  const SizedBox(height: 10),
                  const Text('性別',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
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
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                  TextField(
                    controller: weightController,
                    decoration: const InputDecoration(labelText: '現在の体重 (kg)'),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                  TextField(
                    controller: targetWeightController,
                    decoration: const InputDecoration(labelText: '目標体重 (kg)'),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
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
                    initialValue: dialogActivity,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    isExpanded: true,
                    items: ActivityLevel.values.map((e) {
                      return DropdownMenuItem(
                        value: e,
                        child:
                            Text(e.label, style: const TextStyle(fontSize: 13)),
                      );
                    }).toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setDialogState(() => dialogActivity = v);
                      }
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
                      final targetW =
                          double.tryParse(targetWeightController.text);
                      final weeks = int.tryParse(weeksController.text);
                      if (age == null || age <= 0 || age > 120) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('有効な年齢を入力してください')),
                        );
                        return;
                      }
                      if (height == null || height < 50 || height > 250) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('身長は50〜250cmの範囲で入力してください')),
                        );
                        return;
                      }
                      if (weight == null || weight < 20 || weight > 300) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('現在体重は20〜300kgの範囲で入力してください')),
                        );
                        return;
                      }
                      if (targetW == null || targetW < 20 || targetW > 300) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('目標体重は20〜300kgの範囲で入力してください')),
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
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
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
                            _appliedEnergyBalanceLabel(
                                lastComputed!.appliedDailyDelta),
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[800]),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '理論上の体重変化ペース: 1日あたり約 ${lastComputed!.dailyEnergyBalance.round()} kcal相当',
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey[600]),
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
                    decoration:
                        const InputDecoration(labelText: '目標カロリー (kcal)'),
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
                  const SizedBox(height: 8),
                  const Divider(),
                  TextField(
                    controller: waterGoalController,
                    decoration: const InputDecoration(
                        labelText: '目標水分摂取量 (ml)', hintText: '例: 2000'),
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
                onPressed: () async {
                  await energyNotifier.save(
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
                  await mealNotifier.updateGoals(
                    calories: int.tryParse(calorieController.text) ?? 2000,
                    protein: double.tryParse(proteinController.text) ?? 150,
                    fat: double.tryParse(fatController.text) ?? 60,
                    carbs: double.tryParse(carbsController.text) ?? 200,
                  );
                  final waterGoal =
                      int.tryParse(waterGoalController.text) ?? 2000;
                  waterNotifier.setGoal(waterGoal);
                  if (!context.mounted) return;
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

  // ── AIキー・トレーニングアドバイス設定 ───────────────────────────────────

  void _showAISettingsDialog(BuildContext context, WidgetRef ref) {
    final initialSettings = ref.read(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);
    final anthropicKeyCtrl =
        TextEditingController(text: initialSettings.anthropicApiKey);
    final openAiKeyCtrl =
        TextEditingController(text: initialSettings.openAiApiKey);
    final geminiKeyCtrl =
        TextEditingController(text: initialSettings.geminiApiKey);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          String currentLevel = settingsNotifier.currentSettings.adviceLevel;
          AiProviderType currentProvider =
              settingsNotifier.currentSettings.selectedProvider;
          String currentModel = settingsNotifier.currentSettings
              .resolvedModelForProvider(
                  settingsNotifier.currentSettings.selectedProvider);

          Widget apiKeyField(
              AiProviderType provider, TextEditingController ctrl) {
            bool obscure = true;
            return StatefulBuilder(
              builder: (context, setFieldState) => TextField(
                controller: ctrl,
                obscureText: obscure,
                decoration: InputDecoration(
                  labelText: '${provider.label} APIキー',
                  hintText: provider.apiKeyHint,
                  suffixIcon: IconButton(
                    icon:
                        Icon(obscure ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setFieldState(() => obscure = !obscure),
                  ),
                ),
                onChanged: (v) => settingsNotifier.updateApiKey(provider, v),
              ),
            );
          }

          return AlertDialog(
            title: const Text('AIキー・トレーニングアドバイス設定'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('AIアドバイス設定',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  const Text('使用するAI', style: TextStyle(fontSize: 13)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<AiProviderType>(
                    initialValue: currentProvider,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: AiProviderType.values.map((p) {
                      return DropdownMenuItem(
                        value: p,
                        child: Text(p.label),
                      );
                    }).toList(),
                    onChanged: (p) {
                      if (p == null) return;
                      settingsNotifier.updateSelectedProvider(p);
                      setDialogState(() {
                        currentProvider = p;
                        currentModel = settingsNotifier.currentSettings
                            .resolvedModelForProvider(p);
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  const Text('使用するモデル', style: TextStyle(fontSize: 13)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    key: ValueKey<String>('ai_model_${currentProvider.name}'),
                    initialValue: currentModel,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: currentProvider.availableModels.map((m) {
                      return DropdownMenuItem(
                        value: m.id,
                        child:
                            Text(m.label, style: const TextStyle(fontSize: 13)),
                      );
                    }).toList(),
                    onChanged: (m) {
                      if (m == null) return;
                      settingsNotifier.updateModel(currentProvider, m);
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
                      settingsNotifier.updateAdviceLevel(selection.first);
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
                        value: settingsNotifier
                            .currentSettings.trainingAdviceEnabled,
                        onChanged: (v) {
                          settingsNotifier.updateTrainingAdviceEnabled(v);
                          setDialogState(() {});
                        },
                      ),
                      const Expanded(
                        child: Text(
                          '各トレーニング記録でAI評価ボタンを表示する',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Divider(),
                  const SizedBox(height: 8),
                  const Text('食事メニュー提案',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Switch(
                        value: settingsNotifier
                            .currentSettings.mealSuggestionEnabled,
                        onChanged: (v) {
                          settingsNotifier.updateMealSuggestionEnabled(v);
                          setDialogState(() {});
                        },
                      ),
                      const Expanded(
                        child: Text(
                          'カロリー・PFC目標に合った食事メニューを提案する',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'オンにすると食事管理画面に「今日の食事メニュー提案」カードが表示されます。'
                    'サプリ・プロテインの記録も考慮して献立を提案します。',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  const Divider(),
                  const SizedBox(height: 8),
                  const Text('コミュニティ食品DB',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Switch(
                        value: settingsNotifier
                            .currentSettings.communityFoodContributeEnabled,
                        onChanged: (v) {
                          settingsNotifier
                              .updateCommunityFoodContributeEnabled(v);
                          setDialogState(() {});
                        },
                      ),
                      const Expanded(
                        child: Text(
                          '手動入力した食品をコミュニティに共有する',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '食品名・栄養素のみ共有されます（個人情報は含まれません）',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
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

  // ── リマインダー通知 ──────────────────────────────────────────────────────

  void _showReminderDialog(BuildContext context, WidgetRef _) {
    showDialog(
      context: context,
      // ダイアログを開くと Drawer（ProfileSidebar）はアンマウントされ、その
      // WidgetRef は無効になる。そのため Consumer でダイアログ自身の要素に
      // 紐づく有効な ref を取得して使用する（ref.watch により自動再描画）。
      builder: (context) => Consumer(
        builder: (context, ref, child) {
          final settings = ref.watch(settingsProvider);
          return AlertDialog(
            title: const Text('リマインダー通知'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildReminderRow(
                    context,
                    ref,
                    label: '食事記録リマインダー',
                    enabled: settings.mealReminderEnabled,
                    hour: settings.mealReminderHour,
                    minute: settings.mealReminderMinute,
                    onChanged: (enabled, hour, minute) async {
                      await ref
                          .read(settingsProvider.notifier)
                          .updateNotificationSettings(
                            mealEnabled: enabled,
                            mealHour: hour,
                            mealMinute: minute,
                          );
                      await NotificationService().rescheduleFromSettings();
                    },
                  ),
                  const SizedBox(height: 8),
                  _buildReminderRow(
                    context,
                    ref,
                    label: 'トレーニングリマインダー',
                    enabled: settings.workoutReminderEnabled,
                    hour: settings.workoutReminderHour,
                    minute: settings.workoutReminderMinute,
                    onChanged: (enabled, hour, minute) async {
                      await ref
                          .read(settingsProvider.notifier)
                          .updateNotificationSettings(
                            workoutEnabled: enabled,
                            workoutHour: hour,
                            workoutMinute: minute,
                          );
                      await NotificationService().rescheduleFromSettings();
                    },
                  ),
                  const SizedBox(height: 8),
                  const Divider(),
                  const SizedBox(height: 4),
                  _buildWaterReminderSection(
                    context,
                    ref,
                    settings,
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

  Widget _buildWaterReminderSection(
    BuildContext context,
    WidgetRef ref,
    SettingsState settings,
  ) {
    Future<void> save({
      bool? enabled,
      int? intervalMinutes,
      int? startHour,
      int? endHour,
    }) async {
      await ref.read(settingsProvider.notifier).updateNotificationSettings(
            waterEnabled: enabled,
            waterIntervalMinutes: intervalMinutes,
            waterStartHour: startHour,
            waterEndHour: endHour,
          );
      await NotificationService().rescheduleFromSettings();
    }

    const intervalOptions = [30, 60, 90, 120, 180];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // トグル行
        Row(
          children: [
            Switch(
              value: settings.waterReminderEnabled,
              onChanged: (v) => save(enabled: v),
            ),
            const Expanded(
              child: Text('水分補給リマインダー', style: TextStyle(fontSize: 13)),
            ),
          ],
        ),

        // 詳細設定（有効時のみ）
        if (settings.waterReminderEnabled) ...[
          const SizedBox(height: 8),

          // 間隔
          Row(
            children: [
              const SizedBox(width: 8),
              const Text('間隔', style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(width: 12),
              DropdownButton<int>(
                value: settings.waterReminderIntervalMinutes,
                isDense: true,
                items: intervalOptions
                    .map(
                      (m) => DropdownMenuItem(
                        value: m,
                        child: Text(
                          m < 60 ? '$m分' : '${m ~/ 60}時間',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) save(intervalMinutes: v);
                },
              ),
            ],
          ),
          const SizedBox(height: 4),

          // 時間帯
          Row(
            children: [
              const SizedBox(width: 8),
              const Text('時間帯', style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(width: 8),
              TextButton(
                style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact, padding: EdgeInsets.zero),
                onPressed: () async {
                  final t = await showTimePicker(
                    context: context,
                    initialTime:
                        TimeOfDay(hour: settings.waterReminderStartHour, minute: 0),
                    helpText: '開始時刻',
                  );
                  if (t != null) save(startHour: t.hour);
                },
                child: Text(
                  '${settings.waterReminderStartHour.toString().padLeft(2, '0')}:00',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              const Text('〜', style: TextStyle(fontSize: 13)),
              TextButton(
                style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact, padding: EdgeInsets.zero),
                onPressed: () async {
                  final t = await showTimePicker(
                    context: context,
                    initialTime:
                        TimeOfDay(hour: settings.waterReminderEndHour, minute: 0),
                    helpText: '終了時刻',
                  );
                  if (t != null) save(endHour: t.hour);
                },
                child: Text(
                  '${settings.waterReminderEndHour.toString().padLeft(2, '0')}:00',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ],
          ),

          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 4),
            child: Text(
              '${settings.waterReminderStartHour}:00〜${settings.waterReminderEndHour}:00の間、'
              '${settings.waterReminderIntervalMinutes < 60 ? '${settings.waterReminderIntervalMinutes}分' : '${settings.waterReminderIntervalMinutes ~/ 60}時間'}ごとに通知',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ),
        ],
      ],
    );
  }

  // ── データ管理 ────────────────────────────────────────────────────────────

  void _showDataManagementDialog(BuildContext context, WidgetRef ref) {
    final parentContext = context;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('データ管理'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '記録した食事・トレーニング・進捗データをCSVファイルとして書き出します。',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              icon: const Icon(Icons.download),
              label: const Text('全データをCSVでエクスポート'),
              onPressed: () async {
                Navigator.pop(dialogContext);
                try {
                  await ExportService().exportAll();
                } catch (e) {
                  if (parentContext.mounted) {
                    ScaffoldMessenger.of(parentContext).showSnackBar(
                      SnackBar(content: Text('エクスポートに失敗しました: $e')),
                    );
                  }
                }
              },
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Text(
              'アカウントを削除すると、デバイス内のローカルデータとクラウド同期データを完全に削除します。',
              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.delete_forever, color: Colors.red),
              label: const Text('アカウントと全データを削除'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
              ),
              onPressed: () {
                Navigator.pop(dialogContext);
                _deleteAccount(parentContext);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  // ── サブスクリプション情報ダイアログ ─────────────────────────────────────

  void _showSubscriptionInfoDialog(BuildContext context, WidgetRef ref) {
    final subscription = ref.read(subscriptionProvider);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.workspace_premium_outlined,
                color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            const Text('プレミアムプラン'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoRow('ステータス', 'アクティブ'),
            if (subscription.productId != null)
              _infoRow(
                'プラン',
                subscription.productId!.contains('annual') ? '年額プラン' : '月額プラン',
              ),
            if (subscription.expiresAt != null)
              _infoRow('次回更新', _formatDate(subscription.expiresAt!)),
            if (subscription.platform != null)
              _infoRow('ストア',
                  subscription.platform == 'ios' ? 'App Store' : 'Google Play'),
            const SizedBox(height: 12),
            Text(
              'サブスクリプションの解約・管理は各ストアのアカウント設定から行えます。',
              style:
                  TextStyle(fontSize: 12, color: Colors.grey[600], height: 1.5),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label,
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ),
          Expanded(
            child: Text(value,
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  // ── ヘルパー ──────────────────────────────────────────────────────────────

  String _formatDate(DateTime dt) {
    return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}';
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

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final email = AuthService().userEmail ?? '';
    final subscription = ref.watch(subscriptionProvider);
    final isSubscribed = subscription.hasActiveAccess;

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── ユーザー情報ヘッダー ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Row(
                children: [
                  const Icon(Icons.account_circle,
                      size: 48, color: Colors.teal),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          email,
                          style: const TextStyle(fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (isSubscribed) ...[
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(Icons.auto_awesome_rounded,
                                  size: 12,
                                  color: Theme.of(context).colorScheme.primary),
                              const SizedBox(width: 4),
                              Text(
                                'プレミアム',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // ── サブスクリプションバナー（未加入時） ──
            if (!isSubscribed)
              InkWell(
                onTap: () {
                  scaffoldKey.currentState?.closeEndDrawer();
                  PaywallSheet.show(context);
                },
                child: Container(
                  margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.primaryContainer,
                        Theme.of(context).colorScheme.secondaryContainer,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.auto_awesome_rounded,
                          size: 20,
                          color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'プレミアムプランを試す',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onPrimaryContainer,
                              ),
                            ),
                            Text(
                              'AI機能が自動で使えるようになります',
                              style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onPrimaryContainer,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right,
                          color: Theme.of(context).colorScheme.primary),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 4),

            // ── セクションラベル ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Text(
                'プロフィール設定',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[600],
                  letterSpacing: 0.5,
                ),
              ),
            ),

            // ── カロリー・栄養目標設定 ──
            ListTile(
              leading: const Icon(Icons.calculate_outlined),
              title: const Text('カロリー・栄養目標設定'),
              trailing:
                  const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
              onTap: () {
                final ctx = scaffoldKey.currentContext!;
                scaffoldKey.currentState?.closeEndDrawer();
                _showCalorieGoalDialog(ctx, ref);
              },
            ),

            // ── AIキー・トレーニングアドバイス設定（サブスク未加入時のみAPIキー設定を表示） ──
            ListTile(
              leading: const Icon(Icons.psychology_outlined),
              title: Text(isSubscribed ? 'AIアドバイス設定' : 'AIキー・トレーニングアドバイス設定'),
              trailing:
                  const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
              onTap: () {
                final ctx = scaffoldKey.currentContext!;
                scaffoldKey.currentState?.closeEndDrawer();
                _showAISettingsDialog(ctx, ref);
              },
            ),

            // ── サブスクリプション管理（加入済みのみ） ──
            if (isSubscribed)
              ListTile(
                leading: Icon(Icons.workspace_premium_outlined,
                    color: Theme.of(context).colorScheme.primary),
                title: const Text('プレミアムプラン'),
                subtitle: subscription.expiresAt != null
                    ? Text(
                        '次回更新: ${_formatDate(subscription.expiresAt!)}',
                        style:
                            const TextStyle(fontSize: 11, color: Colors.grey),
                      )
                    : null,
                trailing: const Icon(Icons.chevron_right,
                    size: 20, color: Colors.grey),
                onTap: () {
                  scaffoldKey.currentState?.closeEndDrawer();
                  _showSubscriptionInfoDialog(context, ref);
                },
              ),

            // ── リマインダー通知 ──
            ListTile(
              leading: const Icon(Icons.notifications_outlined),
              title: const Text('リマインダー通知'),
              trailing:
                  const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
              onTap: () {
                final ctx = scaffoldKey.currentContext!;
                scaffoldKey.currentState?.closeEndDrawer();
                _showReminderDialog(ctx, ref);
              },
            ),

            // ── データ管理 ──
            ListTile(
              leading: const Icon(Icons.storage_outlined),
              title: const Text('データ管理'),
              trailing:
                  const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
              onTap: () {
                final ctx = scaffoldKey.currentContext!;
                scaffoldKey.currentState?.closeEndDrawer();
                _showDataManagementDialog(ctx, ref);
              },
            ),

            if (Platform.isAndroid)
              ListTile(
                leading: const Icon(Icons.system_update_alt_outlined),
                title: const Text('アプリ更新'),
                trailing: const Icon(Icons.chevron_right,
                    size: 20, color: Colors.grey),
                onTap: () {
                  final ctx = scaffoldKey.currentContext!;
                  scaffoldKey.currentState?.closeEndDrawer();
                  showAppUpdateDialog(ctx);
                },
              ),

            const Spacer(),
            const Divider(height: 1),

            // ── よくある質問 ──
            ListTile(
              leading: const Icon(Icons.help_outline),
              title: const Text('よくある質問'),
              trailing:
                  const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const FaqScreen()),
                );
              },
            ),
            const Divider(height: 1),

            // ── バッジ・実績 ──
            ListTile(
              leading: const Icon(Icons.emoji_events_rounded),
              title: const Text('バッジ・実績'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const _AchievementsWrapper(),
                  ),
                );
              },
            ),
            const Divider(height: 1),

            // ── ログアウト ──
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('ログアウト'),
              onTap: () {
                final ctx = scaffoldKey.currentContext!;
                scaffoldKey.currentState?.closeEndDrawer();
                _signOut(ctx);
              },
            ),

            // ── アカウント削除 ──
            ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: const Text('アカウント削除', style: TextStyle(color: Colors.red)),
              onTap: () {
                final ctx = scaffoldKey.currentContext!;
                scaffoldKey.currentState?.closeEndDrawer();
                _deleteAccount(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _AchievementsWrapper extends ConsumerWidget {
  const _AchievementsWrapper();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const AchievementsScreen();
  }
}
