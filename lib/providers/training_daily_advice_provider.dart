import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/legacy.dart';
import '../models/training_log.dart';
import '../providers/energy_profile_provider.dart';
import '../providers/settings_provider.dart';
import '../services/training_advice_service.dart';
import '../services/training_calorie_calculator.dart';

class TrainingDailyAdviceState {
  /// 日付文字列（yyyy-MM-dd）→ アドバイステキスト
  final Map<String, String> adviceByDate;
  final bool isLoading;
  final String? error;
  final String? loadingDateKey;

  const TrainingDailyAdviceState({
    this.adviceByDate = const {},
    this.isLoading = false,
    this.error,
    this.loadingDateKey,
  });

  TrainingDailyAdviceState copyWith({
    Map<String, String>? adviceByDate,
    bool? isLoading,
    String? error,
    String? loadingDateKey,
    bool clearError = false,
    bool clearLoadingDate = false,
  }) {
    return TrainingDailyAdviceState(
      adviceByDate: adviceByDate ?? this.adviceByDate,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      loadingDateKey: clearLoadingDate ? null : (loadingDateKey ?? this.loadingDateKey),
    );
  }
}

class TrainingDailyAdviceNotifier extends StateNotifier<TrainingDailyAdviceState> {
  final Ref _ref;

  TrainingDailyAdviceNotifier(this._ref) : super(const TrainingDailyAdviceState());

  static String _dateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
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

    if (apiKey.isEmpty) {
      state = state.copyWith(
        error: '${provider.label} のAPIキーが設定されていません。⚙️設定から入力してください。',
        clearLoadingDate: true,
        isLoading: false,
      );
      return;
    }

    if (dayLogs.isEmpty) {
      state = state.copyWith(
        error: 'この日のトレーニング記録がありません。',
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

      final text = await TrainingAdviceService().getDailyAdvice(
        dayLogs: dayLogs,
        allLogs: allLogs,
        date: date,
        bodyWeightKg: effectiveBw,
        adviceLevel: adviceLevel,
        apiKey: apiKey,
        provider: provider,
        model: model,
        sleepContext: sleepContext,
      );

      state = state.copyWith(
        adviceByDate: {...state.adviceByDate, key: text},
        isLoading: false,
        clearLoadingDate: true,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        clearLoadingDate: true,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  /// 指定日のキャッシュを削除して再取得できるようにする
  void clearAdviceForDate(DateTime date) {
    final key = _dateKey(date);
    final updated = Map<String, String>.from(state.adviceByDate)..remove(key);
    state = state.copyWith(adviceByDate: updated, clearError: true);
  }
}

final trainingDailyAdviceProvider =
    StateNotifierProvider<TrainingDailyAdviceNotifier, TrainingDailyAdviceState>(
  (ref) => TrainingDailyAdviceNotifier(ref),
);
