import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/body_metrics.dart';
import '../services/database_service.dart';

class ProgressState {
  final List<BodyMetrics> metrics;
  final bool isLoading;

  ProgressState({
    this.metrics = const [],
    this.isLoading = true,
  });

  ProgressState copyWith({
    List<BodyMetrics>? metrics,
    bool? isLoading,
  }) {
    return ProgressState(
      metrics: metrics ?? this.metrics,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class ProgressNotifier extends StateNotifier<ProgressState> {
  ProgressNotifier() : super(ProgressState()) {
    _loadMetrics();
  }

  Future<void> _loadMetrics() async {
    state = state.copyWith(isLoading: true);
    final db = await DatabaseService().database;
    final List<Map<String, dynamic>> maps = await db.query(
      'body_metrics',
      orderBy: 'date ASC', // Ascending for graphs
    );

    state = state.copyWith(
      metrics: List.generate(maps.length, (i) => BodyMetrics.fromMap(maps[i])),
      isLoading: false,
    );
  }

  Future<void> addMetrics({
    required double weight,
    required double waist,
    required double bodyFatPercentage,
    String? imagePath,
  }) async {
    final db = await DatabaseService().database;
    final newMetrics = BodyMetrics(
      id: const Uuid().v4(),
      weight: weight,
      waist: waist,
      bodyFatPercentage: bodyFatPercentage,
      imagePath: imagePath,
      date: DateTime.now(),
    );

    await db.insert('body_metrics', newMetrics.toMap());
    await _loadMetrics();
  }

  Future<void> deleteMetrics(String id) async {
    final db = await DatabaseService().database;
    await db.delete('body_metrics', where: 'id = ?', whereArgs: [id]);
    await _loadMetrics();
  }
}

final progressProvider = StateNotifierProvider<ProgressNotifier, ProgressState>((ref) {
  return ProgressNotifier();
});
