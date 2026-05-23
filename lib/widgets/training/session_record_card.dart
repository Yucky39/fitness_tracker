import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:intl/intl.dart';

import '../../models/training_log.dart';
import '../../models/training_session_record.dart';

/// 完了済みトレーニングセッションを表示するカード。
/// ストレッチ推奨テキスト（AIが生成）を展開表示する。
class SessionRecordCard extends StatefulWidget {
  final TrainingSessionRecord session;
  final List<TrainingLog> sessionLogs;
  final bool isStretchLoading;
  final String? stretchError;
  final VoidCallback? onRetryStretch;
  final VoidCallback onDelete;

  const SessionRecordCard({
    super.key,
    required this.session,
    required this.sessionLogs,
    this.isStretchLoading = false,
    this.stretchError,
    this.onRetryStretch,
    required this.onDelete,
  });

  @override
  State<SessionRecordCard> createState() => _SessionRecordCardState();
}

class _SessionRecordCardState extends State<SessionRecordCard> {
  bool _stretchExpanded = false;

  @override
  void didUpdateWidget(SessionRecordCard old) {
    super.didUpdateWidget(old);
    // ストレッチが届いたら自動展開
    if (old.session.stretchRecommendation == null &&
        widget.session.stretchRecommendation != null) {
      setState(() => _stretchExpanded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final timeLabel =
        DateFormat('HH:mm').format(session.startedAt.toLocal());

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── ヘッダー行
          ListTile(
            leading: CircleAvatar(
              backgroundColor:
                  Theme.of(context).colorScheme.primaryContainer,
              child: Icon(
                Icons.fitness_center,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                size: 20,
              ),
            ),
            title: Text(
              session.name ?? 'トレーニングセッション',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(timeLabel),
            trailing: PopupMenuButton<_Action>(
              onSelected: (action) {
                if (action == _Action.delete) {
                  _confirmDelete(context);
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: _Action.delete,
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, size: 18),
                      SizedBox(width: 8),
                      Text('削除'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── 種目リスト
          if (widget.sessionLogs.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: widget.sessionLogs
                    .map(
                      (log) => Chip(
                        label: Text(
                          log.exerciseName,
                          style: const TextStyle(fontSize: 11),
                        ),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                      ),
                    )
                    .toList(),
              ),
            ),

          // ── ストレッチセクション
          _buildStretchSection(context),

          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildStretchSection(BuildContext context) {
    final session = widget.session;
    final colorScheme = Theme.of(context).colorScheme;

    if (widget.isStretchLoading) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'ストレッチを解析中…',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (widget.stretchError != null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: Row(
          children: [
            Icon(Icons.error_outline, size: 16, color: colorScheme.error),
            const SizedBox(width: 6),
            const Expanded(
              child: Text(
                'ストレッチの取得に失敗しました',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
            if (widget.onRetryStretch != null)
              TextButton(
                onPressed: widget.onRetryStretch,
                child: const Text('再試行', style: TextStyle(fontSize: 12)),
              ),
          ],
        ),
      );
    }

    if (session.stretchRecommendation == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 1, indent: 16, endIndent: 16),
        InkWell(
          onTap: () => setState(() => _stretchExpanded = !_stretchExpanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Icon(
                  Icons.self_improvement,
                  size: 18,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  'クールダウンストレッチ',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.primary,
                  ),
                ),
                const Spacer(),
                Icon(
                  _stretchExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: colorScheme.primary,
                ),
              ],
            ),
          ),
        ),
        if (_stretchExpanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: MarkdownBody(
              data: session.stretchRecommendation!,
              styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context))
                  .copyWith(
                    p: Theme.of(context).textTheme.bodySmall,
                    listBullet: Theme.of(context).textTheme.bodySmall,
                  ),
            ),
          ),
      ],
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('削除の確認'),
        content: const Text('このセッション記録を削除しますか？\nトレーニングログは削除されません。'),
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
    );
    if (ok == true) widget.onDelete();
  }
}

enum _Action { delete }
