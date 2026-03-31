import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/training_routine.dart';
import '../providers/routine_provider.dart';

class RoutineScreen extends ConsumerWidget {
  const RoutineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routineState = ref.watch(routineProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('トレーニングルーティン'),
      ),
      body: routineState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : routineState.routines.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.calendar_today,
                            size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'ルーティンを追加して\n曜日ごとのメニューを管理しましょう',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: routineState.routines.length,
                  itemBuilder: (context, index) {
                    final routine = routineState.routines[index];
                    return _buildRoutineCard(context, ref, routine);
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEditDialog(context, ref, null),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildRoutineCard(
      BuildContext context, WidgetRef ref, TrainingRoutine routine) {
    final today = DateTime.now().weekday;
    final isToday = routine.weekdays.contains(today);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isToday
            ? const BorderSide(color: Colors.teal, width: 2)
            : BorderSide.none,
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Row(
          children: [
            Expanded(
              child: Text(
                routine.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            if (isToday)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.teal.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '今日',
                  style: TextStyle(fontSize: 11, color: Colors.teal),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.calendar_today,
                    size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  routine.weekdayLabel,
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ),
            if (routine.note.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                routine.note,
                style:
                    const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, size: 20),
              onPressed: () => _showEditDialog(context, ref, routine),
            ),
            IconButton(
              icon: const Icon(Icons.delete, size: 20, color: Colors.red),
              onPressed: () => _confirmDelete(context, ref, routine),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(
      BuildContext context, WidgetRef ref, TrainingRoutine routine) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('削除の確認'),
        content: Text('「${routine.name}」を削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () {
              ref.read(routineProvider.notifier).deleteRoutine(routine.id);
              Navigator.pop(context);
            },
            child: const Text('削除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(
      BuildContext context, WidgetRef ref, TrainingRoutine? existing) {
    final nameController =
        TextEditingController(text: existing?.name ?? '');
    final noteController =
        TextEditingController(text: existing?.note ?? '');
    final selectedDays = List<int>.from(existing?.weekdays ?? []);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title:
                Text(existing == null ? 'ルーティンを追加' : 'ルーティンを編集'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    decoration:
                        const InputDecoration(labelText: 'ルーティン名（例: 胸・肩の日）'),
                    autofocus: true,
                  ),
                  const SizedBox(height: 16),
                  const Text('曜日',
                      style: TextStyle(
                          fontSize: 13, color: Colors.grey)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: List.generate(7, (i) {
                      final day = i + 1; // 1=Mon...7=Sun
                      final label =
                          TrainingRoutine.weekdayNames[i];
                      final selected = selectedDays.contains(day);
                      return FilterChip(
                        label: Text(label),
                        selected: selected,
                        onSelected: (v) {
                          setDialogState(() {
                            if (v) {
                              selectedDays.add(day);
                              selectedDays.sort();
                            } else {
                              selectedDays.remove(day);
                            }
                          });
                        },
                      );
                    }),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteController,
                    decoration:
                        const InputDecoration(labelText: 'メモ（任意）'),
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
                  if (nameController.text.trim().isEmpty) return;
                  if (existing == null) {
                    ref.read(routineProvider.notifier).addRoutine(
                          name: nameController.text.trim(),
                          weekdays: selectedDays,
                          note: noteController.text.trim(),
                        );
                  } else {
                    ref.read(routineProvider.notifier).updateRoutine(
                          existing.copyWith(
                            name: nameController.text.trim(),
                            weekdays: selectedDays,
                            note: noteController.text.trim(),
                          ),
                        );
                  }
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
}
