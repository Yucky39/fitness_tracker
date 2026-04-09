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
  'インクラインベンチプレス': [MuscleGroup.chest, MuscleGroup.shoulders, MuscleGroup.triceps],
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
  'ルーマニアンデッドリフト': [MuscleGroup.back, MuscleGroup.hamstrings, MuscleGroup.glutes],

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
  'ケーブルカール': [MuscleGroup.biceps],
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

  // 有酸素
  'ランニング': [MuscleGroup.cardio, MuscleGroup.calves, MuscleGroup.quads],
  'ウォーキング': [MuscleGroup.cardio, MuscleGroup.calves],
  'サイクリング': [MuscleGroup.cardio, MuscleGroup.quads, MuscleGroup.calves],
  '水泳': [MuscleGroup.cardio, MuscleGroup.back, MuscleGroup.shoulders],
  'hiit': [MuscleGroup.cardio],
  'HIIT': [MuscleGroup.cardio],
  'ジャンプロープ': [MuscleGroup.cardio, MuscleGroup.calves],
  'エアロビクス': [MuscleGroup.cardio],
  'ローイングマシン': [MuscleGroup.cardio, MuscleGroup.back],
  'エリプティカル': [MuscleGroup.cardio, MuscleGroup.quads],
  'トレッドミル': [MuscleGroup.cardio, MuscleGroup.calves, MuscleGroup.quads],
};

/// 種目名から筋肉部位リストを取得（部分一致で検索）
List<MuscleGroup> getMuscleGroups(String exerciseName) {
  // 完全一致を優先
  if (exerciseMuscleMap.containsKey(exerciseName)) {
    return exerciseMuscleMap[exerciseName]!;
  }
  // 部分一致で検索
  final lower = exerciseName.toLowerCase();
  for (final entry in exerciseMuscleMap.entries) {
    if (lower.contains(entry.key.toLowerCase()) ||
        entry.key.toLowerCase().contains(lower)) {
      return entry.value;
    }
  }
  return [MuscleGroup.chest]; // フォールバック：不明種目は胸として扱う
}
