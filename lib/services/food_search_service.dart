import 'dart:convert';
import 'package:http/http.dart' as http;

import '../data/japanese_food_fallback_nutrition.dart';
import '../data/japanese_food_search_hints.dart';
import '../models/food_search_result.dart';

export '../models/food_search_result.dart';

class FoodSearchService {
  /// Open Food Facts の利用条件: 識別できる User-Agent
  static const _headers = {
    'User-Agent': 'FitnessTracker/1.0 (Flutter; contact: https://openfoodfacts.org)',
    'Accept': 'application/json',
  };

  static bool containsJapanese(String s) {
    for (final r in s.runes) {
      if ((r >= 0x3040 && r <= 0x309F) ||
          (r >= 0x30A0 && r <= 0x30FF) ||
          (r >= 0x4E00 && r <= 0x9FFF)) {
        return true;
      }
    }
    return false;
  }

  /// search.pl は `json=1` や `fields=` の組み合わせで 503 になることがあるため、
  /// `json=true` + `action=process` + `search_simple=1` のみ使用する（fields は付けない）。
  /// 日本語クエリはサーバ側が不安定なため、辞書で英語に寄せた語を先に検索する。
  Future<List<FoodSearchResult>> search(String query) async {
    final q = query.trim();
    if (q.isEmpty) return [];

    final searchTerms = _buildSearchTerms(q);
    final futures = searchTerms
        .map((t) => _fetchOne(_searchUri('world.openfoodfacts.org', t)))
        .toList();

    final lists = await Future.wait(
      futures,
      eagerError: false,
    );

    var merged = _mergeAndDedupe(lists.expand((e) => e));
    merged.sort((a, b) => _score(b, q).compareTo(_score(a, q)));

    if (merged.isEmpty) {
      merged = List<FoodSearchResult>.from(JapaneseFoodFallbackNutrition.match(q));
    }

    if (merged.length > 24) {
      return merged.sublist(0, 24);
    }
    return merged;
  }

  /// 辞書で英語に寄せられる日本語は、その語だけ検索（search.pl が日本語で 503 になりやすいため）
  List<String> _buildSearchTerms(String q) {
    final hint = JapaneseFoodSearchHints.lookup(q);
    if (hint == null) {
      return [q];
    }
    if (!containsJapanese(q)) {
      return hint == q ? [q] : {hint, q}.toList();
    }
    return [hint];
  }

  Uri _searchUri(String host, String terms) {
    return Uri.parse(
      'https://$host/cgi/search.pl'
      '?search_terms=${Uri.encodeComponent(terms)}'
      '&search_simple=1'
      '&action=process'
      '&json=true'
      '&page_size=14',
    );
  }

  int _score(FoodSearchResult r, String query) {
    final ql = query.toLowerCase().trim();
    final nl = r.name.toLowerCase();
    var s = 0;
    if (ql.isNotEmpty && nl.contains(ql)) s += 20;
    if (containsJapanese(query) && containsJapanese(r.name)) s += 8;
    if (r.caloriesPer100g > 0) s += 2;
    if (!r.name.contains('※目安')) s += 1;
    return s;
  }

  Future<List<FoodSearchResult>> _fetchOne(Uri uri) async {
    try {
      final response = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return [];
      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic>) return [];
      final products = data['products'] as List<dynamic>? ?? [];
      final out = <FoodSearchResult>[];
      for (final product in products) {
        final map = product as Map<String, dynamic>;
        final parsed = _parseProduct(map);
        if (parsed != null) out.add(parsed);
      }
      return out;
    } catch (_) {
      return [];
    }
  }

  FoodSearchResult? _parseProduct(Map<String, dynamic> product) {
    final name = _pickProductName(product);
    if (name.trim().isEmpty) return null;

    final n = product['nutriments'] as Map<String, dynamic>? ?? {};
    final cal = _kcalFromNutriments(n);
    final protein = _num(n['proteins_100g'] ?? n['proteins'] ?? n['proteins_value']);
    final fat = _num(n['fat_100g'] ?? n['fat'] ?? n['fat_value']);
    final carbs = _num(n['carbohydrates_100g'] ?? n['carbohydrates'] ?? n['carbohydrates_value']);

    if (cal <= 0 && protein <= 0 && fat <= 0 && carbs <= 0) {
      return null;
    }

    return FoodSearchResult(
      name: name.trim(),
      caloriesPer100g: cal.round(),
      proteinPer100g: protein,
      fatPer100g: fat,
      carbsPer100g: carbs,
    );
  }

  double _kcalFromNutriments(Map<String, dynamic> n) {
    var kcal = _num(n['energy-kcal_100g']);
    if (kcal > 0) return kcal;
    kcal = _num(n['energy-kcal']);
    if (kcal > 0) return kcal;
    kcal = _num(n['energy_100g']);
    if (kcal > 0) return kcal;
    final kj = _num(n['energy-kj_100g'] ?? n['energy-kj']);
    if (kj > 0) return kj / 4.184;
    return 0;
  }

  double _num(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  String _pickProductName(Map<String, dynamic> product) {
    final ja = product['product_name_ja'] as String?;
    if (ja != null && ja.trim().isNotEmpty) return ja;

    final genericJa = product['generic_name_ja'] as String?;
    if (genericJa != null && genericJa.trim().isNotEmpty) return genericJa;

    final name = product['product_name'] as String?;
    if (name != null && name.trim().isNotEmpty) return name;

    final generic = product['generic_name'] as String?;
    if (generic != null && generic.trim().isNotEmpty) return generic;

    return '';
  }

  List<FoodSearchResult> _mergeAndDedupe(Iterable<FoodSearchResult> all) {
    final seen = <String>{};
    final out = <FoodSearchResult>[];
    for (final r in all) {
      final key = _normKey(r.name);
      if (key.isEmpty) continue;
      if (seen.contains(key)) continue;
      seen.add(key);
      out.add(r);
    }
    return out;
  }

  String _normKey(String name) {
    return name.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}
