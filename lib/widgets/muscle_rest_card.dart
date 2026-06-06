import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/muscle_rest_provider.dart';
import '../providers/settings_provider.dart';

/// トレーニングした部位ごとの休息（回復）状況を表示するカード。
///
/// ホーム画面（睡眠・水分補給カードの上部）と、トレーニング管理画面の
/// 部位ヒートマップ付近の両方で使用する。推奨休息日数はユーザーが
/// 設定アイコンから任意に変更できる（デフォルト5日）。
class MuscleRestCard extends ConsumerWidget {
  const MuscleRestCard({super.key, this.margin});

  /// カードの外側マージン。画面ごとに余白を調整するために使用。
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final statuses = ref.watch(muscleRestStatusProvider);
    final restPeriodDays =
        ref.watch(settingsProvider.select((s) => s.restPeriodDays));

    return Card(
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bedtime_outlined, size: 20, color: scheme.primary),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    '部位ごとの休息状況',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  '目標 $restPeriodDays日',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.tune, size: 20),
                  tooltip: '休息日数を設定',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _showRestPeriodDialog(
                    context,
                    ref,
                    restPeriodDays,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (statuses.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'トレーニング記録がまだありません。\n記録すると部位ごとの回復状況を表示します。',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              ...statuses.map(
                (s) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _RestRow(status: s, scheme: scheme),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showRestPeriodDialog(
    BuildContext context,
    WidgetRef ref,
    int current,
  ) async {
    var days = current;
    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('休息日数の設定'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '同じ部位を再びトレーニングするまでの推奨休息日数を設定します。',
                    style: TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton.filledTonal(
                        icon: const Icon(Icons.remove),
                        onPressed: days > 1
                            ? () => setDialogState(() => days--)
                            : null,
                      ),
                      const SizedBox(width: 20),
                      Text(
                        '$days日',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 20),
                      IconButton.filledTonal(
                        icon: const Icon(Icons.add),
                        onPressed: days < 14
                            ? () => setDialogState(() => days++)
                            : null,
                      ),
                    ],
                  ),
                  Slider(
                    value: days.toDouble(),
                    min: 1,
                    max: 14,
                    divisions: 13,
                    label: '$days日',
                    onChanged: (v) =>
                        setDialogState(() => days = v.round()),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('キャンセル'),
                ),
                FilledButton(
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    ref
                        .read(settingsProvider.notifier)
                        .updateRestPeriodDays(days);
                    Navigator.pop(context);
                  },
                  child: const Text('保存'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _RestRow extends StatelessWidget {
  const _RestRow({required this.status, required this.scheme});

  final MuscleRestStatus status;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    final statusLabel = status.isRecovered
        ? '回復済み'
        : 'あと${status.remainingDays}日';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(
              status.group.label,
              style: const TextStyle(fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: status.recoveryFraction,
                minHeight: 7,
                backgroundColor: scheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 64,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (status.isRecovered)
                  Icon(Icons.check_circle, size: 14, color: color),
                if (status.isRecovered) const SizedBox(width: 3),
                Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(MuscleRestStatus s) {
    if (s.isRecovered) return Colors.teal;
    if (s.recoveryFraction >= 0.5) return Colors.orange.shade700;
    return Colors.red.shade400;
  }
}
