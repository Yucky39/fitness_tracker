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
  static const _maxTokens = 4096;

  String _buildPrompt({
    required int calorieGoal,
    required double proteinGoal,
    required double fatGoal,
    required double carbsGoal,
    required List<FoodItem> supplements,
  }) {
    // サプリ・プロテインの合計を算出
    final suppCalories = supplements.fold(0, (s, i) => s + i.calories);
    final suppProtein =
        supplements.fold(0.0, (s, i) => s + i.protein);
    final suppFat = supplements.fold(0.0, (s, i) => s + i.fat);
    final suppCarbs = supplements.fold(0.0, (s, i) => s + i.carbs);

    // 食事で補うべき残余目標
    final remainCalories = (calorieGoal - suppCalories).clamp(0, calorieGoal);
    final remainProtein = (proteinGoal - suppProtein).clamp(0.0, proteinGoal);
    final remainFat = (fatGoal - suppFat).clamp(0.0, fatGoal);
    final remainCarbs = (carbsGoal - suppCarbs).clamp(0.0, carbsGoal);

    // サプリ情報テキスト
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

JSONのみを返してください。前後の説明文や```json```マークダウンは不要です。
''';
  }

  /// 食事提案を生成して返す
  Future<DailyMealSuggestion> suggest({
    required int calorieGoal,
    required double proteinGoal,
    required double fatGoal,
    required double carbsGoal,
    required List<FoodItem> todayItems, // 当日全記録（サプリ抽出用）
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
        rawText =
            await _callAnthropic(prompt, apiKey, resolvedModel);
      case AiProviderType.openai:
        rawText = await _callOpenAi(prompt, apiKey, resolvedModel);
      case AiProviderType.gemini:
        rawText = await _callGemini(prompt, apiKey, resolvedModel);
    }

    return _parseResponse(rawText);
  }

  DailyMealSuggestion _parseResponse(String text) {
    // JSONオブジェクトを抽出
    final match = RegExp(r'\{[\s\S]*\}').firstMatch(text);
    if (match == null) {
      throw Exception('食事提案の解析に失敗しました。もう一度お試しください。');
    }
    try {
      final json = jsonDecode(match.group(0)!) as Map<String, dynamic>;
      json['generated_at'] = DateTime.now().toIso8601String();
      return DailyMealSuggestion.fromJson(json);
    } catch (e) {
      throw Exception('食事提案の解析に失敗しました: $e');
    }
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
        'max_tokens': _maxTokens,
        'messages': [
          {
            'role': 'user',
            'content': prompt,
          },
        ],
      }),
    );

    if (res.statusCode != 200) {
      final body = jsonDecode(utf8.decode(res.bodyBytes));
      throw Exception(
          body['error']?['message'] ?? 'Anthropic APIエラー (${res.statusCode})');
    }
    return (jsonDecode(utf8.decode(res.bodyBytes)))['content'][0]['text']
        as String;
  }

  // ── OpenAI ────────────────────────────────────────────────────────────────

  Future<String> _callOpenAi(
      String prompt, String apiKey, String model) async {
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
          {'role': 'user', 'content': prompt},
        ],
      }),
    );

    if (res.statusCode != 200) {
      final body = jsonDecode(utf8.decode(res.bodyBytes));
      throw Exception(
          body['error']?['message'] ?? 'OpenAI APIエラー (${res.statusCode})');
    }
    return (jsonDecode(utf8.decode(res.bodyBytes)))['choices'][0]['message']
        ['content'] as String;
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
        'generationConfig': {'maxOutputTokens': _maxTokens},
      }),
    );

    if (res.statusCode != 200) {
      final body = jsonDecode(utf8.decode(res.bodyBytes));
      throw Exception(
          body['error']?['message'] ?? 'Gemini APIエラー (${res.statusCode})');
    }
    return (jsonDecode(utf8.decode(res.bodyBytes)))['candidates'][0]['content']
        ['parts'][0]['text'] as String;
  }
}
