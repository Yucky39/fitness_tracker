import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/training_log.dart';
import '../services/database_service.dart';
import '../services/sync_service.dart';

class TrainingState {
  final List<TrainingLog> logs;
  final bool isLoading;

  TrainingState({
    this.logs = const [],
    this.isLoading = true,
  });

  TrainingState copyWith({
    List<TrainingLog>? logs,
    bool? isLoading,
  }) {
    return TrainingState(
      logs: logs ?? this.logs,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class TrainingNotifier extends StateNotifier<TrainingState> {
  TrainingNotifier() : super(TrainingState()) {
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    state = state.copyWith(isLoading: true);
    final adapter = await DatabaseService().database;
    final List<Map<String, dynamic>> maps = await adapter.query(
      'training_logs',
      orderBy: 'date DESC',
    );


    state = state.copyWith(
      logs: List.generate(maps.length, (i) => TrainingLog.fromMap(maps[i])),
      isLoading: false,
    );
  }

  Future<void> addLog({
    required String exerciseName,
    required double weight,
    required int reps,
    required int sets,
    required int interval,
    required String note,
  }) async {
    final adapter = await DatabaseService().database;
    final newLog = TrainingLog(
      id: const Uuid().v4(),
      exerciseName: exerciseName,
      weight: weight,
      reps: reps,
      sets: sets,
      interval: interval,
      note: note,
      date: DateTime.now(),
    );

    await adapter.insert('training_logs', newLog.toMap());
    SyncService().syncRecord('training_logs', newLog.toMap());
    await _loadLogs();
  }

  Future<void> deleteLog(String id) async {
    final adapter = await DatabaseService().database;
    await adapter.delete('training_logs', where: 'id = ?', whereArgs: [id]);
    SyncService().deleteRecord('training_logs', id);
    await _loadLogs();
  }

  // Helper to get previous log for a specific exercise
  TrainingLog? getPreviousLog(String exerciseName) {
    try {
      // Filter logs for the exercise, exclude today (optional, but "previous" usually means before now)
      // For simplicity, just find the first one that isn't the one we are about to add (which doesn't exist yet)
      // Actually, since we just want "last recorded", we can take the first one from the sorted list
      // that matches the name.
      return state.logs.firstWhere((log) => log.exerciseName == exerciseName);
    } catch (e) {
      return null;
    }
  }
}

final trainingProvider = StateNotifierProvider<TrainingNotifier, TrainingState>((ref) {
  return TrainingNotifier();
});
