import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:intl/intl.dart';

import '../../models/training_log.dart';
import '../../providers/training_provider.dart';

/// トレーニングログ1件のカード（メトリクス・AI評価エリアを含む）
class TrainingLogCard extends StatefulWidget {
  final TrainingLog log;
  final bool isPr;
  final double estimatedKcal;
  final double bodyWeightKg;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onIntervalTimer;
  final bool showAiAdvice;
  final bool aiLoading;
  final String? aiAdvice;
  final String? aiError;
  final VoidCallback? onRequestAiAdvice;

  const TrainingLogCard({
    super.key,
    required this.log,
    required this.isPr,
    required this.estimatedKcal,
    required this.bodyWeightKg,
    required this.onEdit,
    required this.onDelete,
    this.onIntervalTimer,
    this.showAiAdvice = false,
    this.aiLoading = false,
    this.aiAdvice,
    this.aiError,
    this.onRequestAiAdvice,
  });

  @override
  State<TrainingLogCard> createState() => _TrainingLogCardState();
}

class _TrainingLogCardState extends State<TrainingLogCard> {
  bool _adviceExpanded = false;

  @override
  void didUpdateWidget(TrainingLogCard old) {
    super.didUpdateWidget(old);
    if (old.aiAdvice == null && widget.aiAdvice != null) {
      setState(() => _adviceExpanded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final log = widget.log;
    final isPr = widget.isPr;
    final estimatedKcal = widget.estimatedKcal;
    final onEdit = widget.onEdit;
    final onDelete = widget.onDelete;
    final onIntervalTimer = widget.onIntervalTimer;
    final showAiAdvice = widget.showAiAdvice;
    final aiLoading = widget.aiLoading;
    final aiAdvice = widget.aiAdvice;
    final aiError = widget.aiError;
    final onRequestAiAdvice = widget.onRequestAiAdvice;
    final isCardio = log.exerciseType == ExerciseType.cardio;
    final oneRm =
        isCardio ? 0.0 : TrainingNotifier.oneRepMax(log.weight, log.reps);
    final volumeLabel = log.totalVolume >= 1000
        ? '${(log.totalVolume / 1000).toStringAsFixed(1)} t'
        : '${log.totalVolume.round()} kg';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            onTap: onEdit,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                      if (onIntervalTimer != null)
                        IconButton(
                          icon: const Icon(Icons.timer_outlined,
                              color: Colors.teal, size: 22),
                          tooltip: 'インターバルタイマー開始',
                          onPressed: onIntervalTimer,
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
                        if (log.rpe != null)
                          _metricText('${log.rpe}', 'RPE'),
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
                        if (log.rpe != null)
                          _metricText('${log.rpe}', 'RPE'),
                      ],
                    ),
                  const SizedBox(height: 8),
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
                  if (log.noteForDisplay.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.notes, size: 13, color: Colors.grey),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(log.noteForDisplay,
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
          if (showAiAdvice && onRequestAiAdvice != null)
            _buildAiAdviceSection(
              context,
              aiAdvice: aiAdvice,
              aiLoading: aiLoading,
              aiError: aiError,
              onRequestAiAdvice: onRequestAiAdvice,
            ),
        ],
      ),
    );
  }

  Widget _buildAiAdviceSection(
    BuildContext context, {
    required String? aiAdvice,
    required bool aiLoading,
    required String? aiError,
    required VoidCallback onRequestAiAdvice,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 8, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1),
          const SizedBox(height: 4),
          if (aiAdvice != null) ...[
            InkWell(
              onTap: () => setState(() => _adviceExpanded = !_adviceExpanded),
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    const Icon(Icons.psychology, size: 18, color: Colors.teal),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text(
                        'AI評価済み',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.teal,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Icon(
                      _adviceExpanded
                          ? Icons.expand_less
                          : Icons.expand_more,
                      size: 20,
                      color: Colors.teal,
                    ),
                  ],
                ),
              ),
            ),
            if (_adviceExpanded) ...[
              const SizedBox(height: 6),
              MarkdownBody(
                data: aiAdvice,
                listItemCrossAxisAlignment:
                    MarkdownListItemCrossAxisAlignment.start,
                styleSheet:
                    MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                  p: const TextStyle(fontSize: 13, height: 1.6),
                  h3: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    height: 1.8,
                  ),
                  strong: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                  horizontalRuleDecoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: Colors.grey.shade300, width: 1),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: aiLoading ? null : onRequestAiAdvice,
                icon: aiLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh, size: 18),
                label: const Text('再評価', style: TextStyle(fontSize: 13)),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  foregroundColor: Colors.grey[600],
                ),
              ),
            ],
          ],
          if (aiAdvice == null) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: aiLoading ? null : onRequestAiAdvice,
                icon: aiLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.psychology_outlined, size: 20),
                label: const Text(
                  'この記録をAI評価',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ),
          ],
          if (aiError != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                aiError,
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
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
