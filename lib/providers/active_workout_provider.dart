import 'package:riverpod/legacy.dart';
import 'package:uuid/uuid.dart';
import '../models/training_log.dart';
import '../models/training_routine.dart';
import '../models/workout_session.dart';

class ActiveWorkoutState {
  final WorkoutSession? session;
  final bool isSaving;

  const ActiveWorkoutState({this.session, this.isSaving = false});

  bool get isActive => session != null && session!.isActive;

  ActiveWorkoutState copyWith({
    WorkoutSession? session,
    bool? isSaving,
    bool clearSession = false,
  }) =>
      ActiveWorkoutState(
        session: clearSession ? null : (session ?? this.session),
        isSaving: isSaving ?? this.isSaving,
      );
}

class ActiveWorkoutNotifier extends StateNotifier<ActiveWorkoutState> {
  ActiveWorkoutNotifier() : super(const ActiveWorkoutState());

  static const _uuid = Uuid();

  /// ルーティンのメモからエクササイズ名を解析して練習セッションを開始する
  void startSession({
    required TrainingRoutine routine,
    required List<TrainingLog> allLogs,
  }) {
    final exerciseNames = _parseExerciseNames(routine.note);
    if (exerciseNames.isEmpty) return;

    final exercises = exerciseNames.map((name) {
      // 過去ログから同名のものを探して提案値を計算
      final pastLogs = allLogs
          .where((l) =>
              l.exerciseName.toLowerCase() == name.toLowerCase())
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));

      final latest = pastLogs.isNotEmpty ? pastLogs.first : null;

      return SessionExercise(
        name: name,
        exerciseType: latest?.exerciseType ?? ExerciseType.freeWeight,
        targetSets: latest?.sets ?? 3,
        suggestedWeight: latest?.weight ?? 0,
        suggestedReps: latest?.reps ?? 10,
        intervalSeconds: latest?.interval ?? 90,
      );
    }).toList();

    state = state.copyWith(
      session: WorkoutSession(
        exercises: exercises,
        startedAt: DateTime.now(),
      ),
    );
  }

  /// 自由形式のセッション（エクササイズ名リストを直接指定）
  void startFreeSession(List<String> exerciseNames, List<TrainingLog> allLogs) {
    final routine = TrainingRoutine(
      id: '',
      name: '',
      weekdays: [],
      note: exerciseNames.join('\n'),
    );
    startSession(routine: routine, allLogs: allLogs);
  }

  /// 現在のセットの記録を確認してログに追加し、次のセットへ進む
  void confirmSet({
    required double weight,
    required int reps,
    int? rpe,
    String note = '',
  }) {
    final session = state.session;
    if (session == null || session.isFinished) return;

    final exercise = session.currentExercise!;
    final log = TrainingLog(
      id: _uuid.v4(),
      exerciseName: exercise.name,
      exerciseType: exercise.exerciseType,
      weight: weight,
      reps: reps,
      sets: 1,
      interval: exercise.intervalSeconds,
      rpe: rpe,
      note: note,
      date: DateTime.now(),
    );

    final newLogs = [...session.completedLogs, log];
    final nextSet = session.currentSet + 1;
    final totalSets = exercise.targetSets;

    if (nextSet > totalSets) {
      // 次のエクササイズへ
      final nextExerciseIndex = session.currentExerciseIndex + 1;
      state = state.copyWith(
        session: session.copyWith(
          completedLogs: newLogs,
          currentExerciseIndex: nextExerciseIndex,
          currentSet: 1,
        ),
      );
    } else {
      state = state.copyWith(
        session: session.copyWith(
          completedLogs: newLogs,
          currentSet: nextSet,
        ),
      );
    }
  }

  /// 現在のエクササイズをスキップして次へ
  void skipExercise() {
    final session = state.session;
    if (session == null || session.isFinished) return;

    state = state.copyWith(
      session: session.copyWith(
        currentExerciseIndex: session.currentExerciseIndex + 1,
        currentSet: 1,
      ),
    );
  }

  /// セッションを破棄
  void abandonSession() {
    state = state.copyWith(clearSession: true);
  }

  /// セッション完了 - ログリストを返す（保存は呼び出し元が行う）
  List<TrainingLog> finishSession() {
    final logs = state.session?.completedLogs ?? [];
    state = state.copyWith(clearSession: true);
    return logs;
  }

  List<String> _parseExerciseNames(String note) {
    if (note.trim().isEmpty) return [];
    return note
        .split(RegExp(r'[\n,、]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }
}

final activeWorkoutProvider =
    StateNotifierProvider<ActiveWorkoutNotifier, ActiveWorkoutState>(
  (_) => ActiveWorkoutNotifier(),
);
