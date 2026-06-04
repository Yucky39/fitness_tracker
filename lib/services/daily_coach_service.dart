import 'dart:convert';
import 'package:http/http.dart' as http;
import '../providers/settings_provider.dart';
import 'ai_proxy_purpose.dart';
import 'ai_proxy_service.dart';

/// 1日の中でコーチが語るタイミング（朝＝先回り、夜＝振り返り）。
enum CoachTimeSlot {
  morning,
  evening;

  String get label => switch (this) {
        CoachTimeSlot.morning => '朝',
        CoachTimeSlot.evening => '夜',
      };

  /// 現在時刻からふさわしいスロットを返す（17時以降は夜）。
  static CoachTimeSlot forTime(DateTime time) {
    return time.hour >= 17 ? CoachTimeSlot.evening : CoachTimeSlot.morning;
  }
}

/// 「手の中にあるパーソナルトレーナー」の心臓部。
///
/// 睡眠・トレーニング・食事・体型という個別ドメインを **横断** して 1 つの文脈に
/// まとめ、その日のユーザーに向けた一貫したコーチングメッセージを生成する。
/// 既存のドメイン別アドバイス（栄養・トレ）と違い、領域をまたいで関連づけるのが役割。
class DailyCoachService {
  static const _maxTokens = 700;

  static String _systemPrompt(String level, CoachTimeSlot slot) {
    final timing = switch (slot) {
      CoachTimeSlot.morning =>
        '今は朝です。これからの1日に向けて、睡眠と昨日までの記録を踏まえ「今日やること」を先回りで示してください。',
      CoachTimeSlot.evening =>
        '今は夜です。今日1日の食事・トレ・歩数・睡眠の見込みを踏まえ「今日の振り返り」と「明日への一手」を示してください。',
    };
    final base = 'あなたはユーザー専属のパーソナルトレーナー兼コーチです。$timing '
        '睡眠・トレーニング・食事・体型の変化を「横断的」に見て、それらの因果やつながりを踏まえた'
        'その日だけの短いコーチングを日本語で行ってください。'
        '各項目を個別に列挙するのではなく、領域をまたいで関連づけて語ってください'
        '（例：睡眠が不足しているので今日は高重量より回復を優先、タンパク質が不足気味なので次の食事で補う等）。'
        '出力は次の形式：1行の挨拶＋本文3点以内の箇条書き＋最後に「今日の一手」を1つ。'
        '合計250文字程度に収め、専門用語は避け、具体的な行動に落としてください。';
    const modifiers = {
      'strict': '妥協のないトレーナーとして、目標から外れた点は数値とともにはっきり指摘し、'
          '甘えを許さない実行プランを示してください。',
      'normal': '前向きさと厳しさのバランスを取り、良い点を認めつつ改善点を具体的に示してください。',
      'gentle': '励ましを最優先にし、できたことを称え、無理のない一歩だけを優しく提案してください。',
    };
    return '$base${modifiers[level] ?? modifiers['normal']!}';
  }

