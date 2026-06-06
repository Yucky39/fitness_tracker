import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:intl/intl.dart';

import '../../models/training_log.dart';
import '../../providers/training_provider.dart';
import '../../theme/app_tokens.dart';
import '../../theme/bewell_colors.dart';
import '../../theme/exercise_colors.dart';
import '../ai_error_text.dart';

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
    final scheme = Theme.of(context).colorScheme;
    final semantic = context.bewellColors;
    final log = widget.log;
    final typeColor = ExerciseColors.forType(log.exerciseType, scheme, semantic);
    final isCardio = log.exerciseType == ExerciseType.cardio;
    final oneRm =
        isCardio ? 0.0 : TrainingNotifier.oneRepMax(log.weight, log.reps);
    final volumeLabel = log.totalVolume >= 1000
        ? '${(log.totalVolume / 1000).toStringAsFixed(1)} t'
        : '${log.totalVolume.round()} kg';

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: 6,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            onTap: widget.onEdit,
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
                          color: typeColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          log.exerciseType.label,
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(
                                color: typeColor,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          log.exerciseName,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      if (widget.isPr)
                        Tooltip(
                          message: '自己ベスト（最大重量）更新！',
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.emoji_events_rounded,
                                  color: semantic.warning, size: 18),
                              const SizedBox(width: 2),
                              Text(
                                'PR',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelMedium
                                    ?.copyWith(
                                      color: semantic.warning,
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      if (widget.onIntervalTimer != null)
                        IconButton(
                          icon: Icon(Icons.timer_outlined,
                              color: scheme.primary, size: 22),
                          tooltip: 'インターバルタイマー開始',
                          onPressed: widget.onIntervalTimer,
                        ),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, size: 20),
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit_outlined, size: 18),
                                SizedBox(width: 8),
                                Text('編集'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline,
                                    size: 18, color: scheme.error),
                                const SizedBox(width: 8),
                                Text('削除',
                                    style: TextStyle(color: scheme.error)),
                              ],
                            ),
                          ),
                        ],
                        onSelected: (v) {
                          if (v == 'edit') widget.onEdit();
                          if (v == 'delete') widget.onDelete();
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
                          _metricText(context, '${log.distanceKm.toStringAsFixed(2)} km', '距離'),
                        if (log.durationMinutes > 0)
                          _metricText(context, '${log.durationMinutes} 分', '時間'),
                        if (log.inclinePercent > 0)
                          _metricText(context, '${_formatIncline(log.inclinePercent)} %', '斜度'),
                        if (log.paceMinPerKm != null)
                          _metricText(context, _formatPace(log.paceMinPerKm!), 'ペース/km'),
                        if (log.rpe != null)
                          _metricText(context, '${log.rpe}', 'RPE'),
                      ],
                    )
                  else
                    Wrap(
                      spacing: 16,
                      runSpacing: 4,
                      children: [
                        _metricText(
                          context,
                          log.exerciseType == ExerciseType.bodyweight &&
                                  log.weight == 0
                              ? '自体重'
                              : '${log.weight} kg',
                          '重量',
                        ),
                        _metricText(context, '${log.reps} 回', '回数'),
                        _metricText(context, '${log.sets} set', 'セット'),
                        if (log.interval > 0)
                          _metricText(context, '${log.interval} 秒', 'インターバル'),
                        if (log.rpe != null)
                          _metricText(context, '${log.rpe}', 'RPE'),
                      ],
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _statChip(
                        context,
                        Icons.local_fire_department_outlined,
                        '${widget.estimatedKcal.round()} kcal',
                        semantic.streak,
                        tooltip: '消費カロリー目安',
                      ),
                      if (!isCardio && log.totalVolume > 0) ...[
                        const SizedBox(width: 8),
                        _statChip(
                          context,
                          Icons.stacked_bar_chart_rounded,
                          volumeLabel,
                          scheme.primary,
                          tooltip: '総ボリューム (重量×回数×セット)',
                        ),
                      ],
                      if (oneRm > 0) ...[
                        const SizedBox(width: 8),
                        _statChip(
                          context,
                          Icons.speed_rounded,
                          '1RM≈${oneRm.round()} kg',
                          scheme.secondary,
                          tooltip: 'Epley式 推定1RM',
                        ),
                      ],
                    ],
                  ),
                  if (log.noteForDisplay.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.notes_rounded,
                            size: 13, color: scheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            log.noteForDisplay,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('yyyy/MM/dd HH:mm').format(log.date),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
          ),
          if (widget.showAiAdvice && widget.onRequestAiAdvice != null)
            _buildAiAdviceSection(context, semantic: semantic),
        ],
      ),
    );
  }

  Widget _buildAiAdviceSection(
    BuildContext context, {
    required BeWellColors semantic,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final aiAccent = semantic.aiAccent;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 8, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1),
          const SizedBox(height: 4),
          if (widget.aiAdvice != null) ...[
            InkWell(
              onTap: () => setState(() => _adviceExpanded = !_adviceExpanded),
              borderRadius: AppRadius.smAll,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Icon(Icons.psychology_outlined, size: 18, color: aiAccent),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'AI評価済み',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: aiAccent,
                            ),
                      ),
                    ),
                    Icon(
                      _adviceExpanded
                          ? Icons.expand_less
                          : Icons.expand_more,
                      size: 20,
                      color: aiAccent,
                    ),
                  ],
                ),
              ),
            ),
            if (_adviceExpanded) ...[
              const SizedBox(height: 6),
              MarkdownBody(
                data: widget.aiAdvice!,
                listItemCrossAxisAlignment:
                    MarkdownListItemCrossAxisAlignment.start,
                styleSheet:
                    MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                  p: Theme.of(context).textTheme.bodySmall,
                  h3: Theme.of(context).textTheme.titleSmall,
                  strong: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                  horizontalRuleDecoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                          color: scheme.outlineVariant.withValues(alpha: 0.5)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: widget.aiLoading ? null : widget.onRequestAiAdvice,
                icon: widget.aiLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh, size: 18),
                label: const Text('再評価'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  foregroundColor: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
          if (widget.aiAdvice == null) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: widget.aiLoading ? null : widget.onRequestAiAdvice,
                icon: widget.aiLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(Icons.psychology_outlined, size: 20, color: aiAccent),
                label: const Text('この記録をAI評価'),
                style: TextButton.styleFrom(foregroundColor: aiAccent),
              ),
            ),
          ],
          if (widget.aiError != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: AiErrorText(widget.aiError!),
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

  String _formatIncline(double v) {
    return v == v.roundToDouble() ? v.toInt().toString() : v.toString();
  }

  Widget _metricText(BuildContext context, String value, String label) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: Theme.of(context).textTheme.titleSmall),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }

  Widget _statChip(
    BuildContext context,
    IconData icon,
    String label,
    Color color, {
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
