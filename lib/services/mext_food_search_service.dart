import 'dart:math' show min;

import 'package:http/http.dart' as http;

import '../models/food_search_result.dart';

/// 文部科学省「食品成分データベース」（日本食品標準成分表 八訂）の検索・詳細HTMLを取得する。
/// https://fooddb.mext.go.jp/ （試験公開中。利用規約・免責に従うこと）
class MextFoodSearchService {
  static const _base = 'https://fooddb.mext.go.jp';
  static const _headers = {
    'User-Agent': 'FitnessTracker/1.0 (Flutter; educational; contact via app)',
    'Accept': 'text/html,application/xhtml+xml',
    'Accept-Language': 'ja-JP,ja;q=0.9',
  };

  /// フリーワード検索 → 候補の ITEM_NO を取得し、各詳細ページから可食部100g当たりの成分を取り込む。
  Future<List<FoodSearchResult>> search(String query) async {
    final q = query.trim();
    if (q.isEmpty) return [];

    final listUri = Uri.parse('$_base/freeword/fword_select.pl');
    try {
      final response = await http
          .post(
            listUri,
            headers: {
              ..._headers,
              'Referer': '$_base/freeword/searchbox.pl',
              'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
            },
            body: {
              'SEARCH_WORD': q,
              'USER_ID': '',
              'function1': '検索',
            },
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) return [];
      final html = response.body;
      if (html.contains('システムエラー') || html.contains('異常終了')) return [];

      final candidates = _parseSearchList(html);
      if (candidates.isEmpty) return [];

      final take = candidates.take(12).toList();
      final results = <FoodSearchResult>[];
      const batch = 4;
      for (var i = 0; i < take.length; i += batch) {
        final chunk = take.sublist(i, min(i + batch, take.length));
        final batchResults = await Future.wait(
          chunk.map((c) => _fetchOneFood(c)),
        );
        for (final r in batchResults) {
          if (r != null) results.add(r);
        }
      }
      return results;
    } catch (_) {
      return [];
    }
  }

  /// `name` と `itemNo`（例: 7_11_11214）
  List<({String itemNo, String name})> _parseSearchList(String html) {
    final re = RegExp(
      r'name="ITEM_NO"[^>]*value="([^"]+)"[^>]*>([^<]+)</label>',
      multiLine: true,
    );
    final out = <({String itemNo, String name})>[];
    for (final m in re.allMatches(html)) {
      final itemNo = m.group(1);
      final name = m.group(2)?.trim();
      if (itemNo == null || name == null || name.isEmpty) continue;
      out.add((itemNo: itemNo, name: name));
    }
    return out;
  }

  Future<FoodSearchResult?> _fetchOneFood(({String itemNo, String name}) c) async {
    final uri = Uri.parse(
      '$_base/details/details.pl?ITEM_NO=${Uri.encodeComponent(c.itemNo)}',
    );
    try {
      final response = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) return null;
      final n = _parseDetailsNutrients(response.body);
      if (n == null) return null;
      final displayName = _parseDisplayName(response.body) ?? c.name;
      final (kcal, p, f, carb) = n;
      return FoodSearchResult(
        name: displayName,
        caloriesPer100g: kcal.round(),
        proteinPer100g: p,
        fatPer100g: f,
        carbsPer100g: carb,
        dataSourceLabel: '日本食品標準成分表（八訂）・文部科学省 食品成分データベース',
      );
    } catch (_) {
      return null;
    }
  }

  String? _parseDisplayName(String html) {
    final m = RegExp(
      r'class="foodfullname">([^<]+)</span>',
    ).firstMatch(html);
    return m?.group(1)?.trim();
  }

  /// 可食部100g当たり (kcal, P, F, C)
  (double, double, double, double)? _parseDetailsNutrients(String html) {
    final kcalI = _firstInt(html, RegExp(
      r'<!--\s*エネルギー\(kcal\)\s*-->\s*<td class="num">(\d+)</td>',
      multiLine: true,
    ));
    if (kcalI == null) return null;

    final protein = _firstDouble(html, RegExp(
      r'<a[^>]*>たんぱく質</a></td>\s*<td class="num">([\d.()]+)</td>',
      multiLine: true,
    ));
    final fat = _firstDouble(html, RegExp(
      r'<a[^>]*>脂質</a></td>\s*<td class="num">([\d.()]+)</td>',
      multiLine: true,
    ));

    var carbs = _firstDouble(html, RegExp(
      r'差引き法による利用可能炭水化物</a></td>\s*<td class="num">([\d.()]+)</td>',
      multiLine: true,
    ));
    carbs ??= _firstDouble(html, RegExp(
      r'<a[^>]*>炭水化物</a></td>\s*<td class="num">([\d.()]+)</td>',
      multiLine: true,
    ));

    if (protein == null || fat == null || carbs == null) return null;

    return (kcalI.toDouble(), protein, fat, carbs);
  }

  int? _firstInt(String html, RegExp re) {
    final m = re.firstMatch(html);
    return m != null ? int.tryParse(m.group(1) ?? '') : null;
  }

  double? _firstDouble(String html, RegExp re) {
    final m = re.firstMatch(html);
    if (m == null) return null;
    return _parseParenNum(m.group(1) ?? '');
  }

  double? _parseParenNum(String raw) {
    final t = raw.replaceAll(RegExp(r'[()]'), '').trim();
    return double.tryParse(t);
  }
}
