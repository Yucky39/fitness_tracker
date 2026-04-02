import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../models/training_log.dart';
import '../providers/settings_provider.dart';

class TrainingAdviceService {
  static const _maxTokens = 1536;

  // ── System prompt ──────────────────────────────────────────────────────────

  static String _systemPrompt(String level) {
    const base = 'あなたは経験豊富なパーソナルトレーナーです。'
        'ユーザのトレーニング記録と過去の履歴を分析し、日本語で種目ごとに具体的な評価とアドバイスを提供してください。'
        'PR（自己記録更新）や重量・回数の変化を必ず言及し、次のトレーニングへの具体的な目標を示してください。';
    const modifiers = {
      'strict': '弱点や改善すべき点を遠慮なく指摘し、フォームや強度・ボリュームの具体的な改善計画を提示してください。'
          '停滞している種目は原因を分析し、打開策を提案してください。',
      'normal': 'バランスよく評価してください。成長している点は明確に褒め、'
          '改善が必要な点には実践しやすい次のステップを提案してください。',
      'gentle': 'ポジティブで励ます口調で評価してください。努力と成長を最大限に認め、'
          'モチベーションが上がるコメントを心がけてください。改善点は優しく短く伝える程度にとどめてください。',
    };
    return '$base${modifiers[level] ?? modifiers['normal']!}';
  }

  // ── User message builder ───────────────────────────────────────────────────

  static String _buildUserMessage({
    required List<TrainingLog> todayLogs,
    required Map<String, List<TrainingLog>> historyByExercise,
    required DateTime date,
  }) {
    final dateStr = DateFormat('yyyy/M/d').format(date);

    // Group today's logs by exercise
    final Map<String, List<TrainingLog>> todayByExercise = {};
    for (final log in todayLogs) {
      todayByExercise.putIfAbsent(log.exerciseName, () => []).add(log);
    }

    final buffer = StringBuffer();
    buffer.writeln('【$dateStr のトレーニング記録】\n');

    for (final entry in todayByExercise.entries) {
      final exerciseName = entry.key;
      final logs = entry.value;
      buffer.writeln('■ $exerciseName');

      for (final log in logs) {
        // Epley 1RM estimate
        final oneRm = log.reps > 0
            ? (log.weight * (1 + log.reps / 30))
            : log.weight;
        buffer.writeln(
            '  今日: ${log.weight}kg × ${log.reps}回 × ${log.sets}セット'
            '  (推定1RM: ${oneRm.toStringAsFixed(1)}kg)');
        if (log.note.isNotEmpty) {
          buffer.writeln('  メモ: ${log.note}');
        }
      }

      // Past history for this exercise (excluding today)
      final history = historyByExercise[exerciseName] ?? [];
      if (history.isNotEmpty) {
        final pastWeights = history
            .map((l) => '${l.weight}kg×${l.reps}回×${l.sets}セット'
                ' (${DateFormat('M/d').format(l.date)})')
            .join(', ');
        buffer.writeln('  過去の記録: $pastWeights');
      } else {
        buffer.writeln('  過去の記録: なし（初回）');
      }
      buffer.writeln();
    }

    buffer.writeln(
        '上記の各種目について、過去の記録と比較しながら個別に評価してください。\n'
        'PR達成・重量増加・停滞・フォーム注意事項などを含めた実践的なアドバイスを、\n'
        '種目ごとに区切って記述してください。');

    return buffer.toString();
  }

  // ── Provider dispatch ──────────────────────────────────────────────────────

  Future<String> getAdvice({
    required List<TrainingLog> todayLogs,
    required Map<String, List<TrainingLog>> historyByExercise,
    required DateTime date,
    required String adviceLevel,
    required String apiKey,
    required AiProviderType provider,
  }) {
    final systemPrompt = _systemPrompt(adviceLevel);
    final userMessage = _buildUserMessage(
      todayLogs: todayLogs,
      historyByExercise: historyByExercise,
      date: date,
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

  Future<String> _callAnthropic(
      String system, String user, String apiKey) async {
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
      throw Exception(
          body['error']?['message'] ?? 'Anthropic APIエラー (${response.statusCode})');
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
      throw Exception(
          body['error']?['message'] ?? 'OpenAI APIエラー (${response.statusCode})');
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
      throw Exception(
          body['error']?['message'] ?? 'Gemini APIエラー (${response.statusCode})');
    }
    final data = jsonDecode(utf8.decode(response.bodyBytes));
    return data['candidates'][0]['content']['parts'][0]['text'] as String;
  }
}
