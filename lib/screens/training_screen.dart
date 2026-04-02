import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/training_log.dart';
import '../providers/energy_profile_provider.dart';
import '../providers/training_provider.dart';
import '../services/health_service.dart';
import '../services/training_calorie_calculator.dart';

class TrainingScreen extends ConsumerWidget {
  const TrainingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trainingState = ref.watch(trainingProvider);
    final trainingNotifier = ref.read(trainingProvider.notifier);
    final bodyWeightKg = ref.watch(energyProfileProvider).weightKg;
    final effectiveBw = bodyWeightKg > 0
        ? bodyWeightKg
        : TrainingCalorieCalculator.defaultBodyWeightKg;

    return Scaffold(
      appBar: AppBar(
        title: const Text('トレーニング記録'),
        actions: [
          if (HealthService.isSupported)
            IconButton(
              icon: const Icon(Icons.health_and_safety_outlined),
              tooltip: 'ヘルスケアから取り込む',
              onPressed: () => _importFromHealth(context, ref, trainingNotifier),
            ),
        ],
      ),
      body: trainingState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : trainingState.logs.isEmpty
              ? const Center(
                  child: Text('まだ記録がありません\n右下の + ボタンで追加できます',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey)))
              : _buildBody(context, ref, trainingState, trainingNotifier, effectiveBw),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showTrainingDialog(
          context: context,
          ref: ref,
          notifier: trainingNotifier,
          bodyWeightKg: effectiveBw,
        ),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    TrainingState state,
    TrainingNotifier notifier,
    double bodyWeightKg,
  ) {
    final todayLogs = state.todayLogs;

    return CustomScrollView(
      slivers: [
        // ── Today summary ───────────────────────────────────────────────
        if (todayLogs.isNotEmpty)
          SliverToBoxAdapter(
            child: _buildTodaySummary(context, todayLogs, bodyWeightKg),
          ),

        // ── Log list ────────────────────────────────────────────────────
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final log = state.logs[index];
              final isPr = notifier.isPersonalRecord(log);
              final kcal = TrainingNotifier.estimateCalories(log,
                  bodyWeightKg: bodyWeightKg);

              return _TrainingLogCard(
                log: log,
                isPr: isPr,
                estimatedKcal: kcal,
                bodyWeightKg: bodyWeightKg,
                onEdit: () => _showTrainingDialog(
                  context: context,
                  ref: ref,
                  notifier: notifier,
                  existingLog: log,
                  bodyWeightKg: bodyWeightKg,
                ),
                onDelete: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('削除の確認'),
                      content: const Text('この記録を削除しますか？'),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('キャンセル')),
                        TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('削除')),
                      ],
                    ),
                  );
                  if (ok == true) notifier.deleteLog(log.id);
                },
              );
            },
            childCount: state.logs.length,
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ],
    );
  }

  // ── Today's session summary ──────────────────────────────────────────────

  Widget _buildTodaySummary(
      BuildContext context, List<TrainingLog> todayLogs, double bodyWeightKg) {
    final totalKcal = TrainingCalorieCalculator.total(todayLogs,
        bodyWeightKg: bodyWeightKg);
    final cardioLogs =
        todayLogs.where((l) => l.exerciseType == ExerciseType.cardio).toList();
    final strengthLogs =
        todayLogs.where((l) => l.exerciseType != ExerciseType.cardio).toList();
    final totalVolume =
        strengthLogs.fold(0.0, (s, l) => s + l.totalVolume);
    final totalDistanceKm =
        cardioLogs.fold(0.0, (s, l) => s + l.distanceKm);
    final exerciseCount =
        todayLogs.map((l) => l.exerciseName).toSet().length;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.deepOrange.shade400,
            Colors.orange.shade300,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '今日のセッション',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _summaryItem('消費カロリー', '${totalKcal.round()} kcal',
                  Icons.local_fire_department, '目安値'),
              if (totalVolume > 0)
                _summaryItem(
                    '総ボリューム',
                    totalVolume >= 1000
                        ? '${(totalVolume / 1000).toStringAsFixed(1)} t'
                        : '${totalVolume.round()} kg',
                    Icons.fitness_center,
                    '重量×回数×セット'),
              if (totalDistanceKm > 0)
                _summaryItem(
                    '走行距離',
                    '${totalDistanceKm.toStringAsFixed(1)} km',
                    Icons.directions_run,
                    '有酸素合計'),
              _summaryItem('種目数', '$exerciseCount 種目',
                  Icons.list_alt_outlined, ''),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryItem(
      String label, String value, IconData icon, String sub) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15)),
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 11)),
        if (sub.isNotEmpty)
          Text(sub,
              style: const TextStyle(color: Colors.white54, fontSize: 10)),
      ],
    );
  }

  // ── HealthKit / Health Connect import ────────────────────────────────────

  Future<void> _importFromHealth(
    BuildContext context,
    WidgetRef ref,
    TrainingNotifier notifier,
  ) async {
    final granted = await HealthService.requestPermissions();
    if (!context.mounted) return;

    if (!granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ヘルスケアへのアクセスが許可されていません')),
      );
      return;
    }

    final workouts = await HealthService.fetchRecentWorkouts(days: 30);
    if (!context.mounted) return;

    if (workouts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('直近30日間にワークアウト記録がありません')),
      );
      return;
    }

    // 既存ログの日時セットを構築（重複インポート防止）
    final existingDates = ref
        .read(trainingProvider)
        .logs
        .where((l) => l.note == 'ヘルスケアから取得')
        .map((l) =>
            '${l.exerciseName}_${DateFormat('yyyyMMddHHmm').format(l.date)}')
        .toSet();

    final newWorkouts = workouts.where((w) {
      final key =
          '${w.exerciseName}_${DateFormat('yyyyMMddHHmm').format(w.date)}';
      return !existingDates.contains(key);
    }).toList();

    if (!context.mounted) return;

    if (newWorkouts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('新しいワークアウト記録はありません（すでに取り込み済み）')),
      );
      return;
    }

    // 確認ダイアログ
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('ヘルスケアから取り込む'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${newWorkouts.length} 件のワークアウトが見つかりました。取り込みますか？'),
            const SizedBox(height: 12),
            ...newWorkouts.take(5).map((w) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      const Icon(Icons.directions_run, size: 14,
                          color: Colors.teal),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${w.exerciseName}  '
                          '${w.durationMinutes}分'
                          '${w.distanceKm > 0 ? '  ${w.distanceKm.toStringAsFixed(1)}km' : ''}'
                          '  ${DateFormat('M/d').format(w.date)}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                )),
            if (newWorkouts.length > 5)
              Text('…他 ${newWorkouts.length - 5} 件',
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('キャンセル')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('取り込む')),
        ],
      ),
    );

    if (ok != true || !context.mounted) return;

    for (final w in newWorkouts) {
      await notifier.addLogFromHealth(w);
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${newWorkouts.length} 件を取り込みました')),
      );
    }
  }

  // ── Add / Edit dialog ────────────────────────────────────────────────────

  void _showTrainingDialog({
    required BuildContext context,
    required WidgetRef ref,
    required TrainingNotifier notifier,
    TrainingLog? existingLog,
    required double bodyWeightKg,
  }) {
    final isEdit = existingLog != null;
    final weightController = TextEditingController(
        text: isEdit && existingLog.weight > 0
            ? existingLog.weight.toString()
            : '');
    final repsController = TextEditingController(
        text: isEdit ? existingLog.reps.toString() : '');
    final setsController = TextEditingController(
        text: isEdit ? existingLog.sets.toString() : '');
    final intervalController = TextEditingController(
        text: isEdit ? existingLog.interval.toString() : '');
    final distanceController = TextEditingController(
        text: isEdit && existingLog.distanceKm > 0
            ? existingLog.distanceKm.toString()
            : '');
    final durationController = TextEditingController(
        text: isEdit && existingLog.durationMinutes > 0
            ? existingLog.durationMinutes.toString()
            : '');
    final noteController =
        TextEditingController(text: isEdit ? existingLog.note : '');

    String exerciseName = existingLog?.exerciseName ?? '';
    ExerciseType exerciseType =
        existingLog?.exerciseType ?? ExerciseType.freeWeight;

    final allExerciseNames = [
      for (final list in ExercisePresets.byCategory.values) ...list
    ];
    final recentExerciseNames = ref
        .read(trainingProvider)
        .logs
        .map((l) => l.exerciseName)
        .toSet()
        .toList()
      ..sort();
    final suggestions = {
      ...recentExerciseNames,
      ...allExerciseNames
    }.toList();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          TrainingLog? previousLog;
          double previewKcal = 0;

          void updatePreview() {
            if (exerciseType == ExerciseType.cardio) {
              final dur = int.tryParse(durationController.text) ?? 0;
              previewKcal = TrainingCalorieCalculator.estimate(
                weight: 0,
                reps: 0,
                sets: 0,
                intervalSec: 0,
                exerciseType: ExerciseType.cardio,
                bodyWeightKg: bodyWeightKg,
                exerciseName: exerciseName,
                durationMinutes: dur,
              );
            } else {
              final w = double.tryParse(weightController.text) ?? 0;
              final r = int.tryParse(repsController.text) ?? 0;
              final s = int.tryParse(setsController.text) ?? 0;
              final iv = int.tryParse(intervalController.text) ?? 0;
              previewKcal = TrainingCalorieCalculator.estimate(
                weight: w,
                reps: r,
                sets: s,
                intervalSec: iv,
                exerciseType: exerciseType,
                bodyWeightKg: bodyWeightKg,
              );
            }
          }

          void fillFromPreviousLog(String name) {
            final prev =
                notifier.getPreviousLog(name, excludeId: existingLog?.id);
            if (prev != null) {
              setState(() {
                previousLog = prev;
                if (prev.exerciseType == ExerciseType.cardio) {
                  distanceController.text = prev.distanceKm > 0
                      ? prev.distanceKm.toString()
                      : '';
                  durationController.text = prev.durationMinutes > 0
                      ? prev.durationMinutes.toString()
                      : '';
                } else {
                  weightController.text = prev.weight.toString();
                  repsController.text = prev.reps.toString();
                  setsController.text = prev.sets.toString();
                  intervalController.text = prev.interval.toString();
                }
                exerciseType = prev.exerciseType;
                updatePreview();
              });
            } else {
              setState(() {
                previousLog = null;
                exerciseType = ExercisePresets.inferType(name);
              });
            }
          }

          updatePreview();

          final isCardio = exerciseType == ExerciseType.cardio;

          return AlertDialog(
            title: Text(isEdit ? 'トレーニングを編集' : 'トレーニングを記録'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Exercise name ────────────────────────────────────
                  Autocomplete<String>(
                    initialValue: TextEditingValue(text: exerciseName),
                    optionsBuilder: (v) {
                      exerciseName = v.text;
                      if (v.text.isEmpty) return suggestions.take(20);
                      return suggestions.where((n) =>
                          n.toLowerCase().contains(v.text.toLowerCase()));
                    },
                    onSelected: (sel) {
                      exerciseName = sel;
                      fillFromPreviousLog(sel);
                    },
                    fieldViewBuilder:
                        (ctx, controller, focusNode, onFieldSubmitted) {
                      return TextField(
                        controller: controller,
                        focusNode: focusNode,
                        decoration: const InputDecoration(labelText: '種目名'),
                        onChanged: (v) {
                          exerciseName = v;
                          exerciseType = ExercisePresets.inferType(v);
                          setState(updatePreview);
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 10),

                  // ── Exercise type ────────────────────────────────────
                  const Text('器具・種別',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    children: ExerciseType.values.map((t) {
                      return ChoiceChip(
                        label: Text(t.label),
                        selected: exerciseType == t,
                        onSelected: (_) => setState(() {
                          exerciseType = t;
                          updatePreview();
                        }),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _exerciseTypeHint(exerciseType),
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),

                  // ── Previous log hint ────────────────────────────────
                  if (previousLog != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.history, size: 14,
                              color: Colors.blue),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              previousLog!.exerciseType == ExerciseType.cardio
                                  ? '前回: ${previousLog!.durationMinutes}分'
                                    '${previousLog!.distanceKm > 0 ? '  ${previousLog!.distanceKm.toStringAsFixed(1)}km' : ''}'
                                    '  (${DateFormat('M/d').format(previousLog!.date)})'
                                  : '前回: ${previousLog!.weight}kg × ${previousLog!.reps}回 × ${previousLog!.sets}セット'
                                    '  (${DateFormat('M/d').format(previousLog!.date)})',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.blue),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 8),

                  // ── Cardio: distance + duration ──────────────────────
                  if (isCardio) ...[
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: distanceController,
                            decoration:
                                const InputDecoration(labelText: '距離 (km)'),
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            onChanged: (_) => setState(updatePreview),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: durationController,
                            decoration:
                                const InputDecoration(labelText: '時間 (分)'),
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setState(updatePreview),
                          ),
                        ),
                      ],
                    ),
                  ],

                  // ── Resistance: weight / reps / sets / interval ──────
                  if (!isCardio) ...[
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: weightController,
                            decoration: InputDecoration(
                              labelText:
                                  exerciseType == ExerciseType.bodyweight
                                      ? '追加重量 (kg)'
                                      : '重量 (kg)',
                              hintText:
                                  exerciseType == ExerciseType.bodyweight
                                      ? '0 = 自体重のみ'
                                      : '',
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            onChanged: (_) => setState(updatePreview),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: repsController,
                            decoration:
                                const InputDecoration(labelText: '回数'),
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setState(updatePreview),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: setsController,
                            decoration:
                                const InputDecoration(labelText: 'セット数'),
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setState(updatePreview),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: intervalController,
                            decoration: const InputDecoration(
                                labelText: 'インターバル (秒)'),
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setState(updatePreview),
                          ),
                        ),
                      ],
                    ),
                  ],

                  TextField(
                    controller: noteController,
                    decoration: const InputDecoration(labelText: 'メモ'),
                  ),
                  const SizedBox(height: 14),

                  // ── Calorie preview ──────────────────────────────────
                  if (previewKcal > 0)
                    _CaloriePreviewChip(
                      kcal: previewKcal,
                      isCardio: isCardio,
                      weight: double.tryParse(weightController.text) ?? 0,
                      reps: int.tryParse(repsController.text) ?? 0,
                      sets: int.tryParse(setsController.text) ?? 0,
                      exerciseType: exerciseType,
                      distanceKm:
                          double.tryParse(distanceController.text) ?? 0,
                      durationMinutes:
                          int.tryParse(durationController.text) ?? 0,
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('キャンセル')),
              TextButton(
                onPressed: () {
                  if (exerciseName.isEmpty) return;
                  if (isCardio) {
                    final dist =
                        double.tryParse(distanceController.text) ?? 0;
                    final dur =
                        int.tryParse(durationController.text) ?? 0;
                    if (isEdit) {
                      notifier.updateLog(existingLog.copyWith(
                        exerciseName: exerciseName,
                        exerciseType: exerciseType,
                        weight: 0,
                        reps: 0,
                        sets: 0,
                        interval: 0,
                        distanceKm: dist,
                        durationMinutes: dur,
                        note: noteController.text,
                      ));
                    } else {
                      notifier.addLog(
                        exerciseName: exerciseName,
                        exerciseType: exerciseType,
                        weight: 0,
                        reps: 0,
                        sets: 0,
                        interval: 0,
                        distanceKm: dist,
                        durationMinutes: dur,
                        note: noteController.text,
                      );
                    }
                  } else {
                    final w = double.tryParse(weightController.text) ?? 0;
                    final r = int.tryParse(repsController.text) ?? 0;
                    final s = int.tryParse(setsController.text) ?? 0;
                    final iv = int.tryParse(intervalController.text) ?? 0;
                    if (isEdit) {
                      notifier.updateLog(existingLog.copyWith(
                        exerciseName: exerciseName,
                        exerciseType: exerciseType,
                        weight: w,
                        reps: r,
                        sets: s,
                        interval: iv,
                        distanceKm: 0,
                        durationMinutes: 0,
                        note: noteController.text,
                      ));
                    } else {
                      notifier.addLog(
                        exerciseName: exerciseName,
                        exerciseType: exerciseType,
                        weight: w,
                        reps: r,
                        sets: s,
                        interval: iv,
                        note: noteController.text,
                      );
                    }
                  }
                  Navigator.pop(context);
                },
                child: Text(isEdit ? '保存' : '記録'),
              ),
            ],
          );
        },
      ),
    );
  }

  String _exerciseTypeHint(ExerciseType type) {
    switch (type) {
      case ExerciseType.freeWeight:
        return 'バーベル・ダンベル等。実際に持ち上げる重量を入力してください。';
      case ExerciseType.machine:
        return 'ケーブル・マシン等。スタック重量を入力してください。';
      case ExerciseType.bodyweight:
        return '体重を利用する種目。追加ウェイトがあれば入力（なければ0）。';
      case ExerciseType.cardio:
        return '器具不要の有酸素運動。距離と時間を入力してください。';
    }
  }
}