  static String _buildUserMessage(CoachContext c) {
    final b = StringBuffer();
    b.writeln('【${c.date.year}/${c.date.month}/${c.date.day} のユーザーの状況】');
    b.writeln();

    // 睡眠
    b.writeln('■ 睡眠（昨夜）');
    if (c.sleepMinutes != null && c.sleepMinutes! > 0) {
      final h = c.sleepMinutes! ~/ 60;
      final m = c.sleepMinutes! % 60;
      b.writeln('- $h時間$m分（${c.sleepQualityLabel ?? '—'}）／ 目標 ${c.sleepGoalMinutes ~/ 60}時間');
    } else {
      b.writeln('- データなし');
    }

    // トレーニング
    b.writeln('■ トレーニング');
    if (c.todayExercises.isNotEmpty) {
      b.writeln('- 今日の種目: ${c.todayExercises.join('、')}');
      if (c.todayTotalVolume > 0) {
        b.writeln('- 今日の総ボリューム: ${c.todayTotalVolume.round()}kg');
      }
    } else {
      b.writeln('- 今日はまだトレーニング記録なし');
    }
    b.writeln('- 直近7日間のトレ日数: ${c.trainingDaysLast7}日');

    // 食事
    b.writeln('■ 食事（今日の累計 vs 目標）');
    final calDiff = c.intakeCalories - c.calorieGoal;
    final calStatus = calDiff >= 0 ? '+$calDiff kcal' : '${calDiff.abs()} kcal 不足';
    b.writeln('- カロリー: ${c.intakeCalories} / ${c.calorieGoal} kcal（$calStatus）');
    b.writeln('- タンパク質: ${c.intakeProtein.round()} / ${c.proteinGoal.round()} g');
    b.writeln('- 脂質: ${c.intakeFat.round()} / ${c.fatGoal.round()} g');
    b.writeln('- 炭水化物: ${c.intakeCarbs.round()} / ${c.carbsGoal.round()} g');
    if (c.stepsBurnedKcal > 0 || c.steps > 0) {
      b.writeln('- 歩数: ${c.steps}歩（推定消費 ${c.stepsBurnedKcal}kcal）');
    }

    // 体型
    b.writeln('■ 体型');
    if (c.latestWeight != null) {
      b.write('- 最新体重: ${c.latestWeight!.toStringAsFixed(1)}kg');
      if (c.weightDeltaKg != null) {
        final d = c.weightDeltaKg!;
        final sign = d > 0 ? '+' : '';
        b.write('（前回比 $sign${d.toStringAsFixed(1)}kg）');
      }
      b.writeln();
      if (c.targetWeightKg != null && c.targetWeightKg! > 0) {
        b.writeln('- 目標体重: ${c.targetWeightKg!.toStringAsFixed(1)}kg（${c.goalDirectionLabel}）');
      }
      if (c.latestBodyFat != null && c.latestBodyFat! > 0) {
        b.writeln('- 体脂肪率: ${c.latestBodyFat!.toStringAsFixed(1)}%');
      }
    } else {
      b.writeln('- 体型記録なし');
    }

    b.writeln();
    b.writeln('上記を横断的に見て、今日のこのユーザーへのコーチングをお願いします。');
    return b.toString();
  }

  Future<String> generate({
    required CoachContext context,
    required String adviceLevel,
    CoachTimeSlot timeSlot = CoachTimeSlot.morning,
    bool useSystemAi = false,
    required String apiKey,
    required AiProviderType provider,
    String? model,
  }) {
    final systemPrompt = _systemPrompt(adviceLevel, timeSlot);
    final userMessage = _buildUserMessage(context);

    if (useSystemAi) {
      return AiProxyService.callText(
        systemPrompt: systemPrompt,
        userMessage: userMessage,
        maxTokens: _maxTokens,
        purpose: AiProxyPurpose.coach,
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

/// 横断コーチングに渡す、その日のユーザー状況スナップショット。
class CoachContext {
  final DateTime date;

  // 睡眠
  final int? sleepMinutes;
  final String? sleepQualityLabel;
  final int sleepGoalMinutes;

  // トレーニング
  final List<String> todayExercises;
  final double todayTotalVolume;
  final int trainingDaysLast7;

  // 食事
  final int intakeCalories;
  final int calorieGoal;
  final double intakeProtein;
  final double proteinGoal;
  final double intakeFat;
  final double fatGoal;
  final double intakeCarbs;
  final double carbsGoal;
  final int steps;
  final int stepsBurnedKcal;

  // 体型
  final double? latestWeight;
  final double? weightDeltaKg;
  final double? targetWeightKg;
  final double? latestBodyFat;

  const CoachContext({
    required this.date,
    this.sleepMinutes,
    this.sleepQualityLabel,
    this.sleepGoalMinutes = 420,
    this.todayExercises = const [],
    this.todayTotalVolume = 0,
    this.trainingDaysLast7 = 0,
    required this.intakeCalories,
    required this.calorieGoal,
    required this.intakeProtein,
    required this.proteinGoal,
    required this.intakeFat,
    required this.fatGoal,
    required this.intakeCarbs,
    required this.carbsGoal,
    this.steps = 0,
    this.stepsBurnedKcal = 0,
    this.latestWeight,
    this.weightDeltaKg,
    this.targetWeightKg,
    this.latestBodyFat,
  });

  String get goalDirectionLabel {
    if (latestWeight == null || targetWeightKg == null || targetWeightKg == 0) {
      return '目標未設定';
    }
    final diff = targetWeightKg! - latestWeight!;
    if (diff.abs() < 0.3) return '維持';
    return diff < 0 ? '減量' : '増量';
  }
}
