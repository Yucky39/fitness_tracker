import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/training_plan.dart';
import 'training_plan_provider.dart';

/// 週次でプランを「実績に合わせて調整」すべきかの提案。
class CoachPlanNudge {
  final TrainingPlan plan;
  final String reason;

  const CoachPlanNudge({required this.plan, required this.reason});
}

/// トレーナーが「来週のメニューを変えよう」と先回りで提案する条件。
final coachPlanNudgeProvider = Provider<CoachPlanNudge?>((ref) {
  final planState = ref.watch(trainingPlanProvider);
  if (planState.isLoading || planState.plans.isEmpty) return null;

  // 最新プラン（created_at DESC）
  final plan = planState.plans.first;
  final ageDays = DateTime.now().difference(plan.createdAt).inDays;
  final ratio = plan.completionRatio;

  if (ageDays >= 7) {
    return CoachPlanNudge(
      plan: plan,
      reason: 'プラン作成から$ageDays日経過しました。今週の実績に合わせて調整しましょう。',
    );
  }
  if (plan.totalExerciseCount > 0 && ratio < 0.45) {
    final pct = (ratio * 100).round();
    return CoachPlanNudge(
      plan: plan,
      reason: 'メニューの消化率が$pct%です。負荷や種目を見直すタイミングかもしれません。',
    );
  }
  return null;
});
