import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/training_log.dart';
import '../providers/energy_profile_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/subscription_provider.dart';
import '../services/training_advice_service.dart';
import '../services/training_calorie_calculator.dart';

class TrainingDailyAdviceState {
  /// 日付文字列（yyyy-MM-dd）→ アドバイステキスト
  final Map<String, String> adviceByDate;
  final bool isLoading;
  final String? error;
  final String? loadingDateKey;
  final String? errorDateKey;

  const TrainingDailyAdviceState({
    this.adviceByDate = const {},
    this.isLoading = false,
    this.error,
    this.loadingDateKey,
    this.errorDateKey,
  });

  TrainingDailyAdviceState copyWith({
    Map<String, String>? adviceByDate,
    bool? isLoading,
    String? error,
    String? loadingDateKey,
    String? errorDateKey,
    bool clearError = false,
    bool clearLoadingDate = false,
  }) {
    return TrainingDailyAdviceState(
      adviceByDate: adviceByDate ?? this.adviceByDate,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      loadingDateKey:
          clearLoadingDate ? null : (loadingDateKey ?? this.loadingDateKey),
      errorDateKey: clearError ? null : (errorDateKey ?? this.errorDateKey),
    );
  }
}

class TrainingDailyAdviceNotifier
    extends StateNotifier<TrainingDailyAdviceState> {
  final Ref _ref;
  static const _prefsKey = 'trainingDailyAdviceByDate';

  TrainingDailyAdviceNotifier(this._ref)
      : super(const TrainingDailyAdviceState()) {
    _loadCachedAdvice();
  }

  static String _dateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
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

  /// 指定日のトレーニングセッション全体のAIアドバイスを取得する。
  /// キャッシュがある場合は再取得をスキップ（[forceRefresh] で強制再取得可能）。
  Future<void> fetchDailyAdvice({
    required List<TrainingLog> dayLogs,
    required List<TrainingLog> allLogs,
    required DateTime date,
    required String adviceLevel,
    required String apiKey,
    required AiProviderType provider,
    String? model,
    String? sleepContext,
    bool forceRefresh = false,
  }) async {
    final key = _dateKey(date);

    if (!forceRefresh && state.adviceByDate.containsKey(key)) return;

    final isSubscribed = _ref.read(isSubscribedProvider);

    if (!isSubscribed && apiKey.isEmpty) {
      state = state.copyWith(
        error: '__paywall__',
        errorDateKey: key,
        clearLoadingDate: true,
        isLoading: false,
      );
      return;
    }

    if (dayLogs.isEmpty) {
      state = state.copyWith(
        error: 'この日のトレーニング記録がありません。',
        errorDateKey: key,
        clearLoadingDate: true,
        isLoading: false,
      );
      return;
    }

    state = state.copyWith(
      isLoading: true,
      loadingDateKey: key,
      clearError: true,
    );

    try {
      final bodyWeightKg = _ref.read(energyProfileProvider).weightKg;
      final effectiveBw = bodyWeightKg > 0
          ? bodyWeightKg
          : TrainingCalorieCalculator.defaultBodyWeightKg;

      final effectiveModel =
          (model != null && model.isNotEmpty) ? model : null;

      final text = await TrainingAdviceService().getDailyAdvice(
        dayLogs: dayLogs,
        allLogs: allLogs,
        date: date,
        bodyWeightKg: effectiveBw,
        adviceLevel: adviceLevel,
        useSystemAi: isSubscribed,
        apiKey: apiKey,
        provider: provider,
        model: effectiveModel,
        sleepContext: sleepContext,
      );

      final updated = {...state.adviceByDate, key: text};
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
        errorDateKey: key,
      );
    }
  }

  /// 指定日のキャッシュを削除して再取得できるようにする
  Future<void> clearAdviceForDate(DateTime date) async {
    final key = _dateKey(date);
    final updated = Map<String, String>.from(state.adviceByDate)..remove(key);
    await _saveCachedAdvice(updated);
    state = state.copyWith(adviceByDate: updated, clearError: true);
  }
}

final trainingDailyAdviceProvider = StateNotifierProvider<
    TrainingDailyAdviceNotifier, TrainingDailyAdviceState>(
  (ref) => TrainingDailyAdviceNotifier(ref),
);
