import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/training_plan.dart';
import '../providers/training_plan_provider.dart';
import '../widgets/training/exercise_motion_demo_sheet.dart';

class TrainingPlanScreen extends ConsumerStatefulWidget {
  const TrainingPlanScreen({super.key});

  @override
  ConsumerState<TrainingPlanScreen> createState() => _TrainingPlanScreenState();
}

class _TrainingPlanScreenState extends ConsumerState<TrainingPlanScreen> {
  // ウィザードの現在ステップ (0-3 = 設定, 4 = 生成結果/一覧)
  int _step = 0;

  // 選択値
  TrainingGoal? _goal;
  final Set<MuscleGroup> _selectedMuscles = {};
  CutStyle _cutStyle = CutStyle.balanced; // ダイエット時のみ使用
  EquipmentOption _equipment = EquipmentOption.fullGym;
  int _daysPerWeek = 3;
  PlanIntensity _intensity = PlanIntensity.moderate;

  // 生成結果
  TrainingPlan? _generatedPlan;

  // 保存済みプラン一覧を表示するか
  bool _showList = false;

  void _nextStep() {
    if (_step < 4) {
      setState(() => _step++);
    } else {
      _generate();
    }
  }

  void _prevStep() {
    if (_generatedPlan != null) {
      setState(() {
        _generatedPlan = null;
        _step = 3;
      });
    } else if (_step > 0) {
      setState(() => _step--);
    } else {
      Navigator.pop(context);
    }
  }

  bool get _isCut => _goal == TrainingGoal.cut;

  bool get _canProceed => switch (_step) {
        0 => _goal != null,
        // cut のとき Step 1 は CutStyle 選択（常にデフォルト値があるので true）
        // それ以外は部位選択（1件以上必要）
        1 => _isCut ? true : _selectedMuscles.isNotEmpty,
        2 => true, // 器具（常にデフォルト値あり）
        3 => true,
        4 => true,
        _ => false,
      };

  Future<void> _generate() async {
    final plan = await ref.read(trainingPlanProvider.notifier).generateAndSave(
          goal: _goal!,
          targetMuscles: _isCut ? [] : _selectedMuscles.toList(),
          cutStyle: _isCut ? _cutStyle : null,
          daysPerWeek: _daysPerWeek,
          intensity: _intensity,
          equipment: _equipment,
        );
    if (plan != null && mounted) {
      setState(() => _generatedPlan = plan);
    }
  }

