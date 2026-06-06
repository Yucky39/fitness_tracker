import 'package:flutter/material.dart';

import '../../theme/bewell_colors.dart';

/// インターバルタイマー用フローティングカード
class TrainingTimerOverlay extends StatelessWidget {
  final int secondsRemaining;
  final int totalSeconds;
  final VoidCallback onClose;

  const TrainingTimerOverlay({
    super.key,
    required this.secondsRemaining,
    required this.totalSeconds,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final semantic = context.bewellColors;
    final progress =
        totalSeconds > 0 ? secondsRemaining / totalSeconds : 0.0;
    final mins = secondsRemaining ~/ 60;
    final secs = secondsRemaining % 60;
    final isDone = secondsRemaining == 0;
    final accent = isDone ? semantic.success : scheme.primary;

    return Positioned(
      bottom: 80,
      left: 16,
      right: 16,
      child: Card(
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: isDone
            ? semantic.success.withValues(alpha: 0.1)
            : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              SizedBox(
                width: 56,
                height: 56,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: progress,
                      backgroundColor: scheme.outlineVariant.withValues(alpha: 0.35),
                      valueColor: AlwaysStoppedAnimation<Color>(accent),
                    ),
                    Icon(
                      isDone ? Icons.check : Icons.timer,
                      color: accent,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isDone ? '休憩終了！' : 'インターバル休憩中',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: isDone ? semantic.success : null,
                          ),
                    ),
                    if (!isDone)
                      Text(
                        '$mins:${secs.toString().padLeft(2, '0')}',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: onClose,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
