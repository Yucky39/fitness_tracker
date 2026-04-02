import 'dart:convert';
import 'package:http/http.dart' as http;
import '../providers/settings_provider.dart';

class AnalyzedFoodItem {
  final String name;
  final String amount;
  final int calories;
  final double protein;
  final double fat;
  final double carbs;
  final double sugar;
  final double fiber;
  final double sodium;
  bool selected;

  AnalyzedFoodItem({
    required this.name,
    required this.amount,
    required this.calories,
    required this.protein,
    required this.fat,
    required this.carbs,
    required this.sugar,
    required this.fiber,
    required this.sodium,
    this.selected = true,
  });

  AnalyzedFoodItem copyWith({
    String? name,
    String? amount,
    int? calories,
    double? protein,
    double? fat,
    double? carbs,
    double? sugar,
    double? fiber,
    double? sodium,
  }) =>
      AnalyzedFoodItem(
        name: name ?? this.name,
        amount: amount ?? this.amount,
        calories: calories ?? this.calories,
        protein: protein ?? this.protein,
        fat: fat ?? this.fat,
        carbs: carbs ?? this.carbs,
        sugar: sugar ?? this.sugar,
        fiber: fiber ?? this.fiber,
        sodium: sodium ?? this.sodium,
        selected: selected,
      );

  factory AnalyzedFoodItem.fromJson(Map<String, dynamic> json) {
    return AnalyzedFoodItem(
      name: json['name'] as String? ?? '不明な食品',
      amount: json['amount'] as String? ?? '',
      calories: (json['calories'] as num?)?.toInt() ?? 0,
      protein: (json['protein'] as num?)?.toDouble() ?? 0.0,
      fat: (json['fat'] as num?)?.toDouble() ?? 0.0,
      carbs: (json['carbs'] as num?)?.toDouble() ?? 0.0,
      sugar: (json['sugar'] as num?)?.toDouble() ?? 0.0,
      fiber: (json['fiber'] as num?)?.toDouble() ?? 0.0,
      sodium: (json['sodium'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class MealImageAnalysisService {
  static const _maxTokens = 2048;

  static const _prompt = '''
この食事の写真に写っている食品を全て分析してください。
栄養素の値は厚生労働省「日本食品標準成分表」やクックパッド等レシピサイトの平均値を参考にしてください。

返却形式（必ずJSONのみ。前後の説明文は一切不要です）:
[
  {
    "name": "食品名（日本語）",
    "amount": "推定量（例：150g、1杯、1個）",
    "calories": カロリー（kcal、整数）,
    "protein": タンパク質（g、小数点1位）,
    "fat": 脂質（g、小数点1位）,
    "carbs": 炭水化物（g、小数点1位）,
    "sugar": 糖質（g、小数点1位）,
    "fiber": 食物繊維（g、小数点1位）,
    "sodium": ナトリウム（mg、整数）
  }
]

注意：
- 複数の食品が写っている場合は全て個別に列挙してください
- 量が不明な場合は一般的な1人前として計算してください
- JSONのみを返し、前後の説明文は一切付けないでください
''';

  Future<List<AnalyzedFoodItem>> analyzeImage({
    required List<int> imageBytes,
    required String filePath,
    required String apiKey,
    required AiProviderType provider,
    String? model,
  }) async {
    if (apiKey.isEmpty) {
      throw Exception('APIキーが設定されていません。設定画面からAPIキーを入力してください。');
    }

    final base64Image = base64Encode(imageBytes);
    final mediaType = _detectMediaType(filePath);
    final resolvedModel = model ?? provider.defaultModel;

    final String rawText;
    switch (provider) {
      case AiProviderType.anthropic:
        rawText = await _callAnthropic(base64Image, mediaType, apiKey, resolvedModel);
      case AiProviderType.openai:
        rawText = await _callOpenAi(base64Image, mediaType, apiKey, resolvedModel);
      case AiProviderType.gemini:
        rawText = await _callGemini(base64Image, mediaType, apiKey, resolvedModel);
    }

    return _parseJson(rawText);
  }

  String _detectMediaType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }

  List<AnalyzedFoodItem> _parseJson(String text) {
    final match = RegExp(r'\[[\s\S]*\]').firstMatch(text);
    if (match == null) {
      throw Exception('食品の分析結果を解析できませんでした。もう一度お試しください。');
    }
    try {
      final list = jsonDecode(match.group(0)!) as List<dynamic>;
      return list
          .map((e) => AnalyzedFoodItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      throw Exception('分析結果の解析に失敗しました。もう一度お試しください。');
    }
  }

  // ── Anthropic (Claude) ─────────────────────────────────────────────────────

  Future<String> _callAnthropic(
      String base64Image, String mediaType, String apiKey, String model) async {
    final res = await http.post(
      Uri.parse('https://api.anthropic.com/v1/messages'),
      headers: {
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
        'content-type': 'application/json',
      },
      body: jsonEncode({
        'model': model,
        'max_tokens': _maxTokens,
        'messages': [
          {
            'role': 'user',
            'content': [
              {
                'type': 'image',
                'source': {
                  'type': 'base64',
                  'media_type': mediaType,
                  'data': base64Image,
                },
              },
              {'type': 'text', 'text': _prompt},
            ],
          },
        ],
      }),
    );

    if (res.statusCode != 200) {
      final body = jsonDecode(utf8.decode(res.bodyBytes));
      throw Exception(body['error']?['message'] ?? 'Anthropic APIエラー (${res.statusCode})');
    }
    return (jsonDecode(utf8.decode(res.bodyBytes)))['content'][0]['text'] as String;
  }

  // ── OpenAI (GPT-4o-mini) ───────────────────────────────────────────────────

  Future<String> _callOpenAi(
      String base64Image, String mediaType, String apiKey, String model) async {
    final res = await http.post(
      Uri.parse('https://api.openai.com/v1/chat/completions'),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'content-type': 'application/json',
      },
      body: jsonEncode({
        'model': model,
        'max_tokens': _maxTokens,
        'messages': [
          {
            'role': 'user',
            'content': [
              {
                'type': 'image_url',
                'image_url': {'url': 'data:$mediaType;base64,$base64Image'},
              },
              {'type': 'text', 'text': _prompt},
            ],
          },
        ],
      }),
    );

    if (res.statusCode != 200) {
      final body = jsonDecode(utf8.decode(res.bodyBytes));
      throw Exception(body['error']?['message'] ?? 'OpenAI APIエラー (${res.statusCode})');
    }
    return (jsonDecode(utf8.decode(res.bodyBytes)))['choices'][0]['message']['content'] as String;
  }

  // ── Google Gemini ──────────────────────────────────────────────────────────

  Future<String> _callGemini(
      String base64Image, String mediaType, String apiKey, String model) async {
    final res = await http.post(
      Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey',
      ),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {'inline_data': {'mime_type': mediaType, 'data': base64Image}},
              {'text': _prompt},
            ],
          },
        ],
        'generationConfig': {'maxOutputTokens': _maxTokens},
      }),
    );

    if (res.statusCode != 200) {
      final body = jsonDecode(utf8.decode(res.bodyBytes));
      throw Exception(body['error']?['message'] ?? 'Gemini APIエラー (${res.statusCode})');
    }
    return (jsonDecode(utf8.decode(res.bodyBytes)))['candidates'][0]['content']['parts'][0]['text']
        as String;
  }
}
