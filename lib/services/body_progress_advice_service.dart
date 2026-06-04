import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/body_metrics.dart';
import '../providers/settings_provider.dart';
import 'ai_proxy_purpose.dart';
import 'ai_proxy_service.dart';

/// 体型（体重・腹囲・体脂肪）の推移をパーソナルトレーナー目線で講評する。
///
/// 「変化の可視化」はトレーナーが鏡の前で行うことそのもの。数値の推移を読み取り、
/// 前向きさと次の一手を返す。
class BodyProgressAdviceService {
  static const _maxTokens = 600;

  static String _systemPrompt(String level) {
    const base = 'あなたはユーザー専属のパーソナルトレーナーです。'
        '体型（体重・腹囲・体脂肪率）の推移データを読み取り、変化の傾向を日本語で講評してください。'
        '良い変化は具体的に称え、停滞や逆行があれば原因仮説と次の一手を1つ示してください。'
        '挨拶＋2〜3文＋「次の一手」を1つ、合計200文字程度で。';
    const modifiers = {
      'strict': '甘えのない口調で、数値の事実に基づき率直に指摘してください。',
      'normal': '前向きさと現実的な助言のバランスを取ってください。',
      'gentle': '励ましを最優先に、できている点を中心に優しく伝えてください。',
    };
    return '$base${modifiers[level] ?? modifiers['normal']!}';
  }

  static String _buildUserMessage({
    required List<BodyMetrics> metrics,
    double? targetWeightKg,
  }) {
    final sorted = [...metrics]..sort((a, b) => a.date.compareTo(b.date));
    final first = sorted.first;
    final last = sorted.last;
    final days = last.date.difference(first.date).inDays;

    String fmtDelta(double from, double to, String unit) {
      final d = to - from;
      final sign = d > 0 ? '+' : '';
      return '$sign${d.toStringAsFixed(1)}$unit';
    }

    final b = StringBuffer();
    b.writeln('【体型の推移（${sorted.length}件・期間$days日）】');
    b.writeln('開始(${first.date.month}/${first.date.day}): '
        '体重${first.weight.toStringAsFixed(1)}kg / '
        '腹囲${first.waist.toStringAsFixed(1)}cm / '
        '体脂肪${first.bodyFatPercentage.toStringAsFixed(1)}%');
    b.writeln('最新(${last.date.month}/${last.date.day}): '
        '体重${last.weight.toStringAsFixed(1)}kg / '
        '腹囲${last.waist.toStringAsFixed(1)}cm / '
        '体脂肪${last.bodyFatPercentage.toStringAsFixed(1)}%');
    b.writeln('変化: 体重${fmtDelta(first.weight, last.weight, 'kg')} / '
        '腹囲${fmtDelta(first.waist, last.waist, 'cm')} / '
        '体脂肪${fmtDelta(first.bodyFatPercentage, last.bodyFatPercentage, '%')}');
    if (targetWeightKg != null && targetWeightKg > 0) {
      final remain = targetWeightKg - last.weight;
      b.writeln('目標体重: ${targetWeightKg.toStringAsFixed(1)}kg'
          '（あと${remain.abs().toStringAsFixed(1)}kg ${remain < 0 ? '減量' : '増量'}）');
    }
    b.writeln();
    b.writeln('この推移を講評し、次の一手を示してください。');
    return b.toString();
  }

  Future<String> getAdvice({
    required List<BodyMetrics> metrics,
    double? targetWeightKg,
    required String adviceLevel,
    bool useSystemAi = false,
    required String apiKey,
    required AiProviderType provider,
    String? model,
  }) {
    final systemPrompt = _systemPrompt(adviceLevel);
    final userMessage = _buildUserMessage(
      metrics: metrics,
      targetWeightKg: targetWeightKg,
    );

    if (useSystemAi) {
      return AiProxyService.callText(
        systemPrompt: systemPrompt,
        userMessage: userMessage,
        maxTokens: _maxTokens,
        purpose: AiProxyPurpose.bodyProgress,
      );
    }

    final resolvedModel = model ?? provider.defaultModel;
    switch (provider) {
      case AiProviderType.anthropic:
        return _callAnthropic(systemPrompt, userMessage, apiKey, resolvedModel);
      case AiProviderType.openai:
        return _callOpenAi(systemPrompt, userMessage, apiKey, resolvedModel);
      case AiProviderType.gemini:
        return _callGemini(systemPrompt, userMessage, apiKey, resolvedModel);
    }
  }

  Future<String> _callAnthropic(
      String system, String user, String apiKey, String model) async {
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
        'system': system,
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

  Future<String> _callOpenAi(
      String system, String user, String apiKey, String model) async {
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
          {'role': 'system', 'content': system},
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

  Future<String> _callGemini(
      String system, String user, String apiKey, String model) async {
    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey',
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
      throw Exception(body['error']?['message'] ??
          'Gemini APIエラー (${response.statusCode})');
    }
    final data = jsonDecode(utf8.decode(response.bodyBytes));
    return data['candidates'][0]['content']['parts'][0]['text'] as String;
  }
}
