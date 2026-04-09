import 'package:flutter/material.dart';

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
    final progress =
        totalSeconds > 0 ? secondsRemaining / totalSeconds : 0.0;
    final mins = secondsRemaining ~/ 60;
    final secs = secondsRemaining % 60;
    final isDone = secondsRemaining == 0;

    return Positioned(
      bottom: 80,
      left: 16,
      right: 16,
      child: Card(
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: isDone ? Colors.green.shade50 : null,
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
                      backgroundColor: Colors.grey.withValues(alpha: 0.2),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isDone ? Colors.green : Colors.teal,
                      ),
                    ),
                    Icon(
                      isDone ? Icons.check : Icons.timer,
                      color: isDone ? Colors.green : Colors.teal,
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
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isDone ? Colors.green : null,
                      ),
                    ),
                    if (!isDone)
                      Text(
                        '$mins:${secs.toString().padLeft(2, '0')}',
                        style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold),
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