  @override
  Widget build(BuildContext context) {
    final planState = ref.watch(trainingPlanProvider);

    if (_showList) {
      return _buildListView(context, planState);
    }
    if (planState.isGenerating) {
      return _buildGeneratingView();
    }
    if (_generatedPlan != null) {
      return _buildResultView(context, _generatedPlan!);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('トレーニングプラン作成'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _prevStep,
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.list),
            label: const Text('保存済み'),
            onPressed: () => setState(() => _showList = true),
          ),
        ],
      ),
      body: Column(
        children: [
          _StepIndicator(
            currentStep: _step,
            totalSteps: 5,
            labels: ['目標', _isCut ? 'スタイル' : '部位', '器具', '日数', '強度'],
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: KeyedSubtree(
                key: ValueKey(_step),
                child: switch (_step) {
                  0 => _buildGoalStep(),
                  1 => _isCut ? _buildCutStyleStep() : _buildMuscleStep(),
                  2 => _buildEquipmentStep(),
                  3 => _buildDaysStep(),
                  4 => _buildIntensityStep(),
                  _ => const SizedBox.shrink(),
                },
              ),
            ),
          ),
          if (planState.error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                planState.error!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          _buildBottomBar(context),
        ],
      ),
    );
  }

  // ─── Step 0: ゴール選択 ───────────────────────────────────────────
  Widget _buildGoalStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('目標を選んでください',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('過去の記録や身体データをもとに最適なプランを提案します',
              style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 24),
          ...TrainingGoal.values.map((g) => _GoalCard(
                goal: g,
                selected: _goal == g,
                onTap: () => setState(() => _goal = g),
              )),
        ],
      ),
    );
  }

  // ─── Step 1: ターゲット部位 ───────────────────────────────────────
  Widget _buildMuscleStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('鍛えたい部位を選んでください',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('複数選択できます', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 20),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: MuscleGroup.values.map((m) {
              final selected = m == MuscleGroup.fullBody
                  ? _selectedMuscles.contains(MuscleGroup.fullBody)
                  : _selectedMuscles.contains(m);
              return FilterChip(
                label: Text(m.label),
                selected: selected,
                onSelected: (v) {
                  setState(() {
                    if (m == MuscleGroup.fullBody) {
                      _selectedMuscles.clear();
                      if (v) _selectedMuscles.add(MuscleGroup.fullBody);
                    } else {
                      _selectedMuscles.remove(MuscleGroup.fullBody);
                      if (v) {
                        _selectedMuscles.add(m);
                      } else {
                        _selectedMuscles.remove(m);
                      }
                    }
                  });
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ─── Step 1 (cut時): トレーニングスタイル ────────────────────────────
  Widget _buildCutStyleStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('トレーニングスタイルを選んでください',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline,
                    size: 18,
                    color: Theme.of(context).colorScheme.onSecondaryContainer),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '部位痩せは生理学的に不可能です。全身の体脂肪を落としながら、どんなアプローチで取り組むか選んでください。',
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ...CutStyle.values.map((s) => _CutStyleCard(
                style: s,
                selected: _cutStyle == s,
                onTap: () => setState(() => _cutStyle = s),
              )),
        ],
      ),
    );
  }

  // ─── Step 2: 器具・環境 ────────────────────────────────────────────
  Widget _buildEquipmentStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('使用できる器具・環境を選んでください',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('選択した環境に合わせた種目を提案します',
              style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 20),
          ...EquipmentOption.values.map((e) => _EquipmentCard(
                option: e,
                selected: _equipment == e,
                onTap: () => setState(() => _equipment = e),
              )),
        ],
      ),
    );
  }

  // ─── Step 3: 週のトレーニング日数 ──────────────────────────────────
  Widget _buildDaysStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('週に何日トレーニングしますか？',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('現実的に続けられる日数を選んでください',
              style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [2, 3, 4, 5, 6].map((d) {
              final selected = _daysPerWeek == d;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: GestureDetector(
                  onTap: () => setState(() => _daysPerWeek = d),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 52,
                    height: 64,
                    decoration: BoxDecoration(
                      color: selected
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$d',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: selected
                                ? Theme.of(context).colorScheme.onPrimary
                                : Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          '日',
                          style: TextStyle(
                            fontSize: 12,
                            color: selected
                                ? Theme.of(context).colorScheme.onPrimary
                                : Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 32),
          Center(
            child: Text(
              '週 $_daysPerWeek 日',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Step 3: 強度選択 ─────────────────────────────────────────────
  Widget _buildIntensityStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('トレーニングの強度を選んでください',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('選択した強度に合わせてセット数・重量を調整します',
              style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 24),
          // 選択内容の確認サマリー
          _buildConfirmSummary(),
          const SizedBox(height: 20),
          ...PlanIntensity.values.map((i) => _IntensityCard(
                intensity: i,
                selected: _intensity == i,
                onTap: () => setState(() => _intensity = i),
              )),
        ],
      ),
    );
  }

  Widget _buildConfirmSummary() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('確認', style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          )),
          const SizedBox(height: 6),
          _SummaryRow(
              label: '目標',
              value: _goal != null
                  ? '${_goal!.emoji} ${_goal!.label}'
                  : '未選択'),
          _SummaryRow(
              label: _isCut ? 'スタイル' : '部位',
              value: _isCut
                  ? _cutStyle.label
                  : (_selectedMuscles.isEmpty
                      ? '未選択'
                      : _selectedMuscles.map((m) => m.label).join('・'))),
          _SummaryRow(label: '器具', value: _equipment.label),
          _SummaryRow(label: '日数', value: '週 $_daysPerWeek 日'),
        ],
      ),
    );
  }

  // ─── 生成中画面 ──────────────────────────────────────────────────
  Widget _buildGeneratingView() {
    return Scaffold(
      appBar: AppBar(title: const Text('プランを作成中...')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            const Text('AIがあなた専用のプランを作成しています',
                style: TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            Text(
              '過去の記録を分析して\n最適な種目・重量・セット数を提案します',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  // ─── 生成結果画面 ─────────────────────────────────────────────────
  Widget _buildResultView(BuildContext context, TrainingPlan initial) {
    final plans = ref.watch(trainingPlanProvider).plans;
    TrainingPlan plan = initial;
    for (final p in plans) {
      if (p.id == initial.id) {
        plan = p;
        break;
      }
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(plan.name),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _prevStep,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // バッジ行
          Wrap(
            spacing: 8,
            children: [
              Chip(
                avatar: Text(plan.goal.emoji),
                label: Text(plan.goal.label),
              ),
              Chip(label: Text('週${plan.daysPerWeek}日')),
              Chip(label: Text(plan.intensity.label)),
            ],
          ),
          const SizedBox(height: 12),
          if (plan.totalExerciseCount > 0) ...[
            _PlanCompletionCard(plan: plan),
            const SizedBox(height: 12),
          ],
          // 概要
          if (plan.overview != null && plan.overview!.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline,
                            size: 18,
                            color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 6),
                        Text('プランの概要',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            )),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(plan.overview!, style: const TextStyle(height: 1.6)),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
          // 各日のプラン
          ...plan.days.asMap().entries.map((entry) {
            final idx = entry.key;
            final day = entry.value;
            return _PlanDayCard(
              planId: plan.id,
              day: day,
              dayIndex: idx,
            );
          }),
          const SizedBox(height: 80),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => setState(() => _showList = true),
        icon: const Icon(Icons.check),
        label: const Text('保存済みプランを確認'),
      ),
    );
  }

  // ─── 保存済みプラン一覧 ────────────────────────────────────────────
  Widget _buildListView(BuildContext context, TrainingPlanState state) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('保存済みプラン'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => setState(() {
            _showList = false;
            _generatedPlan = null;
          }),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '新しいプランを作成',
            onPressed: () => setState(() {
              _showList = false;
              _step = 0;
              _goal = null;
              _selectedMuscles.clear();
              _cutStyle = CutStyle.balanced;
              _equipment = EquipmentOption.fullGym;
              _daysPerWeek = 3;
              _intensity = PlanIntensity.moderate;
              _generatedPlan = null;
            }),
          ),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.plans.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.fitness_center,
                          size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      const Text('保存済みのプランはありません',
                          style: TextStyle(color: Colors.grey)),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () => setState(() {
                          _showList = false;
                          _step = 0;
                        }),
                        child: const Text('プランを作成する'),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: state.plans.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final plan = state.plans[index];
                    return _PlanListTile(
                      plan: plan,
                      onDelete: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('プランを削除'),
                            content:
                                Text('「${plan.name}」を削除しますか？'),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.pop(ctx, false),
                                child: const Text('キャンセル'),
                              ),
                              TextButton(
                                onPressed: () =>
                                    Navigator.pop(ctx, true),
                                child: Text('削除',
                                    style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .error)),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await ref
                              .read(trainingPlanProvider.notifier)
                              .deletePlan(plan.id);
                        }
                      },
                    );
                  },
                ),
    );
  }

  // ─── ボトムバー ───────────────────────────────────────────────────
  Widget _buildBottomBar(BuildContext context) {
    final isLast = _step == 4;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(
          children: [
            if (_step > 0)
              OutlinedButton(
                onPressed: _prevStep,
                child: const Text('戻る'),
              ),
            const Spacer(),
            FilledButton.icon(
              onPressed: _canProceed ? _nextStep : null,
              icon: Icon(isLast ? Icons.auto_awesome : Icons.arrow_forward),
              label: Text(isLast ? 'AIでプランを生成' : '次へ'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── ウィジェット群 ─────────────────────────────────────────────────

class _StepIndicator extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final List<String> labels;

  const _StepIndicator({
    required this.currentStep,
    required this.totalSteps,
    required this.labels,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: List.generate(totalSteps * 2 - 1, (i) {
          if (i.isOdd) {
            return Expanded(
              child: Container(
                height: 2,
                color: i ~/ 2 < currentStep
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outlineVariant,
              ),
            );
          }
          final step = i ~/ 2;
          final done = step < currentStep;
          final active = step == currentStep;
          return Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done || active
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.surfaceVariant,
                ),
                child: Center(
                  child: done
                      ? Icon(Icons.check,
                          size: 16,
                          color: Theme.of(context).colorScheme.onPrimary)
                      : Text(
                          '${step + 1}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: active
                                ? Theme.of(context).colorScheme.onPrimary
                                : Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                labels[step],
                style: TextStyle(
                  fontSize: 10,
                  color: active
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey,
                  fontWeight:
                      active ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  final TrainingGoal goal;
  final bool selected;
  final VoidCallback onTap;

  const _GoalCard(
      {required this.goal, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: selected
                ? Theme.of(context).colorScheme.primaryContainer
                : Theme.of(context).colorScheme.surfaceVariant,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.transparent,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              Text(goal.emoji, style: const TextStyle(fontSize: 32)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(goal.label,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check_circle,
                    color: Theme.of(context).colorScheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _CutStyleCard extends StatelessWidget {
  final CutStyle style;
  final bool selected;
  final VoidCallback onTap;

  const _CutStyleCard(
      {required this.style, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: selected
                ? Theme.of(context).colorScheme.primaryContainer
                : Theme.of(context).colorScheme.surfaceVariant,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.transparent,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(style.label,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(style.description,
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey[600])),
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check_circle,
                    color: Theme.of(context).colorScheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _EquipmentCard extends StatelessWidget {
  final EquipmentOption option;
  final bool selected;
  final VoidCallback onTap;

  const _EquipmentCard(
      {required this.option, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: selected
                ? Theme.of(context).colorScheme.primaryContainer
                : Theme.of(context).colorScheme.surfaceVariant,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.transparent,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              Text(option.icon, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(option.label,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(option.description,
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey[600])),
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check_circle,
                    color: Theme.of(context).colorScheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _IntensityCard extends StatelessWidget {
  final PlanIntensity intensity;
  final bool selected;
  final VoidCallback onTap;

  const _IntensityCard(
      {required this.intensity,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected
                ? Theme.of(context).colorScheme.primaryContainer
                : Theme.of(context).colorScheme.surfaceVariant,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.transparent,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(intensity.label,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(intensity.description,
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey[600])),
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check_circle,
                    color: Theme.of(context).colorScheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  const _SummaryRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text(label,
                style: TextStyle(
                    fontSize: 12, color: Colors.grey[600])),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

/// プラン全体の達成度（種目チェックの集計）を表示
class _PlanCompletionCard extends StatelessWidget {
  final TrainingPlan plan;
  const _PlanCompletionCard({required this.plan});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pct = (plan.completionRatio * 100).round();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.track_changes, size: 22, color: scheme.primary),
                const SizedBox(width: 8),
                Text(
                  'プラン達成度',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: scheme.primary,
                  ),
                ),
                const Spacer(),
                Text(
                  '$pct%',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: scheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${plan.completedExerciseCount} / ${plan.totalExerciseCount} 種目を実施済み',
              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: plan.completionRatio.clamp(0.0, 1.0),
                minHeight: 10,
                backgroundColor: scheme.surfaceContainerHighest,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanDayCard extends StatefulWidget {
  final String planId;
  final TrainingPlanDay day;
  final int dayIndex;
  const _PlanDayCard({
    required this.planId,
    required this.day,
    required this.dayIndex,
  });

  @override
  State<_PlanDayCard> createState() => _PlanDayCardState();
}

class _PlanDayCardState extends State<_PlanDayCard> {
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _expanded = widget.dayIndex == 0;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        children: [
          ListTile(
            leading: CircleAvatar(
              child: Text('${widget.dayIndex + 1}'),
            ),
            title: Text(widget.day.label,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(
              '${widget.day.exercises.length} 種目 · '
              '${widget.day.exercises.where((e) => e.completed).length} 完了',
            ),
            trailing: Icon(
                _expanded ? Icons.expand_less : Icons.expand_more),
            onTap: () => setState(() => _expanded = !_expanded),
          ),
          if (_expanded)
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                children: widget.day.exercises
                    .asMap()
                    .entries
                    .map(
                      (e) => _ExerciseRow(
                        planId: widget.planId,
                        dayIndex: widget.dayIndex,
                        exerciseIndex: e.key,
                        exercise: e.value,
                      ),
                    )
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }
}

class _ExerciseRow extends ConsumerWidget {
  final String planId;
  final int dayIndex;
  final int exerciseIndex;
  final TrainingPlanExercise exercise;
  const _ExerciseRow({
    required this.planId,
    required this.dayIndex,
    required this.exerciseIndex,
    required this.exercise,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final done = exercise.completed;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(4, 8, 10, 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: done,
            onChanged: (v) {
              if (v == null) return;
              ref.read(trainingPlanProvider.notifier).setExerciseCompleted(
                    planId,
                    dayIndex,
                    exerciseIndex,
                    v,
                  );
            },
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        exercise.name,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          decoration:
                              done ? TextDecoration.lineThrough : null,
                          color: done ? Colors.grey : null,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: scheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(exercise.type.label,
                          style: const TextStyle(fontSize: 11)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.play_circle_outline_rounded),
                      tooltip: '動きを見る',
                      onPressed: () => showExerciseMotionDemoSheet(
                        context,
                        exerciseName: exercise.name,
                        exerciseType: exercise.type,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 12,
                  children: [
                    _StatChip(
                        icon: Icons.repeat,
                        label:
                            '${exercise.sets}セット × ${exercise.repRange}回'),
                    if (exercise.suggestedWeightKg != null)
                      _StatChip(
                          icon: Icons.fitness_center,
                          label:
                              '目安 ${exercise.suggestedWeightKg!.toStringAsFixed(1)}kg'),
                    _StatChip(
                        icon: Icons.timer_outlined,
                        label: '休憩 ${exercise.restSeconds}秒'),
                  ],
                ),
                if (exercise.note != null && exercise.note!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    exercise.note!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      decoration:
                          done ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _StatChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: Colors.grey[600]),
        const SizedBox(width: 3),
        Text(label,
            style: TextStyle(fontSize: 12, color: Colors.grey[700])),
      ],
    );
  }
}

class _PlanListTile extends StatefulWidget {
  final TrainingPlan plan;
  final VoidCallback onDelete;
  const _PlanListTile({required this.plan, required this.onDelete});

  @override
  State<_PlanListTile> createState() => _PlanListTileState();
}

class _PlanListTileState extends State<_PlanListTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    return Card(
      child: Column(
        children: [
          ListTile(
            isThreeLine: plan.totalExerciseCount > 0,
            leading: Text(plan.goal.emoji,
                style: const TextStyle(fontSize: 24)),
            title: Text(plan.name,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: plan.totalExerciseCount > 0
                ? Text(
                    '${plan.goal.label} · 週${plan.daysPerWeek}日 · ${plan.intensity.label}\n'
                    '達成 ${plan.completedExerciseCount}/${plan.totalExerciseCount} 種目 '
                    '(${(plan.completionRatio * 100).round()}%)',
                  )
                : Text(
                    '${plan.goal.label} · 週${plan.daysPerWeek}日 · ${plan.intensity.label}',
                  ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_expanded
                    ? Icons.expand_less
                    : Icons.expand_more),
              ],
            ),
            onTap: () => setState(() => _expanded = !_expanded),
          ),
          if (_expanded) ...[
            if (plan.totalExerciseCount > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: _PlanCompletionCard(plan: plan),
              ),
            if (plan.overview != null && plan.overview!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(plan.overview!,
                    style: TextStyle(
                        fontSize: 13, color: Colors.grey[600])),
              ),
            ...plan.days.asMap().entries.map((e) => _PlanDayCard(
                  planId: plan.id,
                  day: e.value,
                  dayIndex: e.key,
                )),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    icon: Icon(Icons.delete_outline,
                        color:
                            Theme.of(context).colorScheme.error,
                        size: 18),
                    label: Text('削除',
                        style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .error)),
                    onPressed: widget.onDelete,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
