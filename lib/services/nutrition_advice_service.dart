import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/food_item.dart';
import '../providers/settings_provider.dart';

class NutritionAdviceService {
  static const _maxTokens = 1024;

  // ── Shared helpers ─────────────────────────────────────────────────────────

  static String _systemPrompt(String level) {
    const base = 'あなたは経験豊富な管理栄養士です。ユーザの食事記録を分析し、日本語で具体的なアドバイスを提供してください。'
        'アドバイスは実践しやすく、科学的根拠に基づいたものにしてください。';
    const modifiers = {
      'strict': '厳格かつ詳細に分析してください。目標から外れた点はすべて具体的な数値とともに指摘し、'
          '改善のための具体的な行動計画を示してください。遠慮なく問題点を指摘してください。',
      'normal': 'バランスよく分析してください。良い点と改善点の両方を挙げ、'
          '無理のない範囲での改善提案を行ってください。',
      'gentle': 'ポジティブで励ます口調で分析してください。良い点を中心に伝え、'
          '重大な問題のみを優しく提案してください。モチベーションを保つことを最優先にしてください。',
    };
    return '$base${modifiers[level] ?? modifiers['normal']!}';
  }

  static String _buildUserMessage({
    required List<FoodItem> items,
    required DateTime date,
    required int calorieGoal,
    required double proteinGoal,
    required double fatGoal,
    required double carbsGoal,
  }) {
    final totalCal = items.fold(0, (s, i) => s + i.calories);
    final totalP = items.fold(0.0, (s, i) => s + i.protein);
    final totalF = items.fold(0.0, (s, i) => s + i.fat);
    final totalC = items.fold(0.0, (s, i) => s + i.carbs);
    final calDiff = totalCal - calorieGoal;
    final calStatus = calDiff >= 0 ? '+$calDiff kcal オーバー' : '${calDiff.abs()} kcal 不足';

    final foodLines = items.isEmpty
        ? '（まだ食事の記録がありません）'
        : items
            .map((i) => '・${i.name}: ${i.calories}kcal (P:${i.protein}g, F:${i.fat}g, C:${i.carbs}g)')
            .join('\n');

    return '''
【${date.year}/${date.month}/${date.day} の食事記録】

■ 摂取した食品:
$foodLines

■ 本日の合計 vs 目標:
- カロリー: ${totalCal}kcal ／ 目標 ${calorieGoal}kcal（$calStatus）
- タンパク質: ${totalP.toStringAsFixed(1)}g ／ 目標 ${proteinGoal}g
- 脂質: ${totalF.toStringAsFixed(1)}g ／ 目標 ${fatGoal}g
- 炭水化物: ${totalC.toStringAsFixed(1)}g ／ 目標 ${carbsGoal}g

上記の食事内容を分析し、栄養バランスのアドバイスをお願いします。
残りの食事で補うべき栄養素についても教えてください。
3〜5点の箇条書きでまとめてください。
''';
  }

  // ── Provider dispatch ──────────────────────────────────────────────────────

  Future<String> getAdvice({
    required List<FoodItem> items,
    required DateTime date,
    required int calorieGoal,
    required double proteinGoal,
    required double fatGoal,
    required double carbsGoal,
    required String adviceLevel,
    required String apiKey,
    required AiProviderType provider,
  }) {
    final systemPrompt = _systemPrompt(adviceLevel);
    final userMessage = _buildUserMessage(
      items: items,
      date: date,
      calorieGoal: calorieGoal,
      proteinGoal: proteinGoal,
      fatGoal: fatGoal,
      carbsGoal: carbsGoal,
    );
    switch (provider) {
      case AiProviderType.anthropic:
        return _callAnthropic(systemPrompt, userMessage, apiKey);
      case AiProviderType.openai:
        return _callOpenAi(systemPrompt, userMessage, apiKey);
      case AiProviderType.gemini:
        return _callGemini(systemPrompt, userMessage, apiKey);
    }
  }

  // ── Anthropic ──────────────────────────────────────────────────────────────

  Future<String> _callAnthropic(String system, String user, String apiKey) async {
    final response = await http.post(
      Uri.parse('https://api.anthropic.com/v1/messages'),
      headers: {
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
        'content-type': 'application/json',
      },
      body: jsonEncode({
        'model': 'claude-haiku-4-5-20251001',
        'max_tokens': _maxTokens,
        'system': system,
        'messages': [
          {'role': 'user', 'content': user},
        ],
      }),
    );

    if (response.statusCode != 200) {
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      throw Exception(body['error']?['message'] ?? 'Anthropic APIエラー (${response.statusCode})');
    }
    final data = jsonDecode(utf8.decode(response.bodyBytes));
    return data['content'][0]['text'] as String;
  }

  // ── OpenAI ─────────────────────────────────────────────────────────────────

  Future<String> _callOpenAi(String system, String user, String apiKey) async {
    final response = await http.post(
      Uri.parse('https://api.openai.com/v1/chat/completions'),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'content-type': 'application/json',
      },
      body: jsonEncode({
        'model': 'gpt-4o-mini',
        'max_tokens': _maxTokens,
        'messages': [
          {'role': 'system', 'content': system},
          {'role': 'user', 'content': user},
        ],
      }),
    );

    if (response.statusCode != 200) {
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      throw Exception(body['error']?['message'] ?? 'OpenAI APIエラー (${response.statusCode})');
    }
    final data = jsonDecode(utf8.decode(response.bodyBytes));
    return data['choices'][0]['message']['content'] as String;
  }

  // ── Google Gemini ──────────────────────────────────────────────────────────

  Future<String> _callGemini(String system, String user, String apiKey) async {
    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$apiKey',
    );

    final response = await http.post(
      uri,
      headers: {'content-type': 'application/json'},
      body: jsonEncode({
        'system_instruction': {
          'parts': [
            {'text': system},
          ],
        },
        'contents': [
          {
            'parts': [
              {'text': user},
            ],
          },
        ],
        'generationConfig': {'maxOutputTokens': _maxTokens},
      }),
    );

    if (response.statusCode != 200) {
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      throw Exception(body['error']?['message'] ?? 'Gemini APIエラー (${response.statusCode})');
    }
    final data = jsonDecode(utf8.decode(response.bodyBytes));
    return data['candidates'][0]['content']['parts'][0]['text'] as String;
  }
}
