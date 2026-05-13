import 'dart:convert';

import 'package:riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/food_item.dart';
import '../providers/settings_provider.dart';
import '../services/nutrition_advice_service.dart';

class AdviceState {
  final Map<String, String> adviceByDate;
  final bool isLoading;
  final String? error;
  final String? loadingDateKey;
  final String? errorDateKey;

  const AdviceState({
    this.adviceByDate = const {},
    this.isLoading = false,
    this.error,
    this.loadingDateKey,
    this.errorDateKey,
  });

  AdviceState copyWith({
    Map<String, String>? adviceByDate,
    bool? isLoading,
    String? error,
    String? loadingDateKey,
    String? errorDateKey,
    bool clearError = false,
    bool clearLoadingDate = false,
  }) =>
      AdviceState(
        adviceByDate: adviceByDate ?? this.adviceByDate,
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : (error ?? this.error),
        loadingDateKey:
            clearLoadingDate ? null : (loadingDateKey ?? this.loadingDateKey),
        errorDateKey: clearError ? null : (errorDateKey ?? this.errorDateKey),
      );
}

class AdviceNotifier extends StateNotifier<AdviceState> {
  AdviceNotifier() : super(const AdviceState()) {
    _loadCachedAdvice();
  }

  static const _prefsKey = 'nutritionAdviceByDate';
  final _service = NutritionAdviceService();

  static String dateKey(DateTime date) {
    final d = date.toLocal();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> _loadCachedAdvice() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final cached = decoded.map(
        (key, value) => MapEntry(key, value.toString()),
      );
      state = state.copyWith(adviceByDate: cached);
    } catch (_) {
      // 壊れたキャッシュは無視して、次回生成時に上書きする。
    }
  }

  Future<void> _saveCachedAdvice(Map<String, String> adviceByDate) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(adviceByDate));
  }

  Future<void> fetchAdvice({
    required List<FoodItem> items,
    required DateTime date,
    required int calorieGoal,
    required double proteinGoal,
    required double fatGoal,
    required double carbsGoal,
    double fiberGoal = 25,
    double sodiumGoal = 2300,
    required String adviceLevel,
    required String apiKey,
    required AiProviderType provider,
    String? model,
    bool forceRefresh = false,
  }) async {
    final dateKey = AdviceNotifier.dateKey(date);
    if (!forceRefresh && state.adviceByDate.containsKey(dateKey)) return;

    if (apiKey.isEmpty) {
      state = state.copyWith(
        error: '${provider.label} のAPIキーが設定されていません。⚙️設定から入力してください。',
        errorDateKey: dateKey,
        isLoading: false,
        clearLoadingDate: true,
      );
      return;
    }

    final resolvedModel = model ?? provider.defaultModel;
    state = state.copyWith(
      isLoading: true,
      loadingDateKey: dateKey,
      clearError: true,
    );
    try {
      final text = await _service.getAdvice(
        items: items,
        date: date,
        calorieGoal: calorieGoal,
        proteinGoal: proteinGoal,
        fatGoal: fatGoal,
        carbsGoal: carbsGoal,
        fiberGoal: fiberGoal,
        sodiumGoal: sodiumGoal,
        adviceLevel: adviceLevel,
        apiKey: apiKey,
        provider: provider,
        model: resolvedModel,
      );
      final updated = {...state.adviceByDate, dateKey: text};
      await _saveCachedAdvice(updated);
      state = state.copyWith(
        adviceByDate: updated,
        isLoading: false,
        clearLoadingDate: true,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        clearLoadingDate: true,
        error: e.toString().replaceFirst('Exception: ', ''),
        errorDateKey: dateKey,
      );
    }
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
    state = const AdviceState();
  }
}

final adviceProvider = StateNotifierProvider<AdviceNotifier, AdviceState>(
  (_) => AdviceNotifier(),
);
