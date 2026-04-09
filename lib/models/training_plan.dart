import 'dart:convert';
import 'training_log.dart';

enum TrainingGoal {
  bulk,
  cut,
  maintain;

  String get label => switch (this) {
        TrainingGoal.bulk => 'バルクアップ（筋肥大）',
        TrainingGoal.cut => 'ダイエット（減量）',
        TrainingGoal.maintain => '現状維持',
      };

  String get emoji => switch (this) {
        TrainingGoal.bulk => '💪',
        TrainingGoal.cut => '🔥',
        TrainingGoal.maintain => '⚖️',
      };

  static TrainingGoal fromString(String s) => switch (s) {
        'bulk' => TrainingGoal.bulk,
        'cut' => TrainingGoal.cut,
        _ => TrainingGoal.maintain,
      };
}

/// ダイエット目標時のトレーニングスタイル（部位痩せは不可能なため部位選択の代わりに使用）
enum CutStyle {
  strength,
  cardio,
  balanced;

  String get label => switch (this) {
        CutStyle.strength => '筋トレ中心',
        CutStyle.cardio => '有酸素中心',
        CutStyle.balanced => 'バランス型',
      };

  String get description => switch (this) {
        CutStyle.strength => '筋量を維持しながら減量・引き締め重視',
        CutStyle.cardio => '有酸素運動で脂肪燃焼を最優先',
        CutStyle.balanced => '筋トレ＋有酸素をバランスよく組み合わせ',
      };

  static CutStyle fromString(String s) {
    return CutStyle.values.firstWhere(
      (e) => e.name == s,
      orElse: () => CutStyle.balanced,
    );
  }
}

enum EquipmentOption {
  fullGym,
  freeWeights,
  dumbbellOnly,
  bodyweightOnly;

  String get label => switch (this) {
        EquipmentOption.fullGym => 'ジム（全器具）',
        EquipmentOption.freeWeights => '自宅（ダンベル＋バーベル）',
        EquipmentOption.dumbbellOnly => '自宅（ダンベルのみ）',
        EquipmentOption.bodyweightOnly => '自重のみ',
      };

  String get description => switch (this) {
        EquipmentOption.fullGym => 'マシン・フリーウェイト・有酸素器具すべて利用可',
        EquipmentOption.freeWeights => 'バーベル・ダンベルが使える（マシンなし）',
        EquipmentOption.dumbbellOnly => 'ダンベルと簡単な器具のみ',
        EquipmentOption.bodyweightOnly => '器具なし・自重トレーニングのみ',
      };

  String get icon => switch (this) {
        EquipmentOption.fullGym => '🏋️',
        EquipmentOption.freeWeights => '🏠',
        EquipmentOption.dumbbellOnly => '💪',
        EquipmentOption.bodyweightOnly => '🤸',
      };

  static EquipmentOption fromString(String s) {
    return EquipmentOption.values.firstWhere(
      (e) => e.name == s,
      orElse: () => EquipmentOption.fullGym,
    );
  }
}

enum MuscleGroup {
  chest,
  back,
  legs,
  shoulders,
  arms,
  core,
  fullBody;

  String get label => switch (this) {
        MuscleGroup.chest => '胸',
        MuscleGroup.back => '背中',
        MuscleGroup.legs => '脚',
        MuscleGroup.shoulders => '肩',
        MuscleGroup.arms => '腕',
        MuscleGroup.core => '体幹・腹筋',
        MuscleGroup.fullBody => '全身',
      };

  static MuscleGroup? tryParse(String s) {
    try {
      return MuscleGroup.values.firstWhere((e) => e.name == s);
    } catch (_) {
      return null;
    }
  }
}

enum PlanIntensity {
  light,
  moderate,
  hard,
  veryHard;

  String get label => switch (this) {
        PlanIntensity.light => '軽め',
        PlanIntensity.moderate => '普通',
        PlanIntensity.hard => 'ハード',
        PlanIntensity.veryHard => '超ハード',
      };

  String get description => switch (this) {
        PlanIntensity.light => '週2〜3回・初心者向け・無理なく継続',
        PlanIntensity.moderate => '週3〜4回・標準的な負荷・着実に進歩',
        PlanIntensity.hard => '週4〜5回・高負荷・本格的なトレーニング',
        PlanIntensity.veryHard => '週5〜6回・上級者向け・限界への挑戦',
      };

  static PlanIntensity fromString(String s) {
    return PlanIntensity.values.firstWhere(
      (e) => e.name == s,
      orElse: () => PlanIntensity.moderate,
    );
  }
}

