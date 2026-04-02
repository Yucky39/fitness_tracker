import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/training_routine.dart';
import '../services/database_service.dart';

class RoutineState {
  final List<TrainingRoutine> routines;
  final bool isLoading;

  RoutineState({this.routines = const [], this.isLoading = true});

  RoutineState copyWith({List<TrainingRoutine>? routines, bool? isLoading}) =>
      RoutineState(
        routines: routines ?? this.routines,
        isLoading: isLoading ?? this.isLoading,
      );
}

class RoutineNotifier extends StateNotifier<RoutineState> {
  RoutineNotifier() : super(RoutineState()) {
    _load();
  }

  Future<void> _load() async {
    state = state.copyWith(isLoading: true);
    final db = await DatabaseService().database;
    final maps = await db.query('training_routines', orderBy: 'name ASC');
    state = state.copyWith(
      routines: maps.map(TrainingRoutine.fromMap).toList(),
      isLoading: false,
    );
  }

  Future<void> addRoutine({
    required String name,
    required List<int> weekdays,
    required String note,
  }) async {
    final db = await DatabaseService().database;
    final routine = TrainingRoutine(
      id: const Uuid().v4(),
      name: name,
      weekdays: weekdays,
      note: note,
    );
    await db.insert('training_routines', routine.toMap());
    await _load();
  }

  Future<void> updateRoutine(TrainingRoutine routine) async {
    final db = await DatabaseService().database;
    await db.update(
      'training_routines',
      routine.toMap(),
      where: 'id = ?',
      whereArgs: [routine.id],
    );
    await _load();
  }

  Future<void> deleteRoutine(String id) async {
    final db = await DatabaseService().database;
    await db.delete('training_routines', where: 'id = ?', whereArgs: [id]);
    await _load();
  }

  List<TrainingRoutine> getTodaysRoutines() {
    final today = DateTime.now().weekday;
    return state.routines.where((r) => r.weekdays.contains(today)).toList();
  }
}

final routineProvider =
    StateNotifierProvider<RoutineNotifier, RoutineState>((_) => RoutineNotifier());
