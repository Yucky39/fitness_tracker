import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/energy_profile.dart';
import '../models/training_log.dart';
import '../models/training_plan.dart';
import '../providers/settings_provider.dart';

class TrainingPlanService {
  static const _maxTokens = 8192;

  static String _systemPrompt() {
    return '経験豊富なパーソナルトレーナーとして、ユーザーの身体データ・過去のトレーニング履歴・目標に基づき、'
        '科学的根拠のある個別最適なトレーニングプランを作成してください。\n'
        '必ず以下のJSON形式のみで返答してください（マークダウンのコードブロックは不要です）:\n'
        '{\n'
        '  "name": "プラン名（20文字以内）",\n'
        '  "overview": "プランの概要（なぜこの構成にしたか・期待される効果。100字以内）",\n'
        '  "days": [\n'
        '    {\n'
        '      "label": "Day 1 - 胸・上腕三頭筋",\n'
        '      "exercises": [\n'
        '        {\n'
        '          "name": "種目名",\n'
        '          "type": "free_weight|machine|bodyweight|cardio",\n'
        '          "sets": 4,\n'
        '          "rep_range": "8-12",\n'
        '          "suggested_weight_kg": 60.0,\n'
        '          "rest_seconds": 90,\n'
        '          "note": "フォームや注意事項（省略可）"\n'
        '        }\n'
        '      ]\n'
        '    }\n'
        '  ]\n'
        '}\n'
        '過去の記録がある場合は、その重量・1RMを参考にして現実的な重量を提案してください。'
        '種目名は日本語で記載してください。'
        '指定された使用可能な器具・環境の範囲内で種目を選んでください。自重のみの場合はweightなしの種目のみ提案してください。';
  }

  static String _buildPrompt({
    required TrainingGoal goal,
    required List<MuscleGroup> targetMuscles,
    CutStyle? cutStyle,
    required int daysPerWeek,
    required PlanIntensity intensity,
    required EquipmentOption equipment,
    EnergyProfile? profile,
    required List<TrainingLog> recentLogs,
  }) {
    final buffer = StringBuffer();

    buffer.writeln('【ユーザーの目標と希望】');
    buffer.writeln('目標: ${goal.label}');
    if (goal == TrainingGoal.cut && cutStyle != null) {
      buffer.writeln('トレーニングスタイル: ${cutStyle.label}（${cutStyle.description}）');
      buffer.writeln('※ 部位痩せは生理学的に不可能であるため、全身の体脂肪を減らしながら'
          '筋量を維持・向上させるプランを作成してください。');
    } else {
      buffer.writeln(
          'ターゲット部位: ${targetMuscles.map((m) => m.label).join('・')}');
    }
    buffer.writeln('週のトレーニング日数: $daysPerWeek 日');
    buffer.writeln('強度レベル: ${intensity.label}（${intensity.description}）');
    buffer.writeln('使用可能な器具・環境: ${equipment.label}（${equipment.description}）');
    buffer.writeln();

    if (profile != null) {
      buffer.writeln('【身体データ】');
      buffer.writeln('性別: ${profile.sex.label}');
      buffer.writeln('年齢: ${profile.age} 歳');
      buffer.writeln('身長: ${profile.heightCm} cm');
      buffer.writeln('体重: ${profile.weightKg} kg');
      buffer.writeln('目標体重: ${profile.targetWeightKg} kg');
      buffer.writeln('活動量: ${profile.activityLevel.label}');
      buffer.writeln();
    }

    if (recentLogs.isNotEmpty) {
      buffer.writeln('【過去4週間のトレーニング履歴サマリー】');

      // 種目ごとにベスト重量/1RMをまとめる
      final byExercise = <String, List<TrainingLog>>{};
      for (final log in recentLogs) {
        byExercise.putIfAbsent(log.exerciseName, () => []).add(log);
      }

      final sortedExercises = byExercise.entries.toList()
        ..sort((a, b) => b.value.length.compareTo(a.value.length));

      for (final entry in sortedExercises.take(15)) {
        final name = entry.key;
        final logs = entry.value;
        if (logs.first.exerciseType == ExerciseType.cardio) {
          final best = logs.reduce((a, b) =>
              a.distanceKm > b.distanceKm ? a : b);
          buffer.writeln(
              '・$name: 最長 ${best.distanceKm.toStringAsFixed(1)}km / ${best.durationMinutes}分 (${logs.length}回)');
        } else {
          final bestWeight = logs.map((l) => l.weight).reduce((a, b) => a > b ? a : b);
          final bestOneRm = logs
              .where((l) => l.reps > 0)
              .map((l) => l.weight * (1 + l.reps / 30))
              .fold<double>(0, (max, v) => v > max ? v : max);
          final lastLog = logs.first;
          buffer.write(
              '・$name: 最大重量 ${bestWeight}kg');
          if (bestOneRm > 0) {
            buffer.write(' / 推定1RM ${bestOneRm.toStringAsFixed(1)}kg');
          }
          buffer.writeln(
              ' / 直近 ${lastLog.weight}kg×${lastLog.reps}×${lastLog.sets} (${logs.length}回実施)');
        }
      }

      final uniqueDays = recentLogs
          .map((l) {
            final d = l.date.toLocal();
            return '${d.year}-${d.month}-${d.day}';
          })
          .toSet()
          .length;
      buffer.writeln('合計トレーニング日数（4週間）: $uniqueDays 日');
      buffer.writeln();
    } else {
      buffer.writeln('【トレーニング履歴】');
      buffer.writeln('記録なし（初心者として扱ってください）');
      buffer.writeln();
    }

    buffer.writeln('上記の情報を基に、$daysPerWeek日分のトレーニングプランを作成してください。');
    buffer.writeln('各日に3〜6種目程度を含め、${goal.label}に最適な重量・セット・レップ数を提案してください。');
    if (recentLogs.isNotEmpty) {
      buffer.writeln('過去の記録を参考に、現実的かつ少し挑戦的な重量を提案してください。');
    }

    return buffer.toString();
  }

