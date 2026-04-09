import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/training_log.dart';
import '../../providers/training_provider.dart';
import '../../services/training_calorie_calculator.dart';

/// トレーニング記録の追加・編集ダイアログを表示する。
///
/// 新規記録でインターバルが設定された場合、[onIntervalTimerStart] に秒数が渡る。
void showTrainingLogDialog({
  required BuildContext context,
  required WidgetRef ref,
  required TrainingNotifier notifier,
  required double bodyWeightKg,
  TrainingLog? existingLog,
  void Function(int intervalSeconds)? onIntervalTimerStart,
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

  var recordRpe = existingLog?.rpe != null;
  var rpeSlider = (existingLog?.rpe ?? 7).toDouble();

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
  final suggestions = <String>{
    ...recentExerciseNames,
    ...allExerciseNames,
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
                distanceController.text =
                    prev.distanceKm > 0 ? prev.distanceKm.toString() : '';
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
              if (prev.rpe != null) {
                recordRpe = true;
                rpeSlider = prev.rpe!.toDouble();
              }
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
                        const Icon(Icons.history, size: 14, color: Colors.blue),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            previousLog!.exerciseType == ExerciseType.cardio
                                ? '前回: ${previousLog!.durationMinutes}分'
                                    '${previousLog!.distanceKm > 0 ? '  ${previousLog!.distanceKm.toStringAsFixed(1)}km' : ''}'
                                    '${previousLog!.rpe != null ? '  RPE ${previousLog!.rpe}' : ''}'
                                    '  (${DateFormat('M/d').format(previousLog!.date)})'
                                : '前回: ${previousLog!.weight}kg × ${previousLog!.reps}回 × ${previousLog!.sets}セット'
                                    '${previousLog!.rpe != null ? '  RPE ${previousLog!.rpe}' : ''}'
                                    '  (${DateFormat('M/d').format(previousLog!.date)})',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.blue),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (previousLog != null) const SizedBox(height: 8),
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
                if (!isCardio) ...[
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: weightController,
                          decoration: InputDecoration(
                            labelText: exerciseType == ExerciseType.bodyweight
                                ? '追加重量 (kg)'
                                : '重量 (kg)',
                            hintText: exerciseType == ExerciseType.bodyweight
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
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('RPEを記録（主観的運動強度 1〜10）'),
                  subtitle: const Text(
                    'そのセット・セッションのきつさ。有酸素・筋トレどちらにも使えます。',
                    style: TextStyle(fontSize: 11),
                  ),
                  value: recordRpe,
                  onChanged: (v) => setState(() => recordRpe = v),
                ),
                if (recordRpe) ...[
                  Row(
                    children: [
                      Text(
                        rpeSlider.round().toString(),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          '1=非常に楽 … 10=限界に近い',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: rpeSlider.clamp(1, 10),
                    min: 1,
                    max: 10,
                    divisions: 9,
                    label: rpeSlider.round().toString(),
                    onChanged: (v) => setState(() => rpeSlider = v),
                  ),
                ],
                TextField(
                  controller: noteController,
                  decoration: const InputDecoration(labelText: 'メモ'),
                ),
                const SizedBox(height: 14),
                if (previewKcal > 0)
                  _CaloriePreviewChip(
                    kcal: previewKcal,
                    isCardio: isCardio,
                    weight: double.tryParse(weightController.text) ?? 0,
                    reps: int.tryParse(repsController.text) ?? 0,
                    sets: int.tryParse(setsController.text) ?? 0,
                    exerciseType: exerciseType,
                    distanceKm: double.tryParse(distanceController.text) ?? 0,
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
                int? intervalToStart;
                if (isCardio) {
                  final dist = double.tryParse(distanceController.text) ?? 0;
                  final dur = int.tryParse(durationController.text) ?? 0;
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
                      rpe: recordRpe ? rpeSlider.round() : null,
                      clearRpe: !recordRpe,
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
                      rpe: recordRpe ? rpeSlider.round() : null,
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
                      rpe: recordRpe ? rpeSlider.round() : null,
                      clearRpe: !recordRpe,
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
                      rpe: recordRpe ? rpeSlider.round() : null,
                      note: noteController.text,
                    );
                    if (iv > 0) intervalToStart = iv;
                  }
                }
                Navigator.pop(context);
                if (intervalToStart != null) {
                  onIntervalTimerStart?.call(intervalToStart);
                }
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
