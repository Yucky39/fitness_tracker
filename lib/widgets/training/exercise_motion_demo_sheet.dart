import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../data/exercise_motion_guides.dart';
import '../../models/training_log.dart';

/// 種目のフォーム解説とループアニメを表示するボトムシート。
Future<void> showExerciseMotionDemoSheet(
  BuildContext context, {
  required String exerciseName,
  required ExerciseType exerciseType,
}) async {
  final guide = lookupExerciseMotionGuide(exerciseName, exerciseType);

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) {
      final bottom = MediaQuery.paddingOf(ctx).bottom;
      return Padding(
        padding: EdgeInsets.fromLTRB(20, 8, 20, 16 + bottom),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                exerciseName,
                style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 6),
              Chip(
                label: Text(exerciseType.label),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
              ),
              const SizedBox(height: 12),
              if (guide.lottieAsset != null)
                Center(
                  child: SizedBox(
                    height: 200,
                    child: Lottie.asset(
                      guide.lottieAsset!,
                      repeat: true,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.fitness_center_rounded,
                        size: 72,
                        color: Theme.of(ctx).colorScheme.primary,
                      ),
                    ),
                  ),
                ),
              if (guide.lottieAsset != null) const SizedBox(height: 8),
              Text(
                'フォームのポイント',
                style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              ...guide.tips.map(
                (t) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Icon(
                          Icons.check_circle_outline_rounded,
                          size: 18,
                          color: Theme.of(ctx).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(t, style: const TextStyle(height: 1.45))),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
