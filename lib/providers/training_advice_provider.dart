import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/legacy.dart';
import '../models/training_log.dart';
import '../providers/settings_provider.dart';
import '../providers/training_provider.dart';
import '../services/training_advice_service.dart';

class TrainingAdviceState {
  /// 記録IDごとの評価テキスト（セッション中のインメモリキャッシュ）
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

  /// 1件の記録を評価。[allLogs] は日付降順を想定（同種目の直近比較用）。
  /// 評価完了後は DB に永続保存する。
  Future<void> fetchAdviceForLog({
    required TrainingLog log,
    required List<TrainingLog> allLogs,
    required String adviceLevel,
    required String apiKey,
    required AiProviderType provider,
    String? model,
    String? sleepContext,
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

      final weeklyLoadContext =
          TrainingAdviceService.buildWeeklyLoadContext(allLogs, log.date);

      final text = await TrainingAdviceService().getAdvice(
        focusLogs: [log],
        historyByExercise: historyByExercise,
        adviceLevel: adviceLevel,
        apiKey: apiKey,
        provider: provider,
        model: model,
        sleepContext: sleepContext,
        weeklyLoadContext: weeklyLoadContext,
      );

      // インメモリに反映
      state = TrainingAdviceState(
        adviceByLogId: {...state.adviceByLogId, log.id: text},
      );

      // DB に永続保存
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
