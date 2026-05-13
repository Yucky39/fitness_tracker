/// 筋肉部位の列挙型（12部位）
enum MuscleGroup {
  chest('胸', '胸筋'),
  back('背中', '広背筋・僧帽筋'),
  shoulders('肩', '三角筋'),
  biceps('上腕二頭筋', '力こぶ'),
  triceps('上腕三頭筋', '二の腕'),
  forearms('前腕', '前腕'),
  abs('腹筋', '腹直筋・腹斜筋'),
  quads('大腿四頭筋', '前腿'),
  hamstrings('ハムストリング', '後腿'),
  glutes('臀部', '大臀筋'),
  calves('ふくらはぎ', '下腿三頭筋'),
  cardio('全身(有酸素)', '心肺機能');

  const MuscleGroup(this.label, this.description);
  final String label;
  final String description;
}

/// 種目名 → 主に使われる筋肉部位のマッピング
/// キーは部分一致で検索する（toLowerCase）
const Map<String, List<MuscleGroup>> exerciseMuscleMap = {
  // 胸
  'ベンチプレス': [MuscleGroup.chest, MuscleGroup.triceps, MuscleGroup.shoulders],
  'インクラインベンチプレス': [
    MuscleGroup.chest,
    MuscleGroup.shoulders,
    MuscleGroup.triceps
  ],
  'ダンベルフライ': [MuscleGroup.chest, MuscleGroup.shoulders],
  'ダンベルプレス': [MuscleGroup.chest, MuscleGroup.triceps],
  'チェストプレス': [MuscleGroup.chest, MuscleGroup.triceps],
  'ペックデック': [MuscleGroup.chest],
  'プッシュアップ': [MuscleGroup.chest, MuscleGroup.triceps, MuscleGroup.shoulders],
  'ディップス': [MuscleGroup.chest, MuscleGroup.triceps],
  'ケーブルクロスオーバー': [MuscleGroup.chest],

  // 背中
  'デッドリフト': [MuscleGroup.back, MuscleGroup.glutes, MuscleGroup.hamstrings],
  'バーベルロウ': [MuscleGroup.back, MuscleGroup.biceps],
  'ダンベルロウ': [MuscleGroup.back, MuscleGroup.biceps],
  'ラットプルダウン': [MuscleGroup.back, MuscleGroup.biceps],
  'シーテッドロウ': [MuscleGroup.back, MuscleGroup.biceps],
  '懸垂': [MuscleGroup.back, MuscleGroup.biceps],
  'チンアップ': [MuscleGroup.back, MuscleGroup.biceps],
  'プルアップ': [MuscleGroup.back, MuscleGroup.biceps],
  'ルーマニアンデッドリフト': [
    MuscleGroup.back,
    MuscleGroup.hamstrings,
    MuscleGroup.glutes
  ],

  // 肩
  'ショルダープレス': [MuscleGroup.shoulders, MuscleGroup.triceps],
  'サイドレイズ': [MuscleGroup.shoulders],
  'フロントレイズ': [MuscleGroup.shoulders],
  'リアレイズ': [MuscleGroup.shoulders, MuscleGroup.back],
  'アーノルドプレス': [MuscleGroup.shoulders, MuscleGroup.triceps],

  // 腕
  'バーベルカール': [MuscleGroup.biceps, MuscleGroup.forearms],
  'ダンベルカール': [MuscleGroup.biceps, MuscleGroup.forearms],
  'ハンマーカール': [MuscleGroup.biceps, MuscleGroup.forearms],
  'ケーブルカール': [MuscleGroup.biceps, MuscleGroup.forearms],
  'トライセプスエクステンション': [MuscleGroup.triceps],
  'トライセプスプッシュダウン': [MuscleGroup.triceps],
  'ライイングトライセプス': [MuscleGroup.triceps],
  'スカルクラッシャー': [MuscleGroup.triceps],

  // 脚
  'スクワット': [MuscleGroup.quads, MuscleGroup.glutes, MuscleGroup.hamstrings],
  'フロントスクワット': [MuscleGroup.quads, MuscleGroup.glutes],
  'ゴブレットスクワット': [MuscleGroup.quads, MuscleGroup.glutes],
  'ダンベルスクワット': [MuscleGroup.quads, MuscleGroup.glutes],
  'レッグプレス': [MuscleGroup.quads, MuscleGroup.glutes, MuscleGroup.hamstrings],
  'レッグエクステンション': [MuscleGroup.quads],
  'レッグカール': [MuscleGroup.hamstrings],
  'ランジ': [MuscleGroup.quads, MuscleGroup.glutes, MuscleGroup.hamstrings],
  'ブルガリアンスクワット': [MuscleGroup.quads, MuscleGroup.glutes],
  'ヒップスラスト': [MuscleGroup.glutes, MuscleGroup.hamstrings],
  'カーフレイズ': [MuscleGroup.calves],
  'シシースクワット': [MuscleGroup.quads],

  // 腹筋
  'プランク': [MuscleGroup.abs],
  'クランチ': [MuscleGroup.abs],
  'レッグレイズ': [MuscleGroup.abs],
  'ケーブルクランチ': [MuscleGroup.abs],
  'アブローラー': [MuscleGroup.abs],
  'バーピー': [MuscleGroup.abs, MuscleGroup.cardio],

  // 腕（前腕）
  'リストカール': [MuscleGroup.forearms],
  'リバースカール': [MuscleGroup.forearms, MuscleGroup.biceps],
  'コンセントレーションカール': [MuscleGroup.biceps],
  'インクラインダンベルカール': [MuscleGroup.biceps],

  // 有酸素
  'ランニング': [MuscleGroup.cardio, MuscleGroup.calves, MuscleGroup.quads],
  'ウォーキング': [MuscleGroup.cardio, MuscleGroup.calves],
  'サイクリング': [MuscleGroup.cardio, MuscleGroup.quads, MuscleGroup.calves],
  '水泳': [MuscleGroup.cardio, MuscleGroup.back, MuscleGroup.shoulders],
  'hiit': [MuscleGroup.cardio],
  'HIIT': [MuscleGroup.cardio],
  'ジャンプロープ': [MuscleGroup.cardio, MuscleGroup.calves],
  '縄跳び': [MuscleGroup.cardio, MuscleGroup.calves],
  'エアロビクス': [MuscleGroup.cardio],
  'ローイングマシン': [MuscleGroup.cardio, MuscleGroup.back],
  'エリプティカル': [MuscleGroup.cardio, MuscleGroup.quads],
  'トレッドミル': [MuscleGroup.cardio, MuscleGroup.calves, MuscleGroup.quads],
  'エアロバイク': [MuscleGroup.cardio, MuscleGroup.quads, MuscleGroup.calves],
};

