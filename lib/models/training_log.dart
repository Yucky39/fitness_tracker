/// 種目の器具カテゴリ
enum ExerciseType {
  freeWeight('free_weight', 'フリーウェイト'),
  machine('machine', 'マシン'),
  bodyweight('bodyweight', '自重'),
  cardio('cardio', '有酸素運動');

  const ExerciseType(this.key, this.label);
  final String key;
  final String label;

  static ExerciseType fromKey(String? key) => ExerciseType.values.firstWhere(
        (e) => e.key == key,
        orElse: () => ExerciseType.freeWeight,
      );
}

class TrainingLog {
  final String id;
  final String exerciseName;
  final ExerciseType exerciseType;
  final double weight;
  final int reps;
  final int sets;
  final int interval;
  /// 有酸素種目：走行距離 (km)。筋トレ種目では 0。
  final double distanceKm;
  /// 有酸素種目：運動時間 (分)。筋トレ種目では 0。
  final int durationMinutes;
  final String note;
  final DateTime date;

  TrainingLog({
    required this.id,
    required this.exerciseName,
    this.exerciseType = ExerciseType.freeWeight,
    required this.weight,
    required this.reps,
    required this.sets,
    required this.interval,
    this.distanceKm = 0,
    this.durationMinutes = 0,
    required this.note,
    required this.date,
  });

  TrainingLog copyWith({
    String? id,
    String? exerciseName,
    ExerciseType? exerciseType,
    double? weight,
    int? reps,
    int? sets,
    int? interval,
    double? distanceKm,
    int? durationMinutes,
    String? note,
    DateTime? date,
  }) =>
      TrainingLog(
        id: id ?? this.id,
        exerciseName: exerciseName ?? this.exerciseName,
        exerciseType: exerciseType ?? this.exerciseType,
        weight: weight ?? this.weight,
        reps: reps ?? this.reps,
        sets: sets ?? this.sets,
        interval: interval ?? this.interval,
        distanceKm: distanceKm ?? this.distanceKm,
        durationMinutes: durationMinutes ?? this.durationMinutes,
        note: note ?? this.note,
        date: date ?? this.date,
      );

  /// 総ボリューム (kg)  例: 100kg × 10rep × 3set = 3000kg（筋トレのみ）
  double get totalVolume => weight * reps * sets;

  /// ペース (分/km)。有酸素種目で distance > 0 の場合のみ有効。
  double? get paceMinPerKm {
    if (exerciseType != ExerciseType.cardio) return null;
    if (distanceKm <= 0 || durationMinutes <= 0) return null;
    return durationMinutes / distanceKm;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'exerciseName': exerciseName,
      'exercise_type': exerciseType.key,
      'weight': weight,
      'reps': reps,
      'sets': sets,
      'interval': interval,
      'distance_km': distanceKm,
      'duration_minutes': durationMinutes,
      'note': note,
      'date': date.toIso8601String(),
    };
  }

  factory TrainingLog.fromMap(Map<String, dynamic> map) {
    return TrainingLog(
      id: map['id'] as String,
      exerciseName: map['exerciseName'] as String,
      exerciseType: ExerciseType.fromKey(map['exercise_type'] as String?),
      weight: (map['weight'] as num).toDouble(),
      reps: map['reps'] as int,
      sets: map['sets'] as int,
      interval: map['interval'] as int,
      distanceKm: (map['distance_km'] as num? ?? 0).toDouble(),
      durationMinutes: map['duration_minutes'] as int? ?? 0,
      note: map['note'] as String,
      date: DateTime.parse(map['date'] as String),
    );
  }
}

/// よく使われる種目と器具種別のプリセット
class ExercisePresets {
  static const Map<String, List<String>> byCategory = {
    'フリーウェイト（胸）': [
      'ベンチプレス',
      'インクラインベンチプレス',
      'ダンベルフライ',
      'ダンベルプレス',
    ],
    'フリーウェイト（背中）': [
      'デッドリフト',
      'バーベルロウ',
      'ダンベルロウ',
    ],
    'フリーウェイト（脚）': [
      'スクワット',
      'フロントスクワット',
      'ルーマニアンデッドリフト',
      'ランジ',
      'ダンベルスクワット',
    ],
    'フリーウェイト（肩・腕）': [
      'ショルダープレス',
      'サイドレイズ',
      'バーベルカール',
      'ダンベルカール',
      'トライセプスエクステンション',
    ],
    'マシン（胸・背中）': [
      'チェストプレス',
      'ペックデック',
      'ラットプルダウン',
      'シーテッドロウ',
      'ケーブルクロスオーバー',
    ],
    'マシン（脚）': [
      'レッグプレス',
      'レッグカール',
      'レッグエクステンション',
      'カーフレイズ',
    ],
    'マシン（肩・腕）': [
      'ショルダープレス（マシン）',
      'ケーブルカール',
      'トライセプスプッシュダウン',
    ],
    '自重': [
      '懸垂（チンアップ）',
      'プルアップ',
      'ディップス',
      'プッシュアップ',
      'スクワット（自重）',
      'ランジ（自重）',
      'プランク',
      'バーピー',
    ],
    '有酸素運動': [
      'ランニング',
      'ウォーキング',
      'サイクリング',
      '水泳',
      'HIIT',
      'ジャンプロープ',
      'エアロビクス',
      'ローイングマシン',
      'エリプティカル',
      'トレッドミル',
    ],
  };

  /// 種目名から器具種別を推定
  static ExerciseType inferType(String name) {
    for (final entry in byCategory.entries) {
      if (entry.value.contains(name)) {
        if (entry.key.contains('マシン')) return ExerciseType.machine;
        if (entry.key.contains('自重')) return ExerciseType.bodyweight;
        if (entry.key.contains('有酸素')) return ExerciseType.cardio;
        return ExerciseType.freeWeight;
      }
    }
    return ExerciseType.freeWeight;
  }
}
