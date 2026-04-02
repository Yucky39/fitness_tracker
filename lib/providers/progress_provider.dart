import 'package:riverpod/legacy.dart';
import 'package:uuid/uuid.dart';
import '../models/body_metrics.dart';
import '../services/database_service.dart';
import '../services/sync_service.dart';

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
  }) =>
      ProgressState(
        metrics: metrics ?? this.metrics,
        isLoading: isLoading ?? this.isLoading,
      );

  /// 最新の記録
  BodyMetrics? get latest =>
      metrics.isEmpty ? null : metrics.last;

  /// 直前の記録（最新の1つ前）
  BodyMetrics? get previous =>
      metrics.length < 2 ? null : metrics[metrics.length - 2];

  /// 週ごとの平均を返す（グラフ用）
  List<({DateTime weekStart, double avgWeight, double avgFat, double avgWaist})>
      get weeklyAverages {
    if (metrics.isEmpty) return [];
    final Map<String, List<BodyMetrics>> byWeek = {};
    for (final m in metrics) {
      final monday =
          m.date.subtract(Duration(days: m.date.weekday - 1));
      final key =
          '${monday.year}-${monday.month.toString().padLeft(2, '0')}-${monday.day.toString().padLeft(2, '0')}';
      byWeek.putIfAbsent(key, () => []).add(m);
    }
    final sorted = byWeek.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return sorted.map((e) {
      final list = e.value;
      final weekStart = list.first.date
          .subtract(Duration(days: list.first.date.weekday - 1));
      return (
        weekStart: DateTime(weekStart.year, weekStart.month, weekStart.day),
        avgWeight: list.map((m) => m.weight).reduce((a, b) => a + b) /
            list.length,
        avgFat:
            list.map((m) => m.bodyFatPercentage).reduce((a, b) => a + b) /
                list.length,
        avgWaist:
            list.map((m) => m.waist).reduce((a, b) => a + b) / list.length,
      );
    }).toList();
  }

  /// 月ごとの平均を返す（グラフ用）
  List<({DateTime monthStart, double avgWeight, double avgFat, double avgWaist})>
      get monthlyAverages {
    if (metrics.isEmpty) return [];
    final Map<String, List<BodyMetrics>> byMonth = {};
    for (final m in metrics) {
      final key =
          '${m.date.year}-${m.date.month.toString().padLeft(2, '0')}';
      byMonth.putIfAbsent(key, () => []).add(m);
    }
    final sorted = byMonth.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return sorted.map((e) {
      final list = e.value;
      final monthStart = DateTime(list.first.date.year, list.first.date.month);
      return (
        monthStart: monthStart,
        avgWeight: list.map((m) => m.weight).reduce((a, b) => a + b) /
            list.length,
        avgFat:
            list.map((m) => m.bodyFatPercentage).reduce((a, b) => a + b) /
                list.length,
        avgWaist:
            list.map((m) => m.waist).reduce((a, b) => a + b) / list.length,
      );
    }).toList();
  }
}

class ProgressNotifier extends StateNotifier<ProgressState> {
  ProgressNotifier() : super(ProgressState()) {
    _loadMetrics();
  }

  Future<void> _loadMetrics() async {
    state = state.copyWith(isLoading: true);
    final adapter = await DatabaseService().database;
    final maps = await adapter.query(
      'body_metrics',
      orderBy: 'date ASC',
    );
    state = state.copyWith(
      metrics: maps.map(BodyMetrics.fromMap).toList(),
      isLoading: false,
    );
  }

  Future<void> addMetrics({
    required double weight,
    required double waist,
    required double bodyFatPercentage,
    String? imagePath,
  }) async {
    final adapter = await DatabaseService().database;
    final newMetrics = BodyMetrics(
      id: const Uuid().v4(),
      weight: weight,
      waist: waist,
      bodyFatPercentage: bodyFatPercentage,
      imagePath: imagePath,
      date: DateTime.now(),
    );
    await adapter.insert('body_metrics', newMetrics.toMap());
    SyncService().syncRecord('body_metrics', newMetrics.toMap());
    await _loadMetrics();
  }

  Future<void> updateMetrics(BodyMetrics updated) async {
    final adapter = await DatabaseService().database;
    await adapter.update(
      'body_metrics',
      updated.toMap(),
      where: 'id = ?',
      whereArgs: [updated.id],
    );
    SyncService().syncRecord('body_metrics', updated.toMap());
    await _loadMetrics();
  }

  Future<void> deleteMetrics(String id) async {
    final adapter = await DatabaseService().database;
    await adapter.delete('body_metrics', where: 'id = ?', whereArgs: [id]);
    SyncService().deleteRecord('body_metrics', id);
    await _loadMetrics();
  }
}

final progressProvider =
    StateNotifierProvider<ProgressNotifier, ProgressState>((ref) {
  return ProgressNotifier();
});
