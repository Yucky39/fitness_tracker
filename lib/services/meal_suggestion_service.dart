import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/food_item.dart';
import '../models/meal_suggestion.dart';
import '../providers/settings_provider.dart';

enum SuggestionPeriod {
  today,
  tomorrow,
  week;

  String get label {
    switch (this) {
      case SuggestionPeriod.today:
        return '今日';
      case SuggestionPeriod.tomorrow:
        return '明日';
      case SuggestionPeriod.week:
        return '1週間';
    }
  }
}

class MealSuggestionService {
  static const _maxTokens = 8192;

  // ── Prompt builders ───────────────────────────────────────────────────────

  String _buildDailyPrompt({
    required int calorieGoal,
    required double proteinGoal,
    required double fatGoal,
    required double carbsGoal,
    required List<FoodItem> supplements,
    required bool isTomorrow,
  }) {
    final suppCalories = supplements.fold(0, (s, i) => s + i.calories);
    final suppProtein = supplements.fold(0.0, (s, i) => s + i.protein);
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

    final targetDay = isTomorrow ? '明日' : '今日';
    final remainSection = isTomorrow
        ? ''
        : '''
## 当日摂取済みのサプリメント・プロテイン
$suppText

## 食事で補うべき残余目標
- カロリー: ${remainCalories}kcal
- タンパク質 (P): ${remainProtein.toStringAsFixed(1)}g
- 脂質 (F): ${remainFat.toStringAsFixed(1)}g
- 炭水化物 (C): ${remainCarbs.toStringAsFixed(1)}g
''';

    return '''
あなたは日本の管理栄養士です。
ユーザーの1日の栄養目標に基づき、${targetDay}1日分の食事メニューを提案してください。

## ユーザーの1日の栄養目標
- カロリー: ${calorieGoal}kcal
- タンパク質 (P): ${proteinGoal.toStringAsFixed(1)}g
- 脂質 (F): ${fatGoal.toStringAsFixed(1)}g
- 炭水化物 (C): ${carbsGoal.toStringAsFixed(1)}g
$remainSection
## 指示
- ${isTomorrow ? '栄養目標' : '残余目標'}に合わせて朝食・昼食・夕食・間食（必要な場合のみ）を提案してください
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
          "steps": ["手順1", "手順2"]
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

  String _buildDailyFromWeeklyPrompt({
    required int calorieGoal,
    required double proteinGoal,
    required double fatGoal,
    required double carbsGoal,
    required WeeklyDayPlan weeklyDay,
    required bool isTomorrow,
  }) {
    final targetDay = isTomorrow ? '明日' : '今日';
    final mealLines = weeklyDay.meals.map((m) {
      final dishName = m.dishes.isNotEmpty ? m.dishes.first.name : '';
      return '・${m.mealTypeLabel}（${m.mealType}）: $dishName'
          '（${m.totalCalories}kcal、P${m.totalProtein.toStringAsFixed(1)}g、'
          'F${m.totalFat.toStringAsFixed(1)}g、C${m.totalCarbs.toStringAsFixed(1)}g）';
    }).join('\n');

    return '''
あなたは日本の管理栄養士です。
週間プランで決定した$targetDay の献立をもとに、各料理の詳細レシピと食材・分量を提案してください。

## ユーザーの1日の栄養目標
- カロリー: ${calorieGoal}kcal
- タンパク質 (P): ${proteinGoal.toStringAsFixed(1)}g
- 脂質 (F): ${fatGoal.toStringAsFixed(1)}g
- 炭水化物 (C): ${carbsGoal.toStringAsFixed(1)}g

## 週間プランで決定した$targetDay の献立
$mealLines

## 指示
- 各料理の名前は週間プランに記載の名前（「・」で結合されている場合は複数料理として扱う）のまま使用してください
- 各料理の食材・分量・調理手順を具体的に示してください
- 栄養素は文部科学省「日本食品標準成分表2020年版（八訂）」の値を参照してください
- calories/protein/fat/carbsは週間プランの値をほぼ維持してください
- 間食（snack）は週間プランに含まれる場合のみ含めてください

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
          "steps": ["手順1", "手順2"]
        }
      ]
    },
    {"meal_type": "lunch", "dishes": [...]},
    {"meal_type": "dinner", "dishes": [...]}
  ],
  "supplement_note": ""
}

