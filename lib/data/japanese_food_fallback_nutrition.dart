import '../models/food_search_result.dart';
import 'japanese_food_search_hints.dart';

/// API が空・失敗のときの目安（日本食品標準成分表 2020（八訂）付近の代表値。商品により異なります）
class JapaneseFoodFallbackNutrition {
  JapaneseFoodFallbackNutrition._();

  static const Map<String, _Row> _byEnglishHint = {
    'egg': _Row(label: '卵（全卵・目安）', kcal: 151, p: 12.3, f: 10.3, c: 0.3),
    'chicken breast': _Row(label: '鶏むね肉（皮なし・目安）', kcal: 108, p: 22.3, f: 1.5, c: 0.0),
    'chicken thigh': _Row(label: '鶏もも肉（皮なし・目安）', kcal: 116, p: 19.2, f: 3.9, c: 0.0),
    'chicken': _Row(label: '鶏肉（可食部・目安）', kcal: 190, p: 20.3, f: 11.5, c: 0.0),
    'pork': _Row(label: '豚肉（もも・目安）', kcal: 221, p: 20.2, f: 14.7, c: 0.0),
    'pork belly': _Row(label: '豚バラ肉（目安）', kcal: 386, p: 13.2, f: 35.6, c: 0.0),
    'beef': _Row(label: '牛肉（もも・目安）', kcal: 182, p: 20.7, f: 10.4, c: 0.0),
    'ground beef': _Row(label: '合挽き肉（目安）', kcal: 263, p: 17.0, f: 20.0, c: 0.0),
    'ground meat': _Row(label: '合挽き肉（目安）', kcal: 263, p: 17.0, f: 20.0, c: 0.0),
    'rice': _Row(label: 'うるち米（精白米・目安）', kcal: 358, p: 6.1, f: 0.9, c: 77.6),
    'white rice': _Row(label: 'うるち米（精白米・目安）', kcal: 358, p: 6.1, f: 0.9, c: 77.6),
    'cooked rice': _Row(label: 'ご飯（炊き上がり・目安）', kcal: 168, p: 2.5, f: 0.3, c: 37.1),
    'brown rice': _Row(label: '玄米（目安）', kcal: 356, p: 6.8, f: 2.7, c: 75.0),
    'tofu': _Row(label: '豆腐（木綿・目安）', kcal: 72, p: 6.6, f: 4.2, c: 2.0),
    'silken tofu': _Row(label: '豆腐（絹ごし・目安）', kcal: 56, p: 5.1, f: 3.0, c: 2.1),
    'firm tofu': _Row(label: '豆腐（木綿・目安）', kcal: 72, p: 6.6, f: 4.2, c: 2.0),
    'natto': _Row(label: '納豆（目安）', kcal: 200, p: 16.5, f: 10.0, c: 12.5),
    'salmon': _Row(label: '鮭（生・目安）', kcal: 142, p: 20.7, f: 6.2, c: 0.0),
    'mackerel': _Row(label: 'さば（生・目安）', kcal: 205, p: 19.0, f: 14.0, c: 0.0),
    'tuna': _Row(label: 'まぐろ（赤身・目安）', kcal: 125, p: 28.0, f: 1.0, c: 0.0),
    'milk': _Row(label: '牛乳（成分無調整・目安）', kcal: 67, p: 3.3, f: 3.8, c: 4.8),
    'yogurt': _Row(label: 'ヨーグルト（無糖・目安）', kcal: 62, p: 3.6, f: 3.0, c: 4.7),
    'cheese': _Row(label: 'チーズ（チェダー系・目安）', kcal: 404, p: 25.0, f: 33.0, c: 1.3),
    'bread': _Row(label: '食パン（6枚切・目安）', kcal: 264, p: 8.7, f: 4.2, c: 47.4),
    'white bread': _Row(label: '食パン（目安）', kcal: 264, p: 8.7, f: 4.2, c: 47.4),
    'udon': _Row(label: 'うどん（乾麺・目安）', kcal: 352, p: 9.5, f: 1.5, c: 72.0),
    'soba': _Row(label: 'そば（乾麺・目安）', kcal: 352, p: 12.0, f: 3.1, c: 69.6),
    'pasta': _Row(label: 'スパゲティ（乾麺・目安）', kcal: 378, p: 14.0, f: 2.5, c: 73.0),
    'spaghetti': _Row(label: 'スパゲティ（乾麺・目安）', kcal: 378, p: 14.0, f: 2.5, c: 73.0),
    'ramen noodles': _Row(label: '中華麺（生・目安）', kcal: 281, p: 9.5, f: 1.5, c: 57.0),
    'oil': _Row(label: 'サラダ油（目安）', kcal: 924, p: 0.0, f: 100.0, c: 0.0),
    'olive oil': _Row(label: 'オリーブオイル（目安）', kcal: 884, p: 0.0, f: 100.0, c: 0.0),
    'sugar': _Row(label: '砂糖（目安）', kcal: 387, p: 0.0, f: 0.0, c: 99.8),
    'honey': _Row(label: 'はちみつ（目安）', kcal: 294, p: 0.2, f: 0.0, c: 79.7),
    'banana': _Row(label: 'バナナ（果肉・目安）', kcal: 86, p: 1.0, f: 0.2, c: 22.5),
    'apple': _Row(label: 'りんご（果肉・目安）', kcal: 54, p: 0.3, f: 0.2, c: 14.1),
    'tomato': _Row(label: 'トマト（生・目安）', kcal: 19, p: 0.7, f: 0.1, c: 4.7),
    'cucumber': _Row(label: 'きゅうり（生・目安）', kcal: 14, p: 0.7, f: 0.1, c: 3.6),
    'lettuce': _Row(label: 'レタス（生・目安）', kcal: 12, p: 1.0, f: 0.1, c: 2.2),
    'cabbage': _Row(label: 'キャベツ（生・目安）', kcal: 23, p: 1.3, f: 0.2, c: 5.2),
    'potato': _Row(label: 'じゃがいも（可食部・目安）', kcal: 76, p: 1.6, f: 0.1, c: 17.6),
    'onion': _Row(label: '玉ねぎ（生・目安）', kcal: 37, p: 1.0, f: 0.1, c: 9.0),
    'carrot': _Row(label: 'にんじん（生・目安）', kcal: 37, p: 0.7, f: 0.2, c: 8.8),
    'broccoli': _Row(label: 'ブロッコリー（生・目安）', kcal: 33, p: 4.3, f: 0.5, c: 4.6),
    'avocado': _Row(label: 'アボカド（可食部・目安）', kcal: 194, p: 1.6, f: 19.5, c: 7.9),
    'almond': _Row(label: 'アーモンド（目安）', kcal: 601, p: 19.5, f: 51.2, c: 19.7),
    'walnut': _Row(label: 'くるみ（目安）', kcal: 674, p: 14.8, f: 68.5, c: 3.9),
    'protein powder': _Row(label: 'ホエイプロテイン（目安）', kcal: 400, p: 75.0, f: 7.0, c: 8.0),
    'protein bar': _Row(label: 'プロテインバー（目安）', kcal: 400, p: 25.0, f: 15.0, c: 35.0),
    'nori': _Row(label: 'のり（焼き・目安）', kcal: 188, p: 41.4, f: 3.7, c: 44.4),
    'wakame': _Row(label: 'わかめ（乾・目安）', kcal: 134, p: 7.5, f: 1.4, c: 22.1),
    'kelp': _Row(label: '昆布（乾・目安）', kcal: 162, p: 7.9, f: 1.4, c: 28.2),
  };

  static List<FoodSearchResult> match(String query) {
    final q = query.trim();
    if (q.isEmpty) return [];

    final hint = JapaneseFoodSearchHints.lookup(q);
    if (hint != null) {
      final row = _byEnglishHint[hint];
      if (row != null) {
        return [_toResult(row)];
      }
    }

    final keys = _byEnglishHint.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    final ql = q.toLowerCase();
    for (final k in keys) {
      if (ql.contains(k)) {
        return [_toResult(_byEnglishHint[k]!)];
      }
    }
    return [];
  }

  static FoodSearchResult _toResult(_Row row) => FoodSearchResult(
        name: '${row.label} ※目安',
        caloriesPer100g: row.kcal.round(),
        proteinPer100g: row.p,
        fatPer100g: row.f,
        carbsPer100g: row.c,
        dataSourceLabel: '日本食品標準成分表に基づくアプリ内目安',
      );
}

class _Row {
  final String label;
  final double kcal;
  final double p;
  final double f;
  final double c;

  const _Row({
    required this.label,
    required this.kcal,
    required this.p,
    required this.f,
    required this.c,
  });
}
