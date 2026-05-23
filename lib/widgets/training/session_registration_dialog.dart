import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/training_log.dart';
import '../../providers/training_session_provider.dart';

/// 選択日のトレーニングログからセッションを登録するダイアログ。
Future<void> showSessionRegistrationDialog({
  required BuildContext context,
  required WidgetRef ref,
  required List<TrainingLog> dayLogs,
  required DateTime sessionDate,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => _SessionRegistrationSheet(
      ref: ref,
      dayLogs: dayLogs,
      sessionDate: sessionDate,
    ),
  );
}

class _SessionRegistrationSheet extends StatefulWidget {
  final WidgetRef ref;
  final List<TrainingLog> dayLogs;
  final DateTime sessionDate;

  const _SessionRegistrationSheet({
    required this.ref,
    required this.dayLogs,
    required this.sessionDate,
  });

  @override
  State<_SessionRegistrationSheet> createState() =>
      _SessionRegistrationSheetState();
}

class _SessionRegistrationSheetState extends State<_SessionRegistrationSheet> {
  late final Set<String> _selectedLogIds;
  final _nameController = TextEditingController();
  final _noteController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // デフォルトで全ログを選択
    _selectedLogIds = widget.dayLogs.map((l) => l.id).toSet();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  List<TrainingLog> get _selectedLogs =>
      widget.dayLogs.where((l) => _selectedLogIds.contains(l.id)).toList();

  Future<void> _save() async {
    if (_selectedLogs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('種目を1件以上選択してください')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      await widget.ref.read(trainingSessionProvider.notifier).addSession(
            logs: _selectedLogs,
            name: _nameController.text.trim().isEmpty
                ? null
                : _nameController.text.trim(),
            note: _noteController.text.trim().isEmpty
                ? null
                : _noteController.text.trim(),
            startedAt: widget.sessionDate,
          );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('セッションを登録しました。ストレッチを解析中…'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存に失敗しました: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel =
        DateFormat('yyyy/M/d').format(widget.sessionDate.toLocal());

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── ヘッダー
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 8, 4),
            child: Row(
              children: [
                const Icon(Icons.fitness_center),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'セッション登録',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        dateLabel,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // ── スクロール可能なコンテンツ
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // セッション名（任意）
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'セッション名（任意）',
                      hintText: '例：胸・三頭筋トレーニング',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 種目選択
                  Text(
                    'セッションに含める種目',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  if (widget.dayLogs.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        'この日のトレーニング記録がありません',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  else
                    ...widget.dayLogs.map((log) {
                      final isSelected = _selectedLogIds.contains(log.id);
                      final subtitle = log.exerciseType == ExerciseType.cardio
                          ? '${log.distanceKm.toStringAsFixed(1)}km / ${log.durationMinutes}分'
                          : '${log.weight}kg × ${log.reps}回 × ${log.sets}セット';

                      return CheckboxListTile(
                        value: isSelected,
                        onChanged: (v) {
                          setState(() {
                            if (v == true) {
                              _selectedLogIds.add(log.id);
                            } else {
                              _selectedLogIds.remove(log.id);
                            }
                          });
                        },
                        title: Text(log.exerciseName),
                        subtitle: Text(subtitle),
                        secondary: Icon(
                          _exerciseIcon(log.exerciseType),
                          size: 20,
                        ),
                        dense: true,
                        controlAffinity: ListTileControlAffinity.leading,
                      );
                    }),

                  const SizedBox(height: 16),

                  // メモ（任意）
                  TextField(
                    controller: _noteController,
                    decoration: const InputDecoration(
                      labelText: 'メモ（任意）',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),

                  const SizedBox(height: 8),

                  // ストレッチ解析の説明
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primaryContainer
                          .withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.self_improvement,
                          color: Theme.of(context).colorScheme.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            '登録後、AIがセッションの種目を解析してクールダウンストレッチを提案します',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),

          // ── 保存ボタン
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: FilledButton.icon(
              onPressed: _isSaving ? null : _save,
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: Text(_isSaving ? '登録中...' : 'セッションを登録'),
            ),
          ),
        ],
      ),
    );
  }

  IconData _exerciseIcon(ExerciseType type) {
    switch (type) {
      case ExerciseType.freeWeight:
        return Icons.sports_gymnastics;
      case ExerciseType.machine:
        return Icons.precision_manufacturing;
      case ExerciseType.bodyweight:
        return Icons.accessibility_new;
      case ExerciseType.cardio:
        return Icons.directions_run;
    }
  }
}
