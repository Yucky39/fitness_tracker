import 'training_log.dart';

class SessionExercise {
  final String name;
  final ExerciseType exerciseType;
  final int targetSets;
  final double suggestedWeight;
  final int suggestedReps;
  final int intervalSeconds;

  const SessionExercise({
    required this.name,
    this.exerciseType = ExerciseType.freeWeight,
    this.targetSets = 3,
    this.suggestedWeight = 0,
    this.suggestedReps = 10,
    this.intervalSeconds = 90,
  });
}

class WorkoutSession {
  final List<SessionExercise> exercises;
  final int currentExerciseIndex;
  final int currentSet;
  final List<TrainingLog> completedLogs;
  final DateTime startedAt;
  final bool isActive;

  const WorkoutSession({
    required this.exercises,
    this.currentExerciseIndex = 0,
    this.currentSet = 1,
    this.completedLogs = const [],
    required this.startedAt,
    this.isActive = true,
  });

  SessionExercise? get currentExercise =>
      currentExerciseIndex < exercises.length
          ? exercises[currentExerciseIndex]
          : null;

  bool get isFinished =>
      currentExerciseIndex >= exercises.length;

  WorkoutSession copyWith({
    int? currentExerciseIndex,
    int? currentSet,
    List<TrainingLog>? completedLogs,
    bool? isActive,
  }) =>
      WorkoutSession(
        exercises: exercises,
        currentExerciseIndex:
            currentExerciseIndex ?? this.currentExerciseIndex,
        currentSet: currentSet ?? this.currentSet,
        completedLogs: completedLogs ?? this.completedLogs,
        startedAt: startedAt,
        isActive: isActive ?? this.isActive,
      );
}
