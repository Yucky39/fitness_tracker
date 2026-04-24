import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/meal_suggestion.dart';
import '../services/meal_suggestion_service.dart';
import 'meal_provider.dart';
import 'settings_provider.dart';

class MealSuggestionState {
  final DailyMealSuggestion? suggestion;
  final WeeklyMealSuggestion? weeklySuggestion;
  final SuggestionPeriod period;
  final bool isLoading;
  final String? error;

  const MealSuggestionState({
    this.suggestion,
    this.weeklySuggestion,
    this.period = SuggestionPeriod.today,
    this.isLoading = false,
    this.error,
  });

  MealSuggestionState copyWith({
    DailyMealSuggestion? suggestion,
    WeeklyMealSuggestion? weeklySuggestion,
    SuggestionPeriod? period,
    bool? isLoading,
    String? error,
    bool clearSuggestion = false,
    bool clearWeeklySuggestion = false,
    bool clearError = false,
  }) =>
      MealSuggestionState(
        suggestion: clearSuggestion ? null : suggestion ?? this.suggestion,
        weeklySuggestion: clearWeeklySuggestion
            ? null
            : weeklySuggestion ?? this.weeklySuggestion,
        period: period ?? this.period,
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : error ?? this.error,
      );
}

class MealSuggestionNotifier extends StateNotifier<MealSuggestionState> {
  final Ref _ref;

  static const _keyToday = 'meal_sugg_today';
  static const _keyTomorrow = 'meal_sugg_tomorrow';
  static const _keyWeek = 'meal_sugg_week';

  MealSuggestionNotifier(this._ref) : super(const MealSuggestionState()) {
    _init();
  }

  Future<void> _init() async {
    await _loadCache(SuggestionPeriod.week);
    await _loadCache(SuggestionPeriod.today);
    if (!mounted) return;
    if (state.suggestion == null && state.weeklySuggestion != null) {
      final weeklyDay = _findWeeklyDayForPeriod(SuggestionPeriod.today);
      if (weeklyDay != null) await generate();
    }
  }

  WeeklyDayPlan? _findWeeklyDayForPeriod(SuggestionPeriod period) {
    final weekly = state.weeklySuggestion;
    if (weekly == null || weekly.days.isEmpty) return null;

    final now = DateTime.now();
    final genDate = weekly.generatedAt;
    final genDay = DateTime(genDate.year, genDate.month, genDate.day);
    final today = DateTime(now.year, now.month, now.day);
    final dayOffset = today.difference(genDay).inDays;

    final targetIndex = switch (period) {
      SuggestionPeriod.today => dayOffset,
      SuggestionPeriod.tomorrow => dayOffset + 1,
      SuggestionPeriod.week => -1,
    };

    if (targetIndex < 0 || targetIndex >= weekly.days.length) return null;
    return weekly.days[targetIndex];
  }

  String _cacheKey(SuggestionPeriod period) => switch (period) {
        SuggestionPeriod.today => _keyToday,
        SuggestionPeriod.tomorrow => _keyTomorrow,
        SuggestionPeriod.week => _keyWeek,
      };

  bool _isCacheValid(DateTime generatedAt, SuggestionPeriod period) {
    final now = DateTime.now();
    switch (period) {
      case SuggestionPeriod.today:
      case SuggestionPeriod.tomorrow:
        return generatedAt.year == now.year &&
            generatedAt.month == now.month &&
            generatedAt.day == now.day;
      case SuggestionPeriod.week:
        return generatedAt.isAfter(now.subtract(const Duration(days: 7)));
    }
  }

