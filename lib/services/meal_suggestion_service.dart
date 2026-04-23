import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/food_item.dart';
import '../models/meal_suggestion.dart';
import '../providers/settings_provider.dart';

/// 1日の食事メニューをAIで提案するサービス。
///
/// 文部科学省「日本食品標準成分表」の栄養素値を参照するよう
/// プロンプトで明示し、PFC目標に合ったメニューとレシピを生成する。
/// ユーザーが当日記録したサプリメント・プロテインを差し引いた
/// 残余目標を食事で補うよう指示する。
class MealSuggestionService {
  /// 1日4食分のレシピ・食材・手順を含むJSONは 4k トークンを超えやすいので、
  /// 途中で打ち切られないよう大きめに取る。
  static const _maxOutputTokens = 16384;

  String _buildPrompt({
    required int calorieGoal,
    required double proteinGoal,
    required double fatGoal,
    required double carbsGoal,
    required List<FoodItem> supplements,
  }) {
    final suppCalories = supplements.fold(0, (s, i) => s + i.calories);
    final suppProtein =
        supplements.fold(0.0, (s, i) => s + i.protein);
    final suppFat = supplements.fold(0.0, (s, i) => s + i.fat);
    final suppCarbs = supplements.fold(0.0, (s, i) => s + i.carbs);

    final remainCalories = (calorieGoal - suppCalories).clamp(0, calorieGoal);
    final remainProtein = (proteinGoal - suppProtein).clamp(0.0, proteinGoal);
    final remainFat = (fatGoal - suppFat).clamp(0.0, fatGoal);
    final remainCarbs = (carbsGoal - suppCarbs).clamp(0.0, carbsGoal);

    final suppText = supplements.isEmpty
        ? 'なし'
        : supplements
            .map((s) =>
                '・${s.name}（タンパク質${s.protein.toStringAsFixed(1)}g、脂質${s.fat.toStringAsFixed(1)}g、炭水化物${s.carbs.toStringAsFixed(1)}g、${s.calories}kcal）')
            .join('\n');

    return '''
あなたは日本の管理栄養士です。
ユーザーの1日の栄養目標に基づき、1日分の食事メニューを提案してください。

## ユーザーの1日の栄養目標
- カロリー: ${calorieGoal}kcal
- タンパク質 (P): ${proteinGoal.toStringAsFixed(1)}g
- 脂質 (F): ${fatGoal.toStringAsFixed(1)}g
- 炭水化物 (C): ${carbsGoal.toStringAsFixed(1)}g

## 当日摂取済みのサプリメント・プロテイン
$suppText

## 食事で補うべき残余目標
- カロリー: ${remainCalories}kcal
- タンパク質 (P): ${remainProtein.toStringAsFixed(1)}g
- 脂質 (F): ${remainFat.toStringAsFixed(1)}g
- 炭水化物 (C): ${remainCarbs.toStringAsFixed(1)}g

## 指示
- 上記の残余目標に合わせて、朝食・昼食・夕食・間食（必要な場合のみ）を提案してください
- 各料理の栄養素は文部科学省「日本食品標準成分表2020年版（八訂）」の値を参照してください
- 各料理の食材と分量、調理手順を具体的に示してください
- サプリメント摂取がある場合はそれを考慮した旨をsupplement_noteに記載してください
- 間食が不要な場合はsnackを省略してください
- 日本人が日常的に作れる親しみやすいメニューにしてください
- レシピ・食材名・手順はすべて日本語で記述してください

## 返却形式（JSONのみ。前後の説明文は一切不要です）
{
  "meals": [
    {
      "meal_type": "breakfast",
      "dishes": [
        {
          "name": "料理名",
          "note": "補足説明（任意）",
          "calories": カロリー整数,
          "protein": タンパク質g小数点1位,
          "fat": 脂質g小数点1位,
          "carbs": 炭水化物g小数点1位,
          "ingredients": [
            {"name": "食材名", "amount": "分量（例: 150g）", "calories": 整数, "protein": 小数点1位, "fat": 小数点1位, "carbs": 小数点1位}
          ],
          "steps": [
            "手順1",
            "手順2"
          ]
        }
      ]
    },
    {"meal_type": "lunch", "dishes": [...]},
    {"meal_type": "dinner", "dishes": [...]},
    {"meal_type": "snack", "dishes": [...]}
  ],
  "supplement_note": "サプリメントの考慮内容（サプリなしの場合は空文字）"
}

重要: 返答は有効なJSONオブジェクト1つだけにしてください。前後の説明文、```json や ``` のマークダウン囲みは一切付けないでください。
''';
  }

