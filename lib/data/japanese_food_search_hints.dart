/// Open Food Facts は英語・ローマ字の商品名が多いため、日本語クエリを補助検索語に変換する。
/// 完全一致 → 部分一致の順で最初のヒントを返す。
class JapaneseFoodSearchHints {
  JapaneseFoodSearchHints._();

  /// キーワード（日本語）→ 補助検索語（英語など）
  static const Map<String, String> _exact = {
    '卵': 'egg',
    'たまご': 'egg',
    'タマゴ': 'egg',
    '鶏卵': 'egg',
    '鶏むね肉': 'chicken breast',
    '鶏胸肉': 'chicken breast',
    '鶏もも肉': 'chicken thigh',
    '鶏肉': 'chicken',
    '豚肉': 'pork',
    '豚バラ': 'pork belly',
    '牛肉': 'beef',
    '合挽き肉': 'ground beef',
    '米': 'rice',
    '白米': 'white rice',
    'ご飯': 'cooked rice',
    '玄米': 'brown rice',
    '豆腐': 'tofu',
    '絹ごし豆腐': 'silken tofu',
    '木綿豆腐': 'firm tofu',
    '納豆': 'natto',
    '鮭': 'salmon',
    '鯖': 'mackerel',
    'マグロ': 'tuna',
    '海苔': 'nori',
    'わかめ': 'wakame',
    '昆布': 'kelp',
    '牛乳': 'milk',
    'ヨーグルト': 'yogurt',
    'チーズ': 'cheese',
    'パン': 'bread',
    '食パン': 'white bread',
    'うどん': 'udon',
    'そば': 'soba',
    'パスタ': 'pasta',
    'スパゲッティ': 'spaghetti',
    'ラーメン': 'ramen noodles',
    '油': 'oil',
    'オリーブオイル': 'olive oil',
    '砂糖': 'sugar',
    'はちみつ': 'honey',
    'バナナ': 'banana',
    'りんご': 'apple',
    'トマト': 'tomato',
    'きゅうり': 'cucumber',
    'レタス': 'lettuce',
    'キャベツ': 'cabbage',
    'じゃがいも': 'potato',
    '玉ねぎ': 'onion',
    'にんじん': 'carrot',
    'ブロッコリー': 'broccoli',
    'アボカド': 'avocado',
    'アーモンド': 'almond',
    'くるみ': 'walnut',
    'プロテイン': 'protein powder',
    'プロテインバー': 'protein bar',
  };

  /// 部分一致用（長いキーを先に試すとよい順に並べる）
  static const List<MapEntry<String, String>> _contains = [
    MapEntry('鶏むね', 'chicken breast'),
    MapEntry('鶏胸', 'chicken breast'),
    MapEntry('鶏もも', 'chicken thigh'),
    MapEntry('合挽', 'ground meat'),
    MapEntry('絹ごし', 'silken tofu'),
    MapEntry('木綿', 'firm tofu'),
    MapEntry('オリーブ', 'olive oil'),
    MapEntry('スパゲティ', 'spaghetti'),
    MapEntry('ヨーグルト', 'yogurt'),
  ];

  /// 補助検索に使う英語などの語。見つからなければ null。
  static String? lookup(String query) {
    final t = query.trim();
    if (t.isEmpty) return null;
    final hit = _exact[t];
    if (hit != null) return hit;
    for (final e in _contains) {
      if (t.contains(e.key)) return e.value;
    }
    return null;
  }
}