  Future<void> _loadCache(SuggestionPeriod period) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_cacheKey(period));
    if (jsonStr == null) return;
    try {
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      if (period == SuggestionPeriod.week) {
        final suggestion = WeeklyMealSuggestion.fromJson(json);
        if (!_isCacheValid(suggestion.generatedAt, period)) return;
        if (!mounted) return;
        state = state.copyWith(weeklySuggestion: suggestion);
      } else {
        final suggestion = DailyMealSuggestion.fromJson(json);
        if (!_isCacheValid(suggestion.generatedAt, period)) return;
        if (!mounted) return;
        state = state.copyWith(suggestion: suggestion);
      }
    } catch (_) {}
  }

  Future<void> _clearDailyCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyToday);
    await prefs.remove(_keyTomorrow);
  }

  Future<void> _saveCache(SuggestionPeriod period) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _cacheKey(period);
    try {
      if (period == SuggestionPeriod.week && state.weeklySuggestion != null) {
        await prefs.setString(key, jsonEncode(state.weeklySuggestion!.toJson()));
      } else if (state.suggestion != null) {
        await prefs.setString(key, jsonEncode(state.suggestion!.toJson()));
      }
    } catch (_) {}
  }

  void setPeriod(SuggestionPeriod period) {
    if (state.period == period) return;
    state = state.copyWith(
      period: period,
      clearSuggestion: true,
      // Keep weeklySuggestion in state when switching to today/tomorrow
      // so _findWeeklyDayForPeriod can reference it for auto-generation.
      clearWeeklySuggestion: period == SuggestionPeriod.week,
      clearError: true,
    );
    _loadCacheAndAutoGenerate(period);
  }

  Future<void> _loadCacheAndAutoGenerate(SuggestionPeriod period) async {
    await _loadCache(period);
    if (!mounted) return;
    if (period != SuggestionPeriod.week &&
        state.suggestion == null &&
        state.weeklySuggestion != null) {
      final weeklyDay = _findWeeklyDayForPeriod(period);
      if (weeklyDay != null) await generate();
    }
  }

  Future<void> generate() async {
    final settings = _ref.read(settingsProvider);
    if (settings.currentApiKey.isEmpty) {
      state = state.copyWith(
        error: 'APIキーが設定されていません。設定 → AIキー設定 から入力してください。',
      );
      return;
    }

    final mealState = _ref.read(mealProvider);
    final model = settings.resolvedModelForProvider(settings.selectedProvider);
    final currentPeriod = state.period;
    final weeklyDay = currentPeriod != SuggestionPeriod.week
        ? _findWeeklyDayForPeriod(currentPeriod)
        : null;

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      if (currentPeriod == SuggestionPeriod.week) {
        final suggestion = await MealSuggestionService().suggestWeekly(
          calorieGoal: mealState.calorieGoal,
          proteinGoal: mealState.proteinGoal,
          fatGoal: mealState.fatGoal,
          carbsGoal: mealState.carbsGoal,
          apiKey: settings.currentApiKey,
          provider: settings.selectedProvider,
          model: model,
        );
        state = MealSuggestionState(
          weeklySuggestion: suggestion,
          period: currentPeriod,
        );
        // Invalidate daily caches so today/tomorrow auto-regenerate from new weekly
        await _clearDailyCache();
      } else {
        final suggestion = await MealSuggestionService().suggestDaily(
          calorieGoal: mealState.calorieGoal,
          proteinGoal: mealState.proteinGoal,
          fatGoal: mealState.fatGoal,
          carbsGoal: mealState.carbsGoal,
          todayItems: mealState.todayItems,
          apiKey: settings.currentApiKey,
          provider: settings.selectedProvider,
          model: model,
          isTomorrow: currentPeriod == SuggestionPeriod.tomorrow,
          weeklyDay: weeklyDay,
        );
        state = MealSuggestionState(
          suggestion: suggestion,
          period: currentPeriod,
        );
      }
      await _saveCache(currentPeriod);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  void clear() => state = MealSuggestionState(period: state.period);
}

final mealSuggestionProvider =
    StateNotifierProvider<MealSuggestionNotifier, MealSuggestionState>(
  (ref) => MealSuggestionNotifier(ref),
);
