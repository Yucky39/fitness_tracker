import 'package:riverpod/legacy.dart';
import '../models/training_log.dart';
import '../providers/settings_provider.dart';
import '../services/training_advice_service.dart';

class TrainingAdviceState {
  final String? adviceText;
  final bool isLoading;
  final String? error;

  const TrainingAdviceState({
    this.adviceText,
    this.isLoading = false,
    this.error,
  });

  TrainingAdviceState copyWith({
    String? adviceText,
    bool? isLoading,
    String? error,
  }) =>
      TrainingAdviceState(
        adviceText: adviceText ?? this.adviceText,
        isLoading: isLoading ?? this.isLoading,
        error: error ?? this.error,
      );
}

class TrainingAdviceNotifier extends StateNotifier<TrainingAdviceState> {
  TrainingAdviceNotifier() : super(const TrainingAdviceState());

  Future<void> fetchAdvice({
    required List<TrainingLog> todayLogs,
    required List<TrainingLog> allLogs,
    required DateTime date,
    required String adviceLevel,
    required String apiKey,
    required AiProviderType provider,
  }) async {
    if (apiKey.isEmpty) {
      state = const TrainingAdviceState(
        error: 'APIキーが設定されていません。設定画面から入力してください。',
      );
      return;
    }
    if (todayLogs.isEmpty) {
      state = const TrainingAdviceState(
        error: '今日のトレーニング記録がありません。',
      );
      return;
    }

    state = const TrainingAdviceState(isLoading: true);

    try {
      // Build history map: exercise -> past logs (excluding today, up to 5 most recent)
      final today = DateTime(date.year, date.month, date.day);
      final Map<String, List<TrainingLog>> historyByExercise = {};

      for (final log in allLogs) {
        final logDate =
            DateTime(log.date.year, log.date.month, log.date.day);
        if (logDate.isAtSameMomentAs(today)) continue; // skip today
        historyByExercise
            .putIfAbsent(log.exerciseName, () => [])
            .add(log);
      }
      // Keep only the 5 most recent per exercise (allLogs is already DESC)
      for (final key in historyByExercise.keys) {
        if (historyByExercise[key]!.length > 5) {
          historyByExercise[key] = historyByExercise[key]!.take(5).toList();
        }
      }

      final text = await TrainingAdviceService().getAdvice(
        todayLogs: todayLogs,
        historyByExercise: historyByExercise,
        date: date,
        adviceLevel: adviceLevel,
        apiKey: apiKey,
        provider: provider,
      );

      state = TrainingAdviceState(adviceText: text);
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      state = TrainingAdviceState(error: msg);
    }
  }

  void clear() => state = const TrainingAdviceState();
}

final trainingAdviceProvider =
    StateNotifierProvider<TrainingAdviceNotifier, TrainingAdviceState>(
        (_) => TrainingAdviceNotifier());
