import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../models/training_log.dart';
import '../providers/settings_provider.dart';

class TrainingAdviceService {
  /// 出力が途中で切れないよう、十分な余裕を持たせる（プロンプトが長い場合も同様）。
  static const _maxTokens = 4096;

  static String _systemPrompt(String level) {
    const base = 'あなたは経験豊富なパーソナルトレーナーであり、運動生理学の基礎に通じています。'
        '提示された1件のトレーニング記録と同種目の過去履歴、および直近の負荷の要約を踏まえ、日本語で具体的な評価とアドバイスを提供してください。'
        '有酸素ではペース・距離・時間のバランス、筋トレでは重量・回数・ボリュームやPRの観点に触れ、次のセッションへの目安を示してください。'
        '主観的運動強度（RPE: 1〜10）が記録されている場合は、内部負荷の目安として扱い、外部負荷（重量・時間など）と食い違う場合はフォーム・疲労・コンディションの観点から考察してください。'
        '直近のトレーニング頻度・ボリュームと照らし、過負荷や回復不足の可能性、周期化（軽い日・中程度・高負荷の配分）に触れてください。'
        '負担を軽減するための休息の取り方、睡眠・栄養・水分の一般的な留意点、および種目に応じたストレッチやモビリティ（対象となる筋群、静止ストレッチは各15〜60秒程度・反復の目安など）を、医療診断ではなく一般的なエクササイズ指針として簡潔に含めてください。';
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

  /// 評価対象日を含む直近7日間の記録から、頻度・負荷の要約文を作る（AIの文脈用）。
  static String? buildWeeklyLoadContext(
    List<TrainingLog> allLogs,
    DateTime focusDate,
  ) {
    final anchor = focusDate.toLocal();
    final end = DateTime(anchor.year, anchor.month, anchor.day, 23, 59, 59, 999);
    final start =
        DateTime(anchor.year, anchor.month, anchor.day)
            .subtract(const Duration(days: 6));

    final inWindow = allLogs.where((l) {
      final d = l.date.toLocal();
      return !d.isBefore(start) && !d.isAfter(end);
    }).toList();

    if (inWindow.isEmpty) return null;

    final daysByKey = <String>{};
    for (final l in inWindow) {
      final d = l.date.toLocal();
      daysByKey.add('${d.year}-${d.month}-${d.day}');
    }
    final trainingDays = daysByKey.length;

    var strengthSets = 0;
    var cardioMinutes = 0;
    var totalVolumeKg = 0.0;
    final rpes = <int>[];
    for (final l in inWindow) {
      if (l.exerciseType == ExerciseType.cardio) {
        cardioMinutes += l.durationMinutes;
      } else {
        strengthSets += l.sets;
        totalVolumeKg += l.totalVolume;
      }
      if (l.rpe != null) rpes.add(l.rpe!);
    }

    final fromLabel = DateFormat('M/d').format(start);
    final toLabel = DateFormat('M/d').format(anchor);
    final buffer = StringBuffer();
    buffer.writeln('【直近7日間のトレーニング負荷（$fromLabel〜$toLabel）】');
    buffer.writeln('トレーニングがあった日数: $trainingDays 日');
    buffer.writeln('筋トレ種目の合計セット数: $strengthSets');
    if (totalVolumeKg >= 1000) {
      buffer.writeln(
          '総ボリューム目安: ${(totalVolumeKg / 1000).toStringAsFixed(1)} t（kg×回×セットの合計）');
    } else {
      buffer.writeln('総ボリューム目安: ${totalVolumeKg.round()} kg');
    }
    buffer.writeln('有酸素の合計時間: $cardioMinutes 分');
    buffer.writeln('この期間の記録件数: ${inWindow.length} 件');
    if (rpes.isNotEmpty) {
      final sum = rpes.fold<int>(0, (a, b) => a + b);
      final avg = sum / rpes.length;
      buffer.writeln(
          'RPEの平均: ${avg.toStringAsFixed(1)}（1〜10。未記録の記録は平均から除外）');
      buffer.writeln('RPEが記録されている件数: ${rpes.length} / ${inWindow.length}');
    } else {
      buffer.writeln('この期間のRPE記録はありません。');
    }
    buffer.writeln(
        '上記の負荷・頻度と今回の記録を照らし、運動科学の観点（過負荷、回復、適切な強度の設定）から言及してください。');
    return buffer.toString();
  }

  /// [focusLogs] は通常1件。プロンプト用テキストを組み立てる。
  static String _buildUserMessage({
    required List<TrainingLog> focusLogs,
    required Map<String, List<TrainingLog>> historyByExercise,
    String? sleepContext,
    String? weeklyLoadContext,
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
      if (log.rpe != null) {
        buffer.writeln('  RPE（主観的運動強度 1〜10）: ${log.rpe}');
      } else {
        buffer.writeln('  RPE: 未記録');
      }
      if (log.note.isNotEmpty) {
        buffer.writeln('  メモ: ${log.note}');
      }

      final history = historyByExercise[log.exerciseName] ?? [];
      if (history.isNotEmpty) {
        final pastWeights = history
            .map((l) {
              final rpePart = l.rpe != null ? ' RPE${l.rpe}' : '';
              if (l.exerciseType == ExerciseType.cardio) {
                return '${l.distanceKm.toStringAsFixed(1)}km・${l.durationMinutes}分$rpePart'
                    ' (${DateFormat('M/d').format(l.date.toLocal())})';
              }
              return '${l.weight}kg×${l.reps}×${l.sets}$rpePart'
                  ' (${DateFormat('M/d').format(l.date.toLocal())})';
            })
            .join(' / ');
        buffer.writeln('  同種目の過去（直近・本記録除く）: $pastWeights');
      } else {
        buffer.writeln('  同種目の過去記録: なし（初回または比較データなし）');
      }
      buffer.writeln();
    }

    if (weeklyLoadContext != null && weeklyLoadContext.isNotEmpty) {
      buffer.writeln(weeklyLoadContext);
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
    String? weeklyLoadContext,
  }) {
    if (focusLogs.isEmpty) {
      throw Exception('評価対象の記録がありません。');
    }
    final systemPrompt = _systemPrompt(adviceLevel);
    final userMessage = _buildUserMessage(
      focusLogs: focusLogs,
      historyByExercise: historyByExercise,
      sleepContext: sleepContext,
      weeklyLoadContext: weeklyLoadContext,
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
