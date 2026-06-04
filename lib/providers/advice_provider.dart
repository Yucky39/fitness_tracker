import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/food_item.dart';
import '../providers/ai_access.dart';
import '../providers/settings_provider.dart';
import '../providers/subscription_provider.dart';
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
  final Ref _ref;

  AdviceNotifier(this._ref) : super(const AdviceState()) {
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
    bool forceRefresh = false,
    String? apiKey,
    AiProviderType? provider,
    String? model,
  }) async {
    final isSubscribed = _ref.read(isSubscribedProvider);
    final settings = _ref.read(settingsProvider);
    final effectiveApiKey = apiKey ?? settings.currentApiKey;
    final effectiveProvider = provider ?? settings.selectedProvider;
    final modelStr = model ?? settings.currentModel;

    final access =
        resolveAiAccess(isSubscribed: isSubscribed, apiKey: effectiveApiKey);
    if (!access.allowed) {
      state = const AdviceState(error: '__paywall__');
      return;
    }

    final dk = AdviceNotifier.dateKey(date);
    if (!forceRefresh && state.adviceByDate.containsKey(dk)) return;

    final resolvedModel = modelStr.isNotEmpty
        ? modelStr
        : effectiveProvider.defaultModel;

    state = state.copyWith(
      isLoading: true,
      loadingDateKey: dk,
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
        useSystemAi: access.useSystemAi,
        apiKey: effectiveApiKey,
        provider: effectiveProvider,
        model: resolvedModel,
      );
      final updated = {...state.adviceByDate, dk: text};
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
        errorDateKey: dk,
      );
    }
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
    state = const AdviceState();
  }
}

final adviceProvider =
    StateNotifierProvider<AdviceNotifier, AdviceState>((ref) => AdviceNotifier(ref));
