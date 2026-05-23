import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../models/training_log.dart';
import '../providers/settings_provider.dart';
import 'ai_proxy_service.dart';

class StretchRecommendationService {
  /// Gemini 3 は thinking トークンも maxOutputTokens に含まれるため余裕を持たせる。
  static const _maxTokens = 4096;

  /// ストレッチ提案は深い推論不要。thinking 分を抑えて本文にトークンを回す。
  static const _geminiThinkingLevel = 'minimal';

  static const _systemPrompt =
      'あなたは経験豊富なパーソナルトレーナーであり、スポーツ科学に基づいたストレッチング指導の専門家です。'
      '提示されたトレーニングセッションの種目リストから、主に使用された筋群を特定し、'
      '効果的なクールダウンストレッチを日本語で提案してください。\n\n'
      '【回答フォーマット】\n'
      '- 使用筋群に対応する3〜5種類のストレッチを、フラットな箇条書き（ネストなし）で提示\n'
      '- 各項目は次の形式で1ブロックにまとめる:\n'
      '  **名称** — 対象筋群: … / 方法: …（1文） / 保持: …\n'
      '- 静的ストレッチを中心に、種目に応じて動的ストレッチも適宜追加\n'
      '- 医療診断ではなく一般的なエクササイズガイドラインとして提供\n'
      '- すべての項目を最後まで書き切る（途中で省略しない）';

  static String _buildUserMessage(List<TrainingLog> logs) {
    final buffer = StringBuffer();
    buffer.writeln('【本日のトレーニングセッション】');
    buffer.writeln('（種目は登録時刻の古い順＝実施順）');
    buffer.writeln();

    for (var i = 0; i < logs.length; i++) {
      final log = logs[i];
      final when = DateFormat('HH:mm').format(log.date.toLocal());
      if (log.exerciseType == ExerciseType.cardio) {
        buffer.writeln(
          '${i + 1}. [$when] ${log.exerciseName}: '
          '${log.distanceKm.toStringAsFixed(1)}km / ${log.durationMinutes}分',
        );
      } else {
        buffer.writeln(
          '${i + 1}. [$when] ${log.exerciseName}（${log.exerciseType.label}）'
          ' ${log.weight}kg × ${log.reps}回 × ${log.sets}セット',
        );
      }
    }

    buffer.writeln();
    buffer.writeln(
      'この種目構成を踏まえ、使用した筋群に対するクールダウンストレッチを提案してください。',
    );
    return buffer.toString();
  }

  Future<String> getRecommendation({
    required List<TrainingLog> sessionLogs,
    bool useSystemAi = false,
    required String apiKey,
    required AiProviderType provider,
    String? model,
  }) async {
    if (sessionLogs.isEmpty) {
      throw Exception('セッションの記録がありません。');
    }

    final userMessage = _buildUserMessage(sessionLogs.sortedByRegistrationTime());

    if (useSystemAi) {
      return AiProxyService.callText(
        systemPrompt: _systemPrompt,
        userMessage: userMessage,
        maxTokens: _maxTokens,
        thinkingLevel: _geminiThinkingLevel,
      );
    }

    final resolvedModel = model ?? provider.defaultModel;
    switch (provider) {
      case AiProviderType.anthropic:
        return _callAnthropic(userMessage, apiKey, resolvedModel);
      case AiProviderType.openai:
        return _callOpenAi(userMessage, apiKey, resolvedModel);
      case AiProviderType.gemini:
        return _callGemini(userMessage, apiKey, resolvedModel);
    }
  }

  Future<String> _callAnthropic(
      String user, String apiKey, String model) async {
    final response = await http.post(
      Uri.parse('https://api.anthropic.com/v1/messages'),
      headers: {
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
        'content-type': 'application/json',
      },
      body: jsonEncode({
        'model': model,
        'max_tokens': _maxTokens,
        'system': _systemPrompt,
        'messages': [
          {'role': 'user', 'content': user},
        ],
      }),
    );
    if (response.statusCode != 200) {
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      throw Exception(body['error']?['message'] ??
          'Anthropic APIエラー (${response.statusCode})');
    }
    final data = jsonDecode(utf8.decode(response.bodyBytes));
    return data['content'][0]['text'] as String;
  }

  Future<String> _callOpenAi(String user, String apiKey, String model) async {
    final response = await http.post(
      Uri.parse('https://api.openai.com/v1/chat/completions'),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'content-type': 'application/json',
      },
      body: jsonEncode({
        'model': model,
        'max_tokens': _maxTokens,
        'messages': [
          {'role': 'system', 'content': _systemPrompt},
          {'role': 'user', 'content': user},
        ],
      }),
    );
    if (response.statusCode != 200) {
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      throw Exception(body['error']?['message'] ??
          'OpenAI APIエラー (${response.statusCode})');
    }
    final data = jsonDecode(utf8.decode(response.bodyBytes));
    return data['choices'][0]['message']['content'] as String;
  }

  Future<String> _callGemini(String user, String apiKey, String model) async {
    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey',
    );
    final response = await http.post(
      uri,
      headers: {'content-type': 'application/json'},
      body: jsonEncode({
        'system_instruction': {
          'parts': [
            {'text': _systemPrompt},
          ],
        },
        'contents': [
          {
            'parts': [
              {'text': user},
            ],
          },
        ],
        'generationConfig': {
          'maxOutputTokens': _maxTokens,
          'thinkingConfig': {'thinkingLevel': _geminiThinkingLevel},
        },
      }),
    );
    if (response.statusCode != 200) {
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      throw Exception(body['error']?['message'] ??
          'Gemini APIエラー (${response.statusCode})');
    }
    final data = jsonDecode(utf8.decode(response.bodyBytes));
    return data['candidates'][0]['content']['parts'][0]['text'] as String;
  }
}