/// 部位カテゴリの列挙型（UIフィルター用）
enum BodyPartCategory {
  chest('胸'),
  back('背中'),
  shoulders('肩'),
  biceps('二の腕'),
  triceps('三頭筋'),
  forearms('前腕'),
  abs('腹筋'),
  legs('脚'),
  cardio('有酸素');

  const BodyPartCategory(this.label);
  final String label;
}

const Map<BodyPartCategory, List<MuscleGroup>> _bodyPartMuscleGroups = {
  BodyPartCategory.chest: [MuscleGroup.chest],
  BodyPartCategory.back: [MuscleGroup.back],
  BodyPartCategory.shoulders: [MuscleGroup.shoulders],
  BodyPartCategory.biceps: [MuscleGroup.biceps],
  BodyPartCategory.triceps: [MuscleGroup.triceps],
  BodyPartCategory.forearms: [MuscleGroup.forearms],
  BodyPartCategory.abs: [MuscleGroup.abs],
  BodyPartCategory.legs: [
    MuscleGroup.quads,
    MuscleGroup.hamstrings,
    MuscleGroup.glutes,
    MuscleGroup.calves,
  ],
  BodyPartCategory.cardio: [MuscleGroup.cardio],
};

/// アプリ共通の種目キー（小文字・空白除去）。
String normalizeExerciseStorageKey(String raw) =>
    raw.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '');

/// 種目リストを部位カテゴリでフィルタリング
List<String> filterExercisesByBodyPart(
  BodyPartCategory category,
  Iterable<String> exercises, [
  Map<String, List<MuscleGroup>> communityMuscleOverrides = const {},
]) {
  final targetGroups = _bodyPartMuscleGroups[category]!;
  return exercises.where((exercise) {
    final muscles = muscleGroupsResolved(exercise, communityMuscleOverrides);
    return muscles.any((m) => targetGroups.contains(m));
  }).toList();
}

/// 埋め込みマップのみから筋肉部位を解決（部分一致）
List<MuscleGroup> _muscleGroupsFromBuiltInMapOnly(String exerciseName) {
  if (exerciseMuscleMap.containsKey(exerciseName)) {
    return exerciseMuscleMap[exerciseName]!;
  }
  final lower = exerciseName.toLowerCase();
  for (final entry in exerciseMuscleMap.entries) {
    if (lower.contains(entry.key.toLowerCase()) ||
        entry.key.toLowerCase().contains(lower)) {
      return entry.value;
    }
  }
  return [MuscleGroup.chest];
}

/// 共通種目 DB の上書きを優先し、なければ埋め込みマップで解決する。
List<MuscleGroup> muscleGroupsResolved(
  String exerciseName,
  Map<String, List<MuscleGroup>> communityByNormalizedKey,
) {
  final key = normalizeExerciseStorageKey(exerciseName);
  if (key.isNotEmpty) {
    final fromCommunity = communityByNormalizedKey[key];
    if (fromCommunity != null && fromCommunity.isNotEmpty) {
      return List<MuscleGroup>.from(fromCommunity);
    }
  }
  return _muscleGroupsFromBuiltInMapOnly(exerciseName);
}

/// [muscleGroupsResolved] と同様だが、共通 DB を参照しない場合（テストなど）
List<MuscleGroup> getMuscleGroups(String exerciseName) =>
    muscleGroupsResolved(exerciseName, const {});
