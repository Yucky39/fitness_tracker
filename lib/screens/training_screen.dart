import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/training_provider.dart';
import '../models/training_log.dart';

class TrainingScreen extends ConsumerWidget {
  const TrainingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trainingState = ref.watch(trainingProvider);
    final trainingNotifier = ref.read(trainingProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('トレーニング記録'),
      ),
      body: trainingState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : trainingState.logs.isEmpty
              ? const Center(child: Text('まだ記録がありません'))
              : ListView.builder(
                  itemCount: trainingState.logs.length,
                  itemBuilder: (context, index) {
                    final log = trainingState.logs[index];
                    return Dismissible(
                      key: Key(log.id),
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
                      onDismissed: (_) => trainingNotifier.deleteLog(log.id),
                      background: Container(color: Colors.red),
                      child: Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: ListTile(
                          title: Text(log.exerciseName),
                          subtitle: Text(
                            '${log.weight}kg x ${log.reps}回 x ${log.sets}セット  インターバル: ${log.interval}秒\n'
                            '${DateFormat('yyyy/MM/dd HH:mm').format(log.date)}'
                            '${log.note.isNotEmpty ? '\nメモ: ${log.note}' : ''}',
                          ),
                          isThreeLine: log.note.isNotEmpty,
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddTrainingDialog(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddTrainingDialog(BuildContext context, WidgetRef ref) {
    final weightController = TextEditingController();
    final repsController = TextEditingController();
    final setsController = TextEditingController();
    final intervalController = TextEditingController();
    final noteController = TextEditingController();
    String exerciseName = '';

    final recentExerciseNames = ref
        .read(trainingProvider)
        .logs
        .map((l) => l.exerciseName)
        .toSet()
        .toList()
      ..sort();

    showDialog(
      context: context,
      builder: (context) {
        TrainingLog? previousLog;

        return StatefulBuilder(
          builder: (context, setState) {
            void updatePreviousLog(String name) {
              final prev = name.isNotEmpty
                  ? ref.read(trainingProvider.notifier).getPreviousLog(name)
                  : null;
              setState(() => previousLog = prev);
            }

            void fillFromPreviousLog(String name) {
              final prev = ref.read(trainingProvider.notifier).getPreviousLog(name);
              setState(() {
                previousLog = prev;
                if (prev != null) {
                  weightController.text = prev.weight.toString();
                  repsController.text = prev.reps.toString();
                  setsController.text = prev.sets.toString();
                  intervalController.text = prev.interval.toString();
                }
              });
            }

            return AlertDialog(
              title: const Text('トレーニングを記録'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Autocomplete<String>(
                      optionsBuilder: (textEditingValue) {
                        exerciseName = textEditingValue.text;
                        if (textEditingValue.text.isEmpty) {
                          return recentExerciseNames;
                        }
                        return recentExerciseNames.where((name) => name
                            .toLowerCase()
                            .contains(textEditingValue.text.toLowerCase()));
                      },
                      onSelected: (selection) {
                        exerciseName = selection;
                        fillFromPreviousLog(selection);
                      },
                      fieldViewBuilder: (ctx, controller, focusNode, onFieldSubmitted) {
                        return TextField(
                          controller: controller,
                          focusNode: focusNode,
                          decoration: const InputDecoration(labelText: '種目名'),
                          onChanged: (value) {
                            exerciseName = value;
                            updatePreviousLog(value);
                          },
                        );
                      },
                    ),
                    if (previousLog != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          '前回: ${previousLog!.weight}kg x ${previousLog!.reps}回 x ${previousLog!.sets}セット'
                          '${previousLog!.note.isNotEmpty ? '\nメモ: ${previousLog!.note}' : ''}',
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                      ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: weightController,
                            decoration: const InputDecoration(labelText: '重量 (kg)'),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextField(
                            controller: repsController,
                            decoration: const InputDecoration(labelText: '回数'),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: setsController,
                            decoration: const InputDecoration(labelText: 'セット数'),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextField(
                            controller: intervalController,
                            decoration: const InputDecoration(labelText: 'インターバル (秒)'),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    TextField(
                      controller: noteController,
                      decoration: const InputDecoration(labelText: 'メモ'),
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
                    if (exerciseName.isNotEmpty) {
                      ref.read(trainingProvider.notifier).addLog(
                            exerciseName: exerciseName,
                            weight: double.tryParse(weightController.text) ?? 0,
                            reps: int.tryParse(repsController.text) ?? 0,
                            sets: int.tryParse(setsController.text) ?? 0,
                            interval: int.tryParse(intervalController.text) ?? 0,
                            note: noteController.text,
                          );
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('記録'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
