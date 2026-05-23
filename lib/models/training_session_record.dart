import 'dart:convert';

/// トレーニングセッション（1回のトレーニングのまとまり）の記録。
/// 1日に複数登録可能。completed_at を主キーの一部とせず UUID で管理。
class TrainingSessionRecord {
  final String id;
  final String? name;
  final DateTime startedAt;
  final DateTime? finishedAt;

  /// 紐付く TrainingLog の ID リスト（順序保持）
  final List<String> logIds;

  /// ストレッチ提案のためにキャッシュする種目名リスト
  final List<String> exerciseNames;

  /// AI が生成したストレッチ推奨テキスト
  final String? stretchRecommendation;

  final String? note;

  const TrainingSessionRecord({
    required this.id,
    this.name,
    required this.startedAt,
    this.finishedAt,
    required this.logIds,
    required this.exerciseNames,
    this.stretchRecommendation,
    this.note,
  });

  TrainingSessionRecord copyWith({
    String? id,
    String? name,
    bool clearName = false,
    DateTime? startedAt,
    DateTime? finishedAt,
    bool clearFinishedAt = false,
    List<String>? logIds,
    List<String>? exerciseNames,
    String? stretchRecommendation,
    bool clearStretch = false,
    String? note,
    bool clearNote = false,
  }) {
    return TrainingSessionRecord(
      id: id ?? this.id,
      name: clearName ? null : (name ?? this.name),
      startedAt: startedAt ?? this.startedAt,
      finishedAt: clearFinishedAt ? null : (finishedAt ?? this.finishedAt),
      logIds: logIds ?? this.logIds,
      exerciseNames: exerciseNames ?? this.exerciseNames,
      stretchRecommendation: clearStretch
          ? null
          : (stretchRecommendation ?? this.stretchRecommendation),
      note: clearNote ? null : (note ?? this.note),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'started_at': startedAt.toIso8601String(),
      'finished_at': finishedAt?.toIso8601String(),
      'log_ids': jsonEncode(logIds),
      'exercise_names': jsonEncode(exerciseNames),
      'stretch_recommendation': stretchRecommendation,
      'note': note,
    };
  }

  factory TrainingSessionRecord.fromMap(Map<String, dynamic> map) {
    List<String> decodeStringList(dynamic raw) {
      if (raw == null) return [];
      if (raw is List) return List<String>.from(raw);
      try {
        final decoded = jsonDecode(raw as String);
        if (decoded is List) return List<String>.from(decoded);
      } catch (_) {}
      return [];
    }

    return TrainingSessionRecord(
      id: map['id'] as String,
      name: map['name'] as String?,
      startedAt: DateTime.parse(map['started_at'] as String),
      finishedAt: map['finished_at'] != null
          ? DateTime.parse(map['finished_at'] as String)
          : null,
      logIds: decodeStringList(map['log_ids']),
      exerciseNames: decodeStringList(map['exercise_names']),
      stretchRecommendation: map['stretch_recommendation'] as String?,
      note: map['note'] as String?,
    );
  }
}