  /// 食事提案を生成して返す
  Future<DailyMealSuggestion> suggest({
    required int calorieGoal,
    required double proteinGoal,
    required double fatGoal,
    required double carbsGoal,
    required List<FoodItem> todayItems,
    required String apiKey,
    required AiProviderType provider,
    String? model,
  }) async {
    if (apiKey.isEmpty) {
      throw Exception('APIキーが設定されていません。設定画面からAPIキーを入力してください。');
    }

    final supplements =
        todayItems.where((i) => i.mealType == MealType.supplement).toList();

    final prompt = _buildPrompt(
      calorieGoal: calorieGoal,
      proteinGoal: proteinGoal,
      fatGoal: fatGoal,
      carbsGoal: carbsGoal,
      supplements: supplements,
    );

    final resolvedModel = model ?? provider.defaultModel;

    final String rawText;
    switch (provider) {
      case AiProviderType.anthropic:
        rawText = await _callAnthropic(prompt, apiKey, resolvedModel);
      case AiProviderType.openai:
        rawText = await _callOpenAi(prompt, apiKey, resolvedModel);
      case AiProviderType.gemini:
        rawText = await _callGemini(prompt, apiKey, resolvedModel);
    }

    return _parseResponse(rawText);
  }

  // ── JSON 解析 ────────────────────────────────────────────────────────────
  //
  // AI のレスポンスは下記のいずれかが起きうるので、順に対処する。
  //   1) ```json ... ``` のマークダウン囲み
  //   2) 前置き文 + JSON + 後書き
  //   3) 応答が途中で切れて末尾の `}` が欠落（max_tokens 超過）
  //   4) 空文字列（thinking モデルがトークンを思考で使い切った場合）

  DailyMealSuggestion _parseResponse(String text) {
    final cleaned = _stripCodeFence(text).trim();

    if (cleaned.isEmpty) {
      throw Exception(
        'AIのレスポンスが空でした。使用中のモデルでは出力トークンが不足している可能性があります。'
        '別のモデルに切り替えるか、もう一度お試しください。',
      );
    }

    final jsonText = _extractJsonObject(cleaned);
    if (jsonText == null) {
      final preview =
          cleaned.length > 300 ? '${cleaned.substring(0, 300)}…' : cleaned;
      throw Exception(
        'AIのレスポンスからJSONを抽出できませんでした。もう一度お試しください。\n'
        '（受信内容冒頭: $preview）',
      );
    }

    try {
      final json = jsonDecode(jsonText) as Map<String, dynamic>;
      json['generated_at'] = DateTime.now().toIso8601String();
      return DailyMealSuggestion.fromJson(json);
    } catch (e) {
      final preview =
          jsonText.length > 300 ? '${jsonText.substring(0, 300)}…' : jsonText;
      throw Exception(
        '食事提案のJSON解析に失敗しました。AIの応答が途中で切れた可能性があります。もう一度お試しください。\n'
        '（エラー: $e / JSON冒頭: $preview）',
      );
    }
  }

  /// ```json ... ``` のフェンスが付いている場合に中身だけを取り出す。
  String _stripCodeFence(String text) {
    final fence = RegExp(
      r'```(?:json|JSON)?\s*([\s\S]*?)```',
      multiLine: true,
    );
    final m = fence.firstMatch(text);
    if (m != null && m.group(1) != null) return m.group(1)!;
    return text;
  }

  /// 最初の `{` を起点にブレース数をカウントして対応する `}` までを切り出す。
  /// 文字列リテラル内の `{` `}` は無視する。
  /// 末尾の `}` が欠落している場合は不足分を補ってから返す（部分的に救済）。
  String? _extractJsonObject(String text) {
    final start = text.indexOf('{');
    if (start < 0) return null;

    var depth = 0;
    var inString = false;
    var escape = false;
    int? end;
    for (var i = start; i < text.length; i++) {
      final c = text[i];
      if (escape) {
        escape = false;
        continue;
      }
      if (c == r'\') {
        escape = true;
        continue;
      }
      if (c == '"') {
        inString = !inString;
        continue;
      }
      if (inString) continue;
      if (c == '{') depth++;
      if (c == '}') {
        depth--;
        if (depth == 0) {
          end = i;
          break;
        }
      }
    }

    if (end != null) {
      return text.substring(start, end + 1);
    }
    if (depth > 0) {
      final missing = List.filled(depth, '}').join();
      return '${text.substring(start)}$missing';
    }
    return null;
  }

  // ── Anthropic (Claude) ────────────────────────────────────────────────────

  Future<String> _callAnthropic(
      String prompt, String apiKey, String model) async {
    final res = await http.post(
      Uri.parse('https://api.anthropic.com/v1/messages'),
      headers: {
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
        'content-type': 'application/json',
      },
      body: jsonEncode({
        'model': model,
        'max_tokens': _maxOutputTokens,
        'messages': [
          {'role': 'user', 'content': prompt},
        ],
      }),
    );

    if (res.statusCode != 200) {
      throw Exception(_readApiError(res, defaultPrefix: 'Anthropic'));
    }

    final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;

    final contents = body['content'];
    if (contents is! List || contents.isEmpty) {
      throw Exception('Anthropic API: 応答に content が含まれていません。');
    }

    // thinking ブロックが先頭に来るケースがあるので、type == 'text' の block を連結する
    final buf = StringBuffer();
    for (final c in contents) {
      if (c is Map<String, dynamic> && c['type'] == 'text') {
        final t = c['text'];
        if (t is String) buf.write(t);
      }
    }
    if (buf.isEmpty) {
      throw Exception(
        'Anthropic API: テキスト応答が含まれていませんでした。'
        '(stop_reason: ${body['stop_reason']})',
      );
    }
    return buf.toString();
  }