JSONのみを返してください。前後の説明文や```json```マークダウンは不要です。
''';
  }

  String _buildWeeklyPartPrompt({
    required int calorieGoal,
    required double proteinGoal,
    required double fatGoal,
    required double carbsGoal,
    required int startDay,
    required int endDay,
  }) {
    const weekDays = ['月', '火', '水', '木', '金', '土', '日'];
    final dayCount = endDay - startDay + 1;
    final rangeLabel =
        '$startDay日目（${weekDays[startDay - 1]}）〜$endDay日目（${weekDays[endDay - 1]}）';

    final exampleDay = startDay;
    final exampleLabel = '$exampleDay日目（${weekDays[exampleDay - 1]}）';

    return '''
あなたは日本の管理栄養士です。
ユーザーの1日の栄養目標に基づき、$rangeLabel（計$dayCount 日分）の食事メニューをJSONで提案してください。

## 栄養目標（各日共通）
- カロリー: ${calorieGoal}kcal
- タンパク質 (P): ${proteinGoal.toStringAsFixed(1)}g
- 脂質 (F): ${fatGoal.toStringAsFixed(1)}g
- 炭水化物 (C): ${carbsGoal.toStringAsFixed(1)}g

## ルール
- 各日: 朝食・昼食・夕食（間食は必要時のみ）を含める
- 各食事のdishesは必ず1要素のみ。nameは「料理A・料理B」と「・」で結合
- calories/protein/fat/carbsはその食事全体の合計値（整数/小数点1位）
- 毎日異なる献立。食材・調理手順は不要
- $startDay 日目から$endDay 日目まで$dayCount 日分全て実際のデータを出力すること

## 返却形式（JSONのみ）
{
  "days": [
    {
      "day": $exampleDay,
      "day_label": "$exampleLabel",
      "meals": [
        {"meal_type": "breakfast", "dishes": [{"name": "料理A・料理B", "calories": 500, "protein": 25.0, "fat": 12.0, "carbs": 65.0}]},
        {"meal_type": "lunch", "dishes": [{"name": "料理C・料理D", "calories": 650, "protein": 40.0, "fat": 15.0, "carbs": 75.0}]},
        {"meal_type": "dinner", "dishes": [{"name": "料理E・料理F", "calories": 750, "protein": 55.0, "fat": 20.0, "carbs": 85.0}]}
      ]
    }
    ${List.generate(dayCount - 1, (i) {
      final d = startDay + 1 + i;
      return ',\n    {"day": $d, "day_label": "$d日目（${weekDays[d - 1]}）", "meals": [朝食・昼食・夕食を同じ形式で]}';
    }).join('')}
  ],
  "supplement_note": ""
}

