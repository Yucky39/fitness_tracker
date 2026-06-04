import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/legacy.dart';
import 'package:uuid/uuid.dart';
import '../models/training_plan.dart';
import '../services/database_service.dart';
import '../services/sync_service.dart';
import '../services/training_plan_service.dart';
import '../providers/ai_access.dart';
import '../providers/settings_provider.dart';
import '../providers/subscription_provider.dart';
import '../providers/training_provider.dart';
import '../providers/energy_profile_provider.dart';
import '../providers/progress_provider.dart';
import '../providers/sleep_provider.dart';

class TrainingPlanState {
  final List<TrainingPlan> plans;
  final bool isLoading;
  final bool isGenerating;
  final String? error;

  const TrainingPlanState({
    this.plans = const [],
    this.isLoading = true,
    this.isGenerating = false,
    this.error,
  });

  TrainingPlanState copyWith({
    List<TrainingPlan>? plans,
    bool? isLoading,
    bool? isGenerating,
    String? error,
    bool clearError = false,
  }) {
    return TrainingPlanState(
      plans: plans ?? this.plans,
      isLoading: isLoading ?? this.isLoading,
      isGenerating: isGenerating ?? this.isGenerating,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class TrainingPlanNotifier extends StateNotifier<TrainingPlanState> {
  final Ref _ref;

  TrainingPlanNotifier(this._ref) : super(const TrainingPlanState()) {
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    state = state.copyWith(isLoading: true, clearError: true);
    final adapter = await DatabaseService().database;
    final maps = await adapter.query(
      'training_plans',
      orderBy: 'created_at DESC',
    );
    state = state.copyWith(
      plans: maps.map(TrainingPlan.fromMap).toList(),
      isLoading: false,
    );
  }

  /// AIでプランを生成して保存する
  Future<TrainingPlan?> generateAndSave({
    required TrainingGoal goal,
    required List<MuscleGroup> targetMuscles,
    CutStyle? cutStyle,
    required int daysPerWeek,
    required PlanIntensity intensity,
    required EquipmentOption equipment,
  }) async {
    final isSubscribed = _ref.read(isSubscribedProvider);
    final settings = _ref.read(settingsProvider);
    final apiKey = settings.currentApiKey;
    final provider = settings.selectedProvider;
    final model = settings.currentModel;

    final access = resolveAiAccess(isSubscribed: isSubscribed, apiKey: apiKey);
    if (!access.allowed) {
      state = state.copyWith(
        isGenerating: false,
        error: '__paywall__',
      );
      return null;
    }

    state = state.copyWith(isGenerating: true, clearError: true);

    try {
      final profileState = _ref.read(energyProfileProvider);
      final allLogs = _ref.read(trainingProvider).logs;

      final cutoff = DateTime.now().subtract(const Duration(days: 28));
      final recentLogs =
          allLogs.where((l) => l.date.isAfter(cutoff)).toList();

      final id = const Uuid().v4();
      final plan = await TrainingPlanService().generatePlan(
        id: id,
        goal: goal,
        targetMuscles: targetMuscles,
        cutStyle: cutStyle,
        daysPerWeek: daysPerWeek,
        intensity: intensity,
        equipment: equipment,
        profile: profileState.toProfileIfComplete(),
        recentLogs: recentLogs,
        useSystemAi: access.useSystemAi,
        apiKey: apiKey,
        provider: provider,
        model: model.isNotEmpty ? model : null,
      );

      await _savePlan(plan);
      state = state.copyWith(
        plans: [plan, ...state.plans],
        isGenerating: false,
      );
      return plan;
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      state = state.copyWith(isGenerating: false, error: msg);
      return null;
    }
  }

  /// 既存プランを直近の実績・体型推移・睡眠で「来週用」に調整して新規保存する。
  /// 元プランは残し、調整版を別プランとして追加する（履歴を保てる）。
  Future<TrainingPlan?> adjustPlan(String planId) async {
    final current = state.plans.firstWhere(
      (p) => p.id == planId,
      orElse: () => state.plans.isNotEmpty
          ? state.plans.first
          : throw StateError('プランが見つかりません'),
    );

    final isSubscribed = _ref.read(isSubscribedProvider);
    final settings = _ref.read(settingsProvider);
    final apiKey = settings.currentApiKey;
    final access = resolveAiAccess(isSubscribed: isSubscribed, apiKey: apiKey);
    if (!access.allowed) {
      state = state.copyWith(isGenerating: false, error: '__paywall__');
      return null;
    }

    state = state.copyWith(isGenerating: true, clearError: true);
    try {
      final allLogs = _ref.read(trainingProvider).logs;
      final cutoff = DateTime.now().subtract(const Duration(days: 14));
      final recentLogs = allLogs.where((l) => l.date.isAfter(cutoff)).toList();

      final days = <String>{};
      for (final l in recentLogs) {
        final d = l.date.toLocal();
        days.add('${d.year}-${d.month}-${d.day}');
      }

      // 体重推移（直近2件の差）
      final progress = _ref.read(progressProvider);
      double? weightDelta;
      if (progress.latest != null && progress.previous != null) {
        weightDelta = progress.latest!.weight - progress.previous!.weight;
      }

      // 平均睡眠（直近14日）
      final sleep = _ref.read(sleepProvider);
      int? avgSleep;
      if (sleep.recentLogs.isNotEmpty) {
        final total = sleep.recentLogs
            .fold<int>(0, (s, l) => s + l.durationMinutes);
        avgSleep = (total / sleep.recentLogs.length).round();
      }

      final profile = _ref.read(energyProfileProvider).toProfileIfComplete();

      final adjusted = await TrainingPlanService().adjustPlan(
        id: const Uuid().v4(),
        current: current,
        recentLogs: recentLogs,
        trainingDaysLast14: days.length,
        weightDeltaKg: weightDelta,
        avgSleepMinutes: avgSleep,
        profile: profile,
        useSystemAi: access.useSystemAi,
        apiKey: apiKey,
        provider: settings.selectedProvider,
        model: settings.currentModel.isNotEmpty ? settings.currentModel : null,
      );

      await _savePlan(adjusted);
      state = state.copyWith(
        plans: [adjusted, ...state.plans],
        isGenerating: false,
      );
      return adjusted;
    } catch (e) {
      state = state.copyWith(
        isGenerating: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
      return null;
    }
  }

  Future<void> _savePlan(TrainingPlan plan) async {
    final adapter = await DatabaseService().database;
    await adapter.insert('training_plans', plan.toMap());
    SyncService().syncRecord('training_plans', plan.toMap());
  }

  /// AIプラン内の各種目の「実施済み」チェックを更新する
  Future<void> setExerciseCompleted(
    String planId,
    int dayIndex,
    int exerciseIndex,
    bool completed,
  ) async {
    final idx = state.plans.indexWhere((p) => p.id == planId);
    if (idx < 0) return;
    final updated = state.plans[idx].withExerciseCompletion(
      dayIndex,
      exerciseIndex,
      completed,
    );
    final adapter = await DatabaseService().database;
    await adapter.update(
      'training_plans',
      updated.toMap(),
      where: 'id = ?',
      whereArgs: [planId],
    );
    final newPlans = List<TrainingPlan>.from(state.plans);
    newPlans[idx] = updated;
    state = state.copyWith(plans: newPlans);
    SyncService().syncRecord('training_plans', updated.toMap());
  }

  Future<void> deletePlan(String id) async {
    final adapter = await DatabaseService().database;
    await adapter.delete('training_plans', where: 'id = ?', whereArgs: [id]);
    SyncService().deleteRecord('training_plans', id);
    state = state.copyWith(
      plans: state.plans.where((p) => p.id != id).toList(),
    );
  }

  void clearError() => state = state.copyWith(clearError: true);
}

final trainingPlanProvider =
    StateNotifierProvider<TrainingPlanNotifier, TrainingPlanState>(
  (ref) => TrainingPlanNotifier(ref),
);