  /// JSONレスポンスからコードブロックを除去して抽出する
  static String _extractJson(String raw) {
    var text = raw.trim();
    // ```json ... ``` や ``` ... ``` を除去
    final codeBlockRegex = RegExp(r'```(?:json)?\s*([\s\S]*?)\s*```');
    final match = codeBlockRegex.firstMatch(text);
    if (match != null) {
      text = match.group(1)!.trim();
    }
    // 先頭の { から最後の } を抽出
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start >= 0 && end > start) {
      text = text.substring(start, end + 1);
    }
    return text;
  }

  /// トークン上限で途中切れしたJSONを修復する（ベストエフォート）
  static String _repairJson(String text) {
    var s = text.trimRight();
    // 末尾のぶら下がり文字（, : ) を除去
    while (s.isNotEmpty && (s.endsWith(',') || s.endsWith(':'))) {
      s = s.substring(0, s.length - 1).trimRight();
    }

    // 未閉じの文字列を閉じる
    var inString = false;
    var escaped = false;
    for (var i = 0; i < s.length; i++) {
      final c = s[i];
      if (escaped) { escaped = false; continue; }
      if (c == '\\') { escaped = true; continue; }
      if (c == '"') inString = !inString;
    }
    if (inString) s += '"';

    // 開き括弧スタックを数えて閉じる
    var braces = 0;
    var brackets = 0;
    var inStr2 = false;
    var esc2 = false;
    for (var i = 0; i < s.length; i++) {
      final c = s[i];
      if (esc2) { esc2 = false; continue; }
      if (c == '\\') { esc2 = true; continue; }
      if (c == '"') { inStr2 = !inStr2; continue; }
      if (inStr2) continue;
      if (c == '{') braces++;
      else if (c == '}') braces--;
      else if (c == '[') brackets++;
      else if (c == ']') brackets--;
    }
    for (var i = 0; i < brackets; i++) s += ']';
    for (var i = 0; i < braces; i++) s += '}';
    return s;
  }

  Future<TrainingPlan> generatePlan({
    required String id,
    required TrainingGoal goal,
    required List<MuscleGroup> targetMuscles,
    CutStyle? cutStyle,
    required int daysPerWeek,
    required PlanIntensity intensity,
    required EquipmentOption equipment,
    required EnergyProfile? profile,
    required List<TrainingLog> recentLogs,
    required String apiKey,
    required AiProviderType provider,
    String? model,
  }) async {
    if (apiKey.isEmpty) {
      throw Exception('APIキーが設定されていません。設定画面から入力してください。');
    }

    final systemPrompt = _systemPrompt();
    final userMessage = _buildPrompt(
      goal: goal,
      targetMuscles: targetMuscles,
      cutStyle: cutStyle,
      daysPerWeek: daysPerWeek,
      intensity: intensity,
      equipment: equipment,
      profile: profile,
      recentLogs: recentLogs,
    );

    final resolvedModel = model ?? provider.defaultModel;
    final String raw;
    switch (provider) {
      case AiProviderType.anthropic:
        raw = await _callAnthropic(systemPrompt, userMessage, apiKey, resolvedModel);
      case AiProviderType.openai:
        raw = await _callOpenAi(systemPrompt, userMessage, apiKey, resolvedModel);
      case AiProviderType.gemini:
        raw = await _callGemini(systemPrompt, userMessage, apiKey, resolvedModel);
    }

    final jsonText = _extractJson(raw);
    Map<String, dynamic> data;
    try {
      data = jsonDecode(jsonText) as Map<String, dynamic>;
    } catch (_) {
      // トークン上限による途中切れを修復して再試行
      try {
        final repaired = _repairJson(jsonText);
        data = jsonDecode(repaired) as Map<String, dynamic>;
      } catch (e2) {
        throw Exception('AIの返答をパースできませんでした。もう一度試してください。\n詳細: $e2');
      }
    }

    final daysRaw = (data['days'] as List<dynamic>? ?? []);
    final days = daysRaw
        .map((d) => TrainingPlanDay.fromMap(Map<String, dynamic>.from(d as Map)))
        .toList();

    return TrainingPlan(
      id: id,
      name: data['name'] as String? ?? 'トレーニングプラン',
      goal: goal,
      targetMuscles: targetMuscles,
      cutStyle: cutStyle,
      daysPerWeek: daysPerWeek,
      intensity: intensity,
      equipment: equipment,
      days: days,
      overview: data['overview'] as String?,
      createdAt: DateTime.now(),
    );
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
