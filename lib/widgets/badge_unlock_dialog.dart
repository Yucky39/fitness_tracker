import 'package:flutter/material.dart';

import '../data/badge_definitions.dart';
import '../providers/achievement_provider.dart';

/// バッジ解放時に中央に表示する祝福ダイアログ。
///
/// 複数同時解放にも対応し、各バッジを 1枚ずつ絵文字＋タイトル＋説明で表示する。
Future<void> showBadgeUnlockedDialog(
  BuildContext context, {
  required List<BadgeDefinition> badges,
  VoidCallback? onViewAll,
}) async {
  if (badges.isEmpty) return;
  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => _BadgeUnlockedDialog(badges: badges, onViewAll: onViewAll),
  );
}

class _BadgeUnlockedDialog extends StatefulWidget {
  const _BadgeUnlockedDialog({required this.badges, this.onViewAll});

  final List<BadgeDefinition> badges;
  final VoidCallback? onViewAll;

  @override
  State<_BadgeUnlockedDialog> createState() => _BadgeUnlockedDialogState();
}

class _BadgeUnlockedDialogState extends State<_BadgeUnlockedDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _scale = CurvedAnimation(parent: _controller, curve: Curves.elasticOut);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_index >= widget.badges.length - 1) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _index += 1);
    _controller.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final def = widget.badges[_index];
    final color = badgeCategoryColor(def.category);
    final total = widget.badges.length;
    final isLast = _index == total - 1;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: color.withValues(alpha: 0.5), width: 2),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.25),
                blurRadius: 24,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                total > 1 ? 'バッジを獲得！ ${_index + 1} / $total' : 'バッジを獲得！',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: 104,
                height: 104,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.18),
                  border: Border.all(
                    color: color.withValues(alpha: 0.55),
                    width: 2,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  def.emoji,
                  style: const TextStyle(
                    fontSize: 52,
                    fontFamilyFallback: [
                      'Apple Color Emoji',
                      'Noto Color Emoji',
                      'Segoe UI Emoji',
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                def.title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                def.description,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  if (widget.onViewAll != null && isLast)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          widget.onViewAll!.call();
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('一覧を見る'),
                      ),
                    ),
                  if (widget.onViewAll != null && isLast)
                    const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: _next,
                      style: FilledButton.styleFrom(
                        backgroundColor: color,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(isLast ? '閉じる' : '次へ'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
