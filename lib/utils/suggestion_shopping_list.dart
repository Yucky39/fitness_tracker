import '../models/meal_suggestion.dart';
import '../services/ingredient_merge_service.dart';

/// AI 提案メニューから買い物メモ用に集計した1行分
class AggregatedShoppingItem implements Comparable<AggregatedShoppingItem> {
  final String name;
  final Map<String, int> amountCounts;

  const AggregatedShoppingItem({
    required this.name,
    required this.amountCounts,
  });

  /// 表示用（例: `200g×3、1個`）
  String get amountsLine {
    if (amountCounts.isEmpty) return '（分量の記載なし）';
    final parts = amountCounts.entries.map((e) {
      if (e.value <= 1) return e.key;
      return '${e.key}×${e.value}';
    }).toList()
      ..sort();
    return parts.join('、');
  }

  @override
  int compareTo(AggregatedShoppingItem other) =>
      name.compareTo(other.name);
}

class _AggBucket {
  _AggBucket(this.displayName, {required this.isExplicit});

  String displayName;
  final bool isExplicit;
  final Set<String> variantLabels = {};
  final Map<String, int> amountCounts = {};
}

String _surfaceKey(String raw) =>
    raw.trim().replaceAll(RegExp(r'\s+'), ' ');

String _stripParenthetical(String s) {
  return s
      .replaceAll(RegExp(r'[（(][^）)]*[）)]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

String _normalizeKey(String raw) {
  var s = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
  return s.toLowerCase();
}

/// 括弧・スペース・一部パターンを寄せた「相対クラスタ」キー（DBに無い表記同士の候補まとめ）
String softClusterKey(String raw) {
  var s = _surfaceKey(raw);
  s = s.replaceAll('（たたき）', 'のたたき').replaceAll('(たたき)', 'のたたき');
  s = _stripParenthetical(s);
  s = s.replaceAll(' ', '').replaceAll('　', '');
  final buf = StringBuffer();
  for (final c in s.split('')) {
    final u = c.codeUnitAt(0);
    if (u >= 0x41 && u <= 0x5a) {
      buf.write(c.toLowerCase());
    } else {
      buf.write(c);
    }
  }
  s = buf.toString();
  if (s.startsWith('真')) {
    var rest = s.substring(1);
    rest = rest
        .replaceAll('ダラ', 'たら')
        .replaceAll('タラ', 'たら')
        .replaceAll('鱈', 'たら')
        .replaceAll('だら', 'たら');
    s = '真$rest';
  }
  return s;
}

String _resolveBucketKey(String surface, IngredientMergeContext ctx) {
  final sk = _surfaceKey(surface);
  if (sk.isEmpty) return '';
  final c = ctx.surfaceToCanonical[sk] ??
      ctx.surfaceToCanonical[_stripParenthetical(sk)];
  if (c != null && c.trim().isNotEmpty) {
    return 'e:${c.trim()}';
  }
  final soft = softClusterKey(sk);
  if (soft.isEmpty) return 'n:${_normalizeKey(sk)}';
  return 's:$soft';
}

String _canonicalAmountKey(String raw) {
  var a = raw.trim();
  if (a.isEmpty) return a;
  final normalized = a.replaceAll('（', '(').replaceAll('）', ')');
  if (normalized == '1缶' || normalized == '1缶(70g)') return '1缶';
  if (normalized == '1個' || normalized == '1コ') return '1個';
  return a;
}

String _pickRelativeDisplay(
  Set<String> variants,
  Map<String, int> seenCount,
) {
  if (variants.isEmpty) return '';
  String best = variants.first;
  int bestScore = seenCount[best] ?? 0;
  for (final v in variants) {
    final sc = seenCount[v] ?? 0;
    if (sc > bestScore || (sc == bestScore && v.length > best.length)) {
      bestScore = sc;
      best = v;
    }
  }
  return best;
}

void _ingestIngredient(
  Map<String, _AggBucket> map,
  SuggestedIngredient ing,
  IngredientMergeContext ctx,
) {
  final display = ing.name.trim();
  final key = _resolveBucketKey(display, ctx);
  if (key.isEmpty) return;

  final isExplicit = key.startsWith('e:');
  map.putIfAbsent(key, () {
    if (isExplicit) {
      final canon = key.substring(2);
      return _AggBucket(canon, isExplicit: true);
    }
    return _AggBucket(display, isExplicit: false);
  });
  final bucket = map[key]!;
  bucket.variantLabels.add(display);

  if (!isExplicit && display.length > bucket.displayName.length) {
    bucket.displayName = display;
  }

  final amt = ing.amount.trim();
  final amtKey = amt.isEmpty ? '' : _canonicalAmountKey(amt);
  bucket.amountCounts[amtKey] = (bucket.amountCounts[amtKey] ?? 0) + 1;
}

void _ingestDish(
  Map<String, _AggBucket> map,
  SuggestedDish dish,
  IngredientMergeContext ctx,
) {
  for (final ing in dish.ingredients) {
    _ingestIngredient(map, ing, ctx);
  }
}

List<AggregatedShoppingItem> _finalize(
  Map<String, _AggBucket> map,
  IngredientMergeContext ctx,
) {
  final out = <AggregatedShoppingItem>[];
  for (final b in map.values) {
    if (!b.isExplicit && b.variantLabels.isNotEmpty) {
      b.displayName = _pickRelativeDisplay(b.variantLabels, ctx.surfaceSeenCount);
    }
    final counts = <String, int>{};
    for (final e in b.amountCounts.entries) {
      final label = e.key.isEmpty ? '（分量の記載なし）' : e.key;
      counts[label] = e.value;
    }
    out.add(AggregatedShoppingItem(name: b.displayName, amountCounts: counts));
  }
  out.sort();
  return out;
}

/// メニュー内の食材名（重複あり）を列挙（統計更新用）
List<String> collectRawIngredientSurfaces(WeeklyMealSuggestion? weekly) {
  if (weekly == null) return [];
  final out = <String>[];
  for (final day in weekly.days) {
    for (final meal in day.meals) {
      for (final dish in meal.dishes) {
        for (final ing in dish.ingredients) {
          final s = ing.name.trim();
          if (s.isNotEmpty) out.add(s);
        }
      }
    }
  }
  return out;
}

List<String> collectRawIngredientSurfacesFromDaily(DailyMealSuggestion? daily) {
  if (daily == null) return [];
  final out = <String>[];
  for (final meal in daily.meals) {
    for (final dish in meal.dishes) {
      for (final ing in dish.ingredients) {
        final s = ing.name.trim();
        if (s.isNotEmpty) out.add(s);
      }
    }
  }
  return out;
}

/// 1週間プラン全体の食材を集計する。
List<AggregatedShoppingItem> shoppingListFromWeekly(
  WeeklyMealSuggestion w,
  IngredientMergeContext ctx,
) {
  final map = <String, _AggBucket>{};
  for (final day in w.days) {
    for (final meal in day.meals) {
      for (final dish in meal.dishes) {
        _ingestDish(map, dish, ctx);
      }
    }
  }
  return _finalize(map, ctx);
}

/// 1日分の提案の食材を集計
List<AggregatedShoppingItem> shoppingListFromDaily(
  DailyMealSuggestion d,
  IngredientMergeContext ctx,
) {
  final map = <String, _AggBucket>{};
  for (final meal in d.meals) {
    for (final dish in meal.dishes) {
      _ingestDish(map, dish, ctx);
    }
  }
  return _finalize(map, ctx);
}

/// 共有・コピー用プレーンテキスト
String buildPlainTextShoppingList({
  required String heading,
  required List<AggregatedShoppingItem> items,
}) {
  final buf = StringBuffer()
    ..writeln(heading)
    ..writeln()
    ..writeln('※ AI 提案から自動集計しました。分量は目安です。店頭の状況に合わせて調整してください。')
    ..writeln();

  if (items.isEmpty) {
    buf.writeln('（食材の記載がありません）');
  } else {
    for (final item in items) {
      buf.writeln('・${item.name} … ${item.amountsLine}');
    }
  }
  return buf.toString().trimRight();
}