JSONのみを返してください。前後の説明文や```json```マークダウンは不要です。
''';
  }

  // ── Public API ────────────────────────────────────────────────────────────

  Future<DailyMealSuggestion> suggestDaily({
    required int calorieGoal,
    required double proteinGoal,
    required double fatGoal,
    required double carbsGoal,
    required List<FoodItem> todayItems,
    required String apiKey,
    required AiProviderType provider,
    required String model,
    required bool isTomorrow,
    WeeklyDayPlan? weeklyDay,
  }) async {
    if (apiKey.isEmpty) {
      throw Exception('APIキーが設定されていません。設定画面からAPIキーを入力してください。');
    }

    final String prompt;
    if (weeklyDay != null) {
      prompt = _buildDailyFromWeeklyPrompt(
        calorieGoal: calorieGoal,
        proteinGoal: proteinGoal,
        fatGoal: fatGoal,
        carbsGoal: carbsGoal,
        weeklyDay: weeklyDay,
        isTomorrow: isTomorrow,
      );
    } else {
      final supplements = isTomorrow
          ? <FoodItem>[]
          : todayItems.where((i) => i.mealType == MealType.supplement).toList();
      prompt = _buildDailyPrompt(
        calorieGoal: calorieGoal,
        proteinGoal: proteinGoal,
        fatGoal: fatGoal,
        carbsGoal: carbsGoal,
        supplements: supplements,
        isTomorrow: isTomorrow,
      );
    }

    final rawText = await _callApi(prompt, apiKey, model, provider);
    return _parseDailyResponse(rawText);
  }

  Future<WeeklyMealSuggestion> suggestWeekly({
    required int calorieGoal,
    required double proteinGoal,
    required double fatGoal,
    required double carbsGoal,
    required String apiKey,
    required AiProviderType provider,
    required String model,
  }) async {
    if (apiKey.isEmpty) {
      throw Exception('APIキーが設定されていません。設定画面からAPIキーを入力してください。');
    }

    final prompt1 = _buildWeeklyPartPrompt(
      calorieGoal: calorieGoal,
      proteinGoal: proteinGoal,
      fatGoal: fatGoal,
      carbsGoal: carbsGoal,
      startDay: 1,
      endDay: 4,
    );
    final prompt2 = _buildWeeklyPartPrompt(
      calorieGoal: calorieGoal,
      proteinGoal: proteinGoal,
      fatGoal: fatGoal,
      carbsGoal: carbsGoal,
      startDay: 5,
      endDay: 7,
    );

    final results = await Future.wait([
      _callApi(prompt1, apiKey, model, provider),
      _callApi(prompt2, apiKey, model, provider),
    ]);

    final part1 = _parseWeeklyResponse(results[0]);
    final part2 = _parseWeeklyResponse(results[1]);

    return WeeklyMealSuggestion(
      days: [...part1.days, ...part2.days],
      supplementNote: part1.supplementNote,
      generatedAt: part1.generatedAt,
    );
  }

  // ── Response parsers ──────────────────────────────────────────────────────

  DailyMealSuggestion _parseDailyResponse(String text) {
    final match = RegExp(r'\{[\s\S]*\}').firstMatch(text);
    if (match == null) {
      final preview = text.length > 200 ? '${text.substring(0, 200)}…' : text;
      throw Exception(
          'AIのレスポンスを解析できませんでした。もう一度お試しください。\n（レスポンス冒頭: $preview）');
    }
    try {
      final json = jsonDecode(match.group(0)!) as Map<String, dynamic>;
      json['generated_at'] = DateTime.now().toIso8601String();
      return DailyMealSuggestion.fromJson(json);
    } catch (e) {
      throw Exception('食事提案のJSON解析に失敗しました: $e');
    }
  }

  WeeklyMealSuggestion _parseWeeklyResponse(String text) {
    final match = RegExp(r'\{[\s\S]*\}').firstMatch(text);
    if (match == null) {
      final preview = text.length > 200 ? '${text.substring(0, 200)}…' : text;
      throw Exception(
          'AIのレスポンスを解析できませんでした。もう一度お試しください。\n（レスポンス冒頭: $preview）');
    }
    try {
      final json = jsonDecode(match.group(0)!) as Map<String, dynamic>;
      json['generated_at'] = DateTime.now().toIso8601String();
      return WeeklyMealSuggestion.fromJson(json);
    } catch (e) {
      throw Exception('週間食事提案のJSON解析に失敗しました: $e');
    }
  }

  // ── API dispatcher ────────────────────────────────────────────────────────

  Future<String> _callApi(
      String prompt, String apiKey, String model, AiProviderType provider) {
    switch (provider) {
      case AiProviderType.anthropic:
        return _callAnthropic(prompt, apiKey, model);
      case AiProviderType.openai:
        return _callOpenAi(prompt, apiKey, model);
      case AiProviderType.gemini:
        return _callGemini(prompt, apiKey, model);
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
          {'role': 'user', 'content': prompt},
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