// ── Training log card ──────────────────────────────────────────────────────

class _TrainingLogCard extends StatelessWidget {
  final TrainingLog log;
  final bool isPr;
  final double estimatedKcal;
  final double bodyWeightKg;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _TrainingLogCard({
    required this.log,
    required this.isPr,
    required this.estimatedKcal,
    required this.bodyWeightKg,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isCardio = log.exerciseType == ExerciseType.cardio;
    final oneRm =
        isCardio ? 0.0 : TrainingNotifier.oneRepMax(log.weight, log.reps);
    final volumeLabel = log.totalVolume >= 1000
        ? '${(log.totalVolume / 1000).toStringAsFixed(1)} t'
        : '${log.totalVolume.round()} kg';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──────────────────────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Exercise type badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _typeColor(log.exerciseType)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      log.exerciseType.label,
                      style: TextStyle(
                          fontSize: 10,
                          color: _typeColor(log.exerciseType),
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      log.exerciseName,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                  if (isPr)
                    const Tooltip(
                      message: '自己ベスト（最大重量）更新！',
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.emoji_events,
                              color: Colors.amber, size: 18),
                          SizedBox(width: 2),
                          Text('PR',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.amber,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 20),
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                          value: 'edit',
                          child: Row(children: [
                            Icon(Icons.edit, size: 18),
                            SizedBox(width: 8),
                            Text('編集')
                          ])),
                      const PopupMenuItem(
                          value: 'delete',
                          child: Row(children: [
                            Icon(Icons.delete_outline,
                                size: 18, color: Colors.red),
                            SizedBox(width: 8),
                            Text('削除',
                                style: TextStyle(color: Colors.red))
                          ])),
                    ],
                    onSelected: (v) {
                      if (v == 'edit') onEdit();
                      if (v == 'delete') onDelete();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // ── Main metrics ────────────────────────────────────────
              if (isCardio)
                Wrap(
                  spacing: 16,
                  runSpacing: 4,
                  children: [
                    if (log.distanceKm > 0)
                      _metricText(
                          '${log.distanceKm.toStringAsFixed(2)} km', '距離'),
                    if (log.durationMinutes > 0)
                      _metricText('${log.durationMinutes} 分', '時間'),
                    if (log.paceMinPerKm != null)
                      _metricText(
                          _formatPace(log.paceMinPerKm!), 'ペース/km'),
                  ],
                )
              else
                Wrap(
                  spacing: 16,
                  runSpacing: 4,
                  children: [
                    _metricText(
                      log.exerciseType == ExerciseType.bodyweight &&
                              log.weight == 0
                          ? '自体重'
                          : '${log.weight} kg',
                      '重量',
                    ),
                    _metricText('${log.reps} 回', '回数'),
                    _metricText('${log.sets} set', 'セット'),
                    if (log.interval > 0)
                      _metricText('${log.interval} 秒', 'インターバル'),
                  ],
                ),
              const SizedBox(height: 8),

              // ── Derived metrics ─────────────────────────────────────
              Row(
                children: [
                  _statChip(Icons.local_fire_department,
                      '${estimatedKcal.round()} kcal', Colors.deepOrange,
                      tooltip: '消費カロリー目安'),
                  if (!isCardio && log.totalVolume > 0) ...[
                    const SizedBox(width: 8),
                    _statChip(Icons.stacked_bar_chart, volumeLabel,
                        Colors.indigo,
                        tooltip: '総ボリューム (重量×回数×セット)'),
                  ],
                  if (oneRm > 0) ...[
                    const SizedBox(width: 8),
                    _statChip(Icons.speed, '1RM≈${oneRm.round()} kg',
                        Colors.teal,
                        tooltip: 'Epley式 推定1RM'),
                  ],
                ],
              ),

              if (log.note.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.notes, size: 13, color: Colors.grey),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(log.note,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey)),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 4),
              Text(
                DateFormat('yyyy/MM/dd HH:mm').format(log.date),
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// ペース表示: 5.5 → "5:30/km"
  String _formatPace(double minPerKm) {
    final min = minPerKm.floor();
    final sec = ((minPerKm - min) * 60).round();
    return '$min:${sec.toString().padLeft(2, '0')}/km';
  }

  Widget _metricText(String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 15)),
        Text(label,
            style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }

