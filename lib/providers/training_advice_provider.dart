import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/legacy.dart';
import '../models/training_log.dart';
import '../providers/settings_provider.dart';
import '../providers/subscription_provider.dart';
import '../providers/training_provider.dart';
import '../services/training_advice_service.dart';

class TrainingAdviceState {
  final Map<String, String> adviceByLogId;
  final String? loadingLogId;
  final String? errorLogId;
  final String? errorMessage;

  const TrainingAdviceState({
    this.adviceByLogId = const {},
    this.loadingLogId,
    this.errorLogId,
    this.errorMessage,
  });
}

class TrainingAdviceNotifier extends StateNotifier<TrainingAdviceState> {
  final Ref _ref;

  TrainingAdviceNotifier(this._ref) : super(const TrainingAdviceState());

  Future<void> fetchAdviceForLog({
    required TrainingLog log,
    required List<TrainingLog> allLogs,
    required String adviceLevel,
    String? sleepContext,
  }) async {
    final isSubscribed = _ref.read(isSubscribedProvider);
    final settings = _ref.read(settingsProvider);
    final apiKey = settings.currentApiKey;

    if (!isSubscribed && apiKey.isEmpty) {
      state = TrainingAdviceState(
        adviceByLogId: state.adviceByLogId,
        errorLogId: log.id,
        errorMessage: '__paywall__',
      );
      return;
    }

    state = TrainingAdviceState(
      adviceByLogId: state.adviceByLogId,
      loadingLogId: log.id,
    );

    try {
      final history = allLogs
          .where((l) => l.id != log.id && l.exerciseName == log.exerciseName)
          .take(5)
          .toList();

      final weeklyLoadContext =
          TrainingAdviceService.buildWeeklyLoadContext(allLogs, log.date);

      final text = await TrainingAdviceService().getAdvice(
        focusLogs: [log],
        historyByExercise: {log.exerciseName: history},
        adviceLevel: adviceLevel,
        useSystemAi: isSubscribed,
        apiKey: apiKey,
        provider: settings.selectedProvider,
        model: settings.currentModel.isNotEmpty ? settings.currentModel : null,
        sleepContext: sleepContext,
        weeklyLoadContext: weeklyLoadContext,
      );

      state = TrainingAdviceState(
        adviceByLogId: {...state.adviceByLogId, log.id: text},
      );

      await _ref.read(trainingProvider.notifier).updateLogAdvice(log.id, text);
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      state = TrainingAdviceState(
        adviceByLogId: state.adviceByLogId,
        errorLogId: log.id,
        errorMessage: msg,
      );
    }
  }

  void clear() => state = const TrainingAdviceState();
}

final trainingAdviceProvider =
    StateNotifierProvider<TrainingAdviceNotifier, TrainingAdviceState>(
        (ref) => TrainingAdviceNotifier(ref));
