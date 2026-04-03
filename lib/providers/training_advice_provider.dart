import 'package:riverpod/legacy.dart';
import '../models/training_log.dart';
import '../providers/settings_provider.dart';
import '../services/training_advice_service.dart';

class TrainingAdviceState {
  /// 記録IDごとの評価テキスト（再取得で上書き）
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
  TrainingAdviceNotifier() : super(const TrainingAdviceState());

  /// 1件の記録を評価。[allLogs] は日付降順を想定（同種目の直近比較用）。
  Future<void> fetchAdviceForLog({
    required TrainingLog log,
    required List<TrainingLog> allLogs,
    required String adviceLevel,
    required String apiKey,
    required AiProviderType provider,
    String? model,
  }) async {
    if (apiKey.isEmpty) {
      state = TrainingAdviceState(
        adviceByLogId: state.adviceByLogId,
        errorLogId: log.id,
        errorMessage: 'APIキーが設定されていません。設定画面から入力してください。',
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

      final historyByExercise = <String, List<TrainingLog>>{
        log.exerciseName: history,
      };

      final text = await TrainingAdviceService().getAdvice(
        focusLogs: [log],
        historyByExercise: historyByExercise,
        adviceLevel: adviceLevel,
        apiKey: apiKey,
        provider: provider,
        model: model,
      );

      state = TrainingAdviceState(
        adviceByLogId: {...state.adviceByLogId, log.id: text},
      );
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
        (_) => TrainingAdviceNotifier());