  Widget _statChip(IconData icon, String label, Color color,
      {required String tooltip}) {
    return Tooltip(
      message: tooltip,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    color: color,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Color _typeColor(ExerciseType type) {
    switch (type) {
      case ExerciseType.freeWeight:
        return Colors.deepOrange;
      case ExerciseType.machine:
        return Colors.blue;
      case ExerciseType.bodyweight:
        return Colors.green;
      case ExerciseType.cardio:
        return Colors.teal;
    }
  }
}

// ── Calorie preview chip (inside dialog) ──────────────────────────────────

class _CaloriePreviewChip extends StatelessWidget {
  final double kcal;
  final bool isCardio;
  final double weight;
  final int reps;
  final int sets;
  final ExerciseType exerciseType;
  final double distanceKm;
  final int durationMinutes;

  const _CaloriePreviewChip({
    required this.kcal,
    required this.isCardio,
    required this.weight,
    required this.reps,
    required this.sets,
    required this.exerciseType,
    required this.distanceKm,
    required this.durationMinutes,
  });

  @override
  Widget build(BuildContext context) {
    final volume = weight * reps * sets;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.deepOrange.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.deepOrange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_fire_department,
                  color: Colors.deepOrange, size: 18),
              const SizedBox(width: 6),
              Text(
                '推定消費カロリー: ${kcal.round()} kcal',
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.deepOrange,
                    fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (isCardio && distanceKm > 0 && durationMinutes > 0)
            Text(
              'ペース: ${_formatPace(durationMinutes / distanceKm)}  ／  距離: ${distanceKm.toStringAsFixed(2)} km',
              style: TextStyle(fontSize: 12, color: Colors.orange.shade800),
            )
          else if (!isCardio && volume > 0)
            Text(
              'ボリューム: ${volume.round()} kg  ／  1RM (Epley): ≈${TrainingNotifier.oneRepMax(weight, reps).round()} kg',
              style: TextStyle(fontSize: 12, color: Colors.orange.shade800),
            ),
          const SizedBox(height: 2),
          Text(
            isCardio
                ? '※ MET法（運動強度×体重×時間）による目安値です。'
                : '※ MET法＋挙上量ベースの目安値です。実際の消費カロリーは個人差があります。',
            style: TextStyle(fontSize: 10, color: Colors.orange.shade700),
          ),
        ],
      ),
    );
  }

  String _formatPace(double minPerKm) {
    final min = minPerKm.floor();
    final sec = ((minPerKm - min) * 60).round();
    return '$min:${sec.toString().padLeft(2, '0')}/km';
  }
}
