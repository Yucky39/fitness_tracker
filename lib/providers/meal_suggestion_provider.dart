import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/legacy.dart';
import '../models/meal_suggestion.dart';
import '../services/meal_suggestion_service.dart';
import 'meal_provider.dart';
import 'settings_provider.dart';

class MealSuggestionState {
  final DailyMealSuggestion? suggestion;
  final bool isLoading;
  final String? error;

  const MealSuggestionState({
    this.suggestion,
    this.isLoading = false,
    this.error,
  });

  MealSuggestionState copyWith({
    DailyMealSuggestion? suggestion,
    bool? isLoading,
    String? error,
    bool clearSuggestion = false,
    bool clearError = false,
  }) =>
      MealSuggestionState(
        suggestion: clearSuggestion ? null : suggestion ?? this.suggestion,
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : error ?? this.error,
      );
}

class MealSuggestionNotifier extends StateNotifier<MealSuggestionState> {
  final Ref _ref;

  MealSuggestionNotifier(this._ref) : super(const MealSuggestionState());

  /// 食事提案を生成する。
  /// [calorieGoal] 等は呼び出し元から渡す（mealProvider の値を使う）。
  Future<void> generate() async {
    final settings = _ref.read(settingsProvider);
    if (settings.currentApiKey.isEmpty) {
      state = state.copyWith(
        error: 'APIキーが設定されていません。設定 → AIキー設定 から入力してください。',
        clearSuggestion: false,
      );
      return;
    }

    final mealState = _ref.read(mealProvider);

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final suggestion = await MealSuggestionService().suggest(
        calorieGoal: mealState.calorieGoal,
        proteinGoal: mealState.proteinGoal,
        fatGoal: mealState.fatGoal,
        carbsGoal: mealState.carbsGoal,
        todayItems: mealState.todayItems,
        apiKey: settings.currentApiKey,
        provider: settings.selectedProvider,
        model: settings.resolvedModelForProvider(settings.selectedProvider),
      );
      state = MealSuggestionState(suggestion: suggestion);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  void clear() => state = const MealSuggestionState();
}

final mealSuggestionProvider =
    StateNotifierProvider<MealSuggestionNotifier, MealSuggestionState>(
  (ref) => MealSuggestionNotifier(ref),
);
