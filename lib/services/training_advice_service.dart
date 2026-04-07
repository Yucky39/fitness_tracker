import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../models/training_log.dart';
import '../providers/settings_provider.dart';

class TrainingAdviceService {
  static const _maxTokens = 1536;

  static String _systemPrompt(String level) {
    const base = 'あなたは経験豊富なパーソナルトレーナーです。'
        '提示された1件のトレーニング記録と同種目の過去履歴を踏まえ、日本語で具体的な評価とアドバイスを提供してください。'
        '有酸素ではペース・距離・時間のバランス、筋トレでは重量・回数・ボリュームやPRの観点に触れ、次のセッションへの目安を示してください。';
    final modifiers = {
      'strict': '弱点や改善点を遠慮なく指摘し、強度・ボリュームの具体的な改善を提示してください。',
      'normal': '良い点と改善点のバランスよく、実践しやすい次のステップを提案してください。',
      'gentle': 'ポジティブに励ましつつ、改善点は短く優しく伝えてください。',
    };
    return '$base${modifiers[level] ?? modifiers['normal']!}';
  }

  static String _formatPace(double minPerKm) {
    final min = minPerKm.floor();
    final sec = ((minPerKm - min) * 60).round();
    return '$min:${sec.toString().padLeft(2, '0')}/km';
  }

  /// [focusLogs] は通常1件。プロンプト用テキストを組み立てる。
  static String _buildUserMessage({
    required List<TrainingLog> focusLogs,
    required Map<String, List<TrainingLog>> historyByExercise,
    String? sleepContext,
  }) {
    final buffer = StringBuffer();

    for (final log in focusLogs) {
      final when = DateFormat('yyyy/M/d HH:mm').format(log.date.toLocal());
      buffer.writeln('【評価対象の記録】');
      buffer.writeln('日時: $when');
      buffer.writeln('種目: ${log.exerciseName}（${log.exerciseType.label}）');

      if (log.exerciseType == ExerciseType.cardio) {
        buffer.write(
          '  距離: ${log.distanceKm.toStringAsFixed(2)} km, 時間: ${log.durationMinutes} 分',
        );
        if (log.paceMinPerKm != null) {
          buffer.write(', ペース: ${_formatPace(log.paceMinPerKm!)}');
        }
        buffer.writeln();
      } else {
        final oneRm = log.reps > 0
            ? (log.weight * (1 + log.reps / 30))
            : log.weight;
        buffer.writeln(
          '  重量: ${log.weight} kg × ${log.reps} 回 × ${log.sets} セット'
          '（推定1RM: ${oneRm.toStringAsFixed(1)} kg）',
        );
      }
      if (log.note.isNotEmpty) {
        buffer.writeln('  メモ: ${log.note}');
      }

      final history = historyByExercise[log.exerciseName] ?? [];
      if (history.isNotEmpty) {
        final pastWeights = history
            .map((l) {
              if (l.exerciseType == ExerciseType.cardio) {
                return '${l.distanceKm.toStringAsFixed(1)}km・${l.durationMinutes}分'
                    ' (${DateFormat('M/d').format(l.date.toLocal())})';
              }
              return '${l.weight}kg×${l.reps}×${l.sets}'
                  ' (${DateFormat('M/d').format(l.date.toLocal())})';
            })
            .join(' / ');
        buffer.writeln('  同種目の過去（直近・本記録除く）: $pastWeights');
      } else {
        buffer.writeln('  同種目の過去記録: なし（初回または比較データなし）');
      }
      buffer.writeln();
    }

    if (sleepContext != null) {
      buffer.writeln('【コンディション情報】');
      buffer.writeln(sleepContext);
      buffer.writeln(
          '睡眠状態をトレーニングの質・強度設定・回復見込みへのアドバイスに反映してください。');
      buffer.writeln();
    }

    buffer.writeln(
      '上記のこの記録について、過去の傾向と比較しながら評価し、次に取り組むときの具体的なアドバイスを述べてください。',
    );

    return buffer.toString();
  }

  Future<String> getAdvice({
    required List<TrainingLog> focusLogs,
    required Map<String, List<TrainingLog>> historyByExercise,
    required String adviceLevel,
    required String apiKey,
    required AiProviderType provider,
    String? model,
    String? sleepContext,
  }) {
    if (focusLogs.isEmpty) {
      throw Exception('評価対象の記録がありません。');
    }
    final systemPrompt = _systemPrompt(adviceLevel);
    final userMessage = _buildUserMessage(
      focusLogs: focusLogs,
      historyByExercise: historyByExercise,
      sleepContext: sleepContext,
    );
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
      throw Exception(
          body['error']?['message'] ?? 'Anthropic APIエラー (${response.statusCode})');
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
      throw Exception(
          body['error']?['message'] ?? 'OpenAI APIエラー (${response.statusCode})');
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
      throw Exception(
          body['error']?['message'] ?? 'Gemini APIエラー (${response.statusCode})');
    }
    final data = jsonDecode(utf8.decode(response.bodyBytes));
    return data['candidates'][0]['content']['parts'][0]['text'] as String;
  }
}