class TrainingPlanExercise {
  final String name;
  final ExerciseType type;
  final int sets;
  final String repRange;
  final double? suggestedWeightKg;
  final int restSeconds;
  final String? note;

  const TrainingPlanExercise({
    required this.name,
    required this.type,
    required this.sets,
    required this.repRange,
    this.suggestedWeightKg,
    required this.restSeconds,
    this.note,
  });

  Map<String, dynamic> toMap() => {
        'name': name,
        'type': type.name,
        'sets': sets,
        'rep_range': repRange,
        'suggested_weight_kg': suggestedWeightKg,
        'rest_seconds': restSeconds,
        'note': note,
      };

  factory TrainingPlanExercise.fromMap(Map<String, dynamic> m) {
    ExerciseType type;
    try {
      type = ExerciseType.values.firstWhere(
        (e) => e.name == (m['type'] as String? ?? ''),
      );
    } catch (_) {
      type = ExerciseType.freeWeight;
    }
    return TrainingPlanExercise(
      name: m['name'] as String? ?? '',
      type: type,
      sets: (m['sets'] as num?)?.toInt() ?? 3,
      repRange: m['rep_range'] as String? ?? '10',
      suggestedWeightKg: (m['suggested_weight_kg'] as num?)?.toDouble(),
      restSeconds: (m['rest_seconds'] as num?)?.toInt() ?? 90,
      note: m['note'] as String?,
    );
  }
}

class TrainingPlanDay {
  final String label;
  final List<TrainingPlanExercise> exercises;

  const TrainingPlanDay({required this.label, required this.exercises});

  Map<String, dynamic> toMap() => {
        'label': label,
        'exercises': exercises.map((e) => e.toMap()).toList(),
      };

  factory TrainingPlanDay.fromMap(Map<String, dynamic> m) {
    final exList = (m['exercises'] as List<dynamic>? ?? [])
        .map((e) => TrainingPlanExercise.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
    return TrainingPlanDay(
      label: m['label'] as String? ?? '',
      exercises: exList,
    );
  }
}

class TrainingPlan {
  final String id;
  final String name;
  final TrainingGoal goal;
  /// goal == cut のときは null。代わりに cutStyle を使う
  final List<MuscleGroup> targetMuscles;
  /// goal == cut のときのみ有効
  final CutStyle? cutStyle;
  final int daysPerWeek;
  final PlanIntensity intensity;
  final EquipmentOption equipment;
  final List<TrainingPlanDay> days;
  final String? overview;
  final DateTime createdAt;

  const TrainingPlan({
    required this.id,
    required this.name,
    required this.goal,
    required this.targetMuscles,
    this.cutStyle,
    required this.daysPerWeek,
    required this.intensity,
    this.equipment = EquipmentOption.fullGym,
    required this.days,
    this.overview,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'goal': goal.name,
        'target_muscles': jsonEncode(targetMuscles.map((e) => e.name).toList()),
        'cut_style': cutStyle?.name,
        'days_per_week': daysPerWeek,
        'intensity': intensity.name,
        'equipment': equipment.name,
        'plan_days': jsonEncode(days.map((d) => d.toMap()).toList()),
        'overview': overview,
        'created_at': createdAt.toIso8601String(),
      };

  factory TrainingPlan.fromMap(Map<String, dynamic> m) {
    final muscleRaw =
        jsonDecode(m['target_muscles'] as String? ?? '[]') as List<dynamic>;
    final muscles = muscleRaw
        .map((s) => MuscleGroup.tryParse(s as String))
        .whereType<MuscleGroup>()
        .toList();

    final daysRaw =
        jsonDecode(m['plan_days'] as String? ?? '[]') as List<dynamic>;
    final days = daysRaw
        .map((d) => TrainingPlanDay.fromMap(Map<String, dynamic>.from(d as Map)))
        .toList();

    final cutStyleRaw = m['cut_style'] as String?;

    return TrainingPlan(
      id: m['id'] as String,
      name: m['name'] as String? ?? 'トレーニングプラン',
      goal: TrainingGoal.fromString(m['goal'] as String? ?? 'maintain'),
      targetMuscles: muscles,
      cutStyle: cutStyleRaw != null ? CutStyle.fromString(cutStyleRaw) : null,
      daysPerWeek: (m['days_per_week'] as num?)?.toInt() ?? 3,
      intensity: PlanIntensity.fromString(m['intensity'] as String? ?? 'moderate'),
      equipment: EquipmentOption.fromString(m['equipment'] as String? ?? 'fullGym'),
      days: days,
      overview: m['overview'] as String?,
      createdAt: DateTime.parse(m['created_at'] as String),
    );
  }
}
