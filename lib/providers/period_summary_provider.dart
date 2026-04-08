import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/legacy.dart';

import '../models/period_summary.dart';
import '../services/period_summary_service.dart';
import 'energy_profile_provider.dart';
import 'meal_provider.dart';

class PeriodSummaryState {
  final SummaryPeriodKind preset;
  final PeriodSummary? summary;
  final bool isLoading;

  const PeriodSummaryState({
    this.preset = SummaryPeriodKind.week,
    this.summary,
    this.isLoading = true,
  });

  PeriodSummaryState copyWith({
    SummaryPeriodKind? preset,
    PeriodSummary? summary,
    bool? isLoading,
  }) =>
      PeriodSummaryState(
        preset: preset ?? this.preset,
        summary: summary ?? this.summary,
        isLoading: isLoading ?? this.isLoading,
      );
}

class PeriodSummaryNotifier extends StateNotifier<PeriodSummaryState> {
  PeriodSummaryNotifier(this._ref) : super(const PeriodSummaryState()) {
    _ref.listen(
      mealProvider.select(
        (m) => (m.calorieGoal, m.proteinGoal, m.mealDataEpoch),
      ),
      (_, __) => load(),
    );
    _ref.listen(
      energyProfileProvider.select(
        (e) => (e.weightKg, e.targetWeightKg),
      ),
      (_, __) => load(),
    );
    load();
  }

  final Ref _ref;

  Future<void> load() async {
    state = state.copyWith(isLoading: true);
    final meal = _ref.read(mealProvider);
    final ep = _ref.read(energyProfileProvider);
    final w = ep.weightKg > 0 ? ep.weightKg : 0.0;
    final tw = ep.targetWeightKg > 0 ? ep.targetWeightKg : 0.0;

    final summary = await PeriodSummaryService.build(
      kind: state.preset,
      calorieGoal: meal.calorieGoal,
      proteinGoal: meal.proteinGoal,
      bodyWeightKg: w,
      profileWeightKg: w,
      targetWeightKg: tw,
    );
    state = state.copyWith(summary: summary, isLoading: false);
  }

  Future<void> setPreset(SummaryPeriodKind next) async {
    if (next == state.preset) return;
    state = state.copyWith(preset: next, isLoading: true);
    final meal = _ref.read(mealProvider);
    final ep = _ref.read(energyProfileProvider);
    final w = ep.weightKg > 0 ? ep.weightKg : 0.0;
    final tw = ep.targetWeightKg > 0 ? ep.targetWeightKg : 0.0;

    final summary = await PeriodSummaryService.build(
      kind: next,
      calorieGoal: meal.calorieGoal,
      proteinGoal: meal.proteinGoal,
      bodyWeightKg: w,
      profileWeightKg: w,
      targetWeightKg: tw,
    );
    state = state.copyWith(summary: summary, isLoading: false);
  }
}

final periodSummaryProvider =
    StateNotifierProvider<PeriodSummaryNotifier, PeriodSummaryState>(
  (ref) => PeriodSummaryNotifier(ref),
);