  // ── OpenAI ────────────────────────────────────────────────────────────────

  /// GPT-5 / GPT-4.1 / o 系などは `max_tokens` が廃止されており、
  /// `max_completion_tokens` を使う必要がある。モデル名で判定する。
  bool _openAiRequiresMaxCompletionTokens(String model) {
    final m = model.toLowerCase();
    return m.startsWith('gpt-5') ||
        m.startsWith('gpt-4.1') ||
        m.startsWith('o1') ||
        m.startsWith('o3') ||
        m.startsWith('o4');
  }

  Future<String> _callOpenAi(
      String prompt, String apiKey, String model) async {
    final usesMaxCompletion = _openAiRequiresMaxCompletionTokens(model);

    final payload = <String, dynamic>{
      'model': model,
      'messages': [
        {'role': 'user', 'content': prompt},
      ],
      // できる限り JSON オブジェクトだけを返させる
      'response_format': {'type': 'json_object'},
    };
    if (usesMaxCompletion) {
      payload['max_completion_tokens'] = _maxOutputTokens;
    } else {
      payload['max_tokens'] = _maxOutputTokens;
    }

    final res = await http.post(
      Uri.parse('https://api.openai.com/v1/chat/completions'),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'content-type': 'application/json',
      },
      body: jsonEncode(payload),
    );

    if (res.statusCode != 200) {
      throw Exception(_readApiError(res, defaultPrefix: 'OpenAI'));
    }

    final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final choices = body['choices'];
    if (choices is! List || choices.isEmpty) {
      throw Exception('OpenAI API: 応答に choices が含まれていません。');
    }
    final message = (choices.first as Map<String, dynamic>)['message']
        as Map<String, dynamic>?;
    final content = message?['content'];
    if (content is! String || content.isEmpty) {
      // 推論系モデルは `finish_reason == 'length'` で推論に全トークンを使い切り、
      // 本文が空になることがある
      final finish = (choices.first as Map<String, dynamic>)['finish_reason'];
      throw Exception(
        'OpenAI API: 本文が空でした（finish_reason: $finish）。'
        'モデルを「GPT-4o」や「GPT-4o mini」などに変更して再試行してください。',
      );
    }
    return content;
  }

  // ── Google Gemini ─────────────────────────────────────────────────────────

  Future<String> _callGemini(
      String prompt, String apiKey, String model) async {
    final res = await http.post(
      Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey',
      ),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt},
            ],
          },
        ],
        'generationConfig': {
          'maxOutputTokens': _maxOutputTokens,
          'responseMimeType': 'application/json',
        },
      }),
    );

    if (res.statusCode != 200) {
      throw Exception(_readApiError(res, defaultPrefix: 'Gemini'));
    }

    final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final candidates = body['candidates'];
    if (candidates is! List || candidates.isEmpty) {
      throw Exception(
        'Gemini API: 応答に candidates が含まれていません。'
        'プロンプトがブロックされた可能性があります。',
      );
    }

    final first = candidates.first as Map<String, dynamic>;
    final content = first['content'] as Map<String, dynamic>?;
    final parts = content?['parts'];

    final buf = StringBuffer();
    if (parts is List) {
      for (final p in parts) {
        if (p is Map<String, dynamic>) {
          // 思考パート（`thought: true`）はスキップしてテキストだけを集める
          if (p['thought'] == true) continue;
          final t = p['text'];
          if (t is String) buf.write(t);
        }
      }
    }

    if (buf.isEmpty) {
      final finish = first['finishReason'];
      throw Exception(
        'Gemini API: テキスト応答が空でした（finishReason: $finish）。'
        'モデルが推論にトークンを使い切った可能性があります。'
        '「Gemini 2.0 Flash」など推論トークンを消費しないモデルに切り替えて再試行してください。',
      );
    }
    return buf.toString();
  }

  // ── 共通ヘルパ ────────────────────────────────────────────────────────────

  String _readApiError(http.Response res, {required String defaultPrefix}) {
    try {
      final body = jsonDecode(utf8.decode(res.bodyBytes));
      final msg = (body is Map ? body['error'] : null) is Map
          ? (body['error'] as Map)['message']
          : body is Map
              ? body['error']
              : null;
      if (msg is String && msg.isNotEmpty) return msg;
    } catch (_) {}
    return '$defaultPrefix APIエラー (${res.statusCode})';
  }
}
