import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../models/food_item.dart';
import '../models/training_log.dart';
import '../providers/settings_provider.dart';
import 'training_calorie_calculator.dart';

/// 週間・月間の振り返りレポートを生成するサービス。
class ReviewAdviceService {
  static const _maxTokens = 2048;

  // ── System prompts ──────────────────────────────────────────────────────────

  static String _weeklySystemPrompt(String level) {
    const base = 'あなたは経験豊富なパーソナルトレーナー兼管理栄養士です。'
        '提示された1週間のトレーニングと食事データを総合的に分析し、日本語で振り返りレポートを作成してください。'
        'トレーニング面では：頻度・総ボリューム・種目バランス（筋肉部位・有酸素の配分）・強度の推移に触れてください。'
        '食事面では：平均カロリー・PFCバランス・目標達成度に触れてください。'
        'トレーニングと食事の組み合わせの観点から、体組成・パフォーマンス・回復への影響を考察し、'
        '来週に向けた具体的な改善点と優先事項を3〜5点で示してください。';
    final modifiers = {
      'strict': '問題点・非効率な点をすべて具体的な数値とともに指摘し、来週の明確な数値目標を設定してください。',
      'normal': '良い点と改善点をバランスよく取り上げ、実践しやすい来週の行動計画を提案してください。',
      'gentle': 'この1週間の努力をポジティブに評価しつつ、最も重要な改善点を優しく伝えてください。',
    };
    return '$base${modifiers[level] ?? modifiers['normal']!}';
  }

  static String _monthlySystemPrompt(String level) {
    const base = 'あなたは経験豊富なパーソナルトレーナー兼管理栄養士です。'
        '提示された1ヶ月間のトレーニングと食事データを総合的に分析し、日本語で月次振り返りレポートを作成してください。'
        'トレーニング面では：月間の総ワークアウト数・頻度の安定性・ボリューム推移・種目の多様性・有酸素と筋トレの比率に触れてください。'
        '食事面では：月平均カロリー・PFC推移・目標達成の安定性に触れてください。'
        '月間を通じた体組成・パフォーマンスの変化傾向を考察し、来月のトレーニングプログラムと食事戦略の提案を5点以内で示してください。';
    final modifiers = {
      'strict': '月間の成果を数値で詳細に評価し、達成できなかった目標の原因分析と来月の具体的な数値目標を示してください。',
      'normal': '月間の成果と課題を整理し、来月の実践的な改善計画を提案してください。',
      'gentle': '1ヶ月間の継続を称え、前向きになれる振り返りと来月の小さな改善ステップを提案してください。',
    };
    return '$base${modifiers[level] ?? modifiers['normal']!}';
  }

  // ── User messages ───────────────────────────────────────────────────────────

  static String _buildWeeklyUserMessage({
    required List<TrainingLog> logs,
    required List<FoodItem> foodItems,
    required DateTime weekStart,
    required DateTime weekEnd,
    required int calorieGoal,
    required double proteinGoal,
    required double fatGoal,
    required double carbsGoal,
    required double bodyWeightKg,
  }) {
    final fmt = DateFormat('M/d');
    final buffer = StringBuffer();
    buffer.writeln('【週間振り返り: ${fmt.format(weekStart)} 〜 ${fmt.format(weekEnd)}】');
    buffer.writeln();

    // ── トレーニングサマリー
    buffer.writeln('■ トレーニングサマリー');
    if (logs.isEmpty) {
      buffer.writeln('この週のトレーニング記録はありません。');
    } else {
      final daySet = <String>{};
      for (final l in logs) {
        final d = l.date.toLocal();
        daySet.add('${d.year}-${d.month}-${d.day}');
      }
      final strengthLogs = logs.where((l) => l.exerciseType != ExerciseType.cardio).toList();
      final cardioLogs = logs.where((l) => l.exerciseType == ExerciseType.cardio).toList();
      final totalKcal = TrainingCalorieCalculator.total(logs, bodyWeightKg: bodyWeightKg);
      final totalVolume = strengthLogs.fold(0.0, (s, l) => s + l.totalVolume);
      final totalCardioMin = cardioLogs.fold(0, (s, l) => s + l.durationMinutes);
      final totalCardioKm = cardioLogs.fold(0.0, (s, l) => s + l.distanceKm);
      final exerciseNames = logs.map((l) => l.exerciseName).toSet();
      final rpes = logs.where((l) => l.rpe != null).map((l) => l.rpe!).toList();

      buffer.writeln('  ワークアウト日数: ${daySet.length} 日 / 7日');
      buffer.writeln('  総記録数: ${logs.length} 件 / ${exerciseNames.length} 種目');
      buffer.writeln('  推定消費カロリー合計: ${totalKcal.round()} kcal');
      if (strengthLogs.isNotEmpty) {
        final label = totalVolume >= 1000
            ? '${(totalVolume / 1000).toStringAsFixed(1)} t'
            : '${totalVolume.round()} kg';
        buffer.writeln('  筋トレ総ボリューム: $label（重量×回数×セット）');
      }
      if (cardioLogs.isNotEmpty) {
        buffer.writeln('  有酸素: ${totalCardioKm.toStringAsFixed(1)} km / ${totalCardioMin} 分');
      }
      if (rpes.isNotEmpty) {
        final avgRpe = rpes.fold(0, (s, v) => s + v) / rpes.length;
        buffer.writeln('  平均RPE: ${avgRpe.toStringAsFixed(1)}');
      }

      buffer.writeln();
      buffer.writeln('  日別トレーニング:');
      final byDay = <String, List<TrainingLog>>{};
      for (final l in logs) {
        final d = l.date.toLocal();
        final key = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
        byDay.putIfAbsent(key, () => []).add(l);
      }
      for (final entry in (byDay.entries.toList()..sort((a, b) => a.key.compareTo(b.key)))) {
        final dayLogs = entry.value;
        final names = dayLogs.map((l) => l.exerciseName).toSet().join('・');
        buffer.writeln('  ${entry.key}: ${names}（${dayLogs.length}件）');
      }
    }

    buffer.writeln();

    // ── 食事サマリー
    buffer.writeln('■ 食事サマリー');
    if (foodItems.isEmpty) {
      buffer.writeln('この週の食事記録はありません。');
    } else {
      final byDay = <String, List<FoodItem>>{};
      for (final item in foodItems) {
        final d = item.date.toLocal();
        final key = '${d.year}-${d.month}-${d.day}';
        byDay.putIfAbsent(key, () => []).add(item);
      }
      final recordedDays = byDay.length;
      final avgCal = foodItems.fold(0, (s, i) => s + i.calories) / recordedDays;
      final avgP = foodItems.fold(0.0, (s, i) => s + i.protein) / recordedDays;
      final avgF = foodItems.fold(0.0, (s, i) => s + i.fat) / recordedDays;
      final avgC = foodItems.fold(0.0, (s, i) => s + i.carbs) / recordedDays;

      buffer.writeln('  食事記録日数: $recordedDays 日');
      buffer.writeln('  1日平均カロリー: ${avgCal.round()} kcal（目標: $calorieGoal kcal）');
      buffer.writeln('  1日平均PFC: P ${avgP.toStringAsFixed(1)}g（目標: ${proteinGoal}g） /'
          ' F ${avgF.toStringAsFixed(1)}g（目標: ${fatGoal}g） /'
          ' C ${avgC.toStringAsFixed(1)}g（目標: ${carbsGoal}g）');
    }

    buffer.writeln();
    buffer.writeln('上記データを基に、この1週間の総合評価と来週への具体的なアドバイスを提供してください。');
    return buffer.toString();
  }

  static String _buildMonthlyUserMessage({
    required List<TrainingLog> logs,
    required List<FoodItem> foodItems,
    required DateTime monthStart,
    required DateTime monthEnd,
    required int calorieGoal,
    required double proteinGoal,
    required double fatGoal,
    required double carbsGoal,
    required double bodyWeightKg,
  }) {
    final fmt = DateFormat('yyyy年M月');
    final buffer = StringBuffer();
    buffer.writeln('【月間振り返り: ${fmt.format(monthStart)}】');
    buffer.writeln();

    // ── トレーニングサマリー
    buffer.writeln('■ トレーニングサマリー');
    if (logs.isEmpty) {
      buffer.writeln('この月のトレーニング記録はありません。');
    } else {
      final daySet = <String>{};
      for (final l in logs) {
        final d = l.date.toLocal();
        daySet.add('${d.year}-${d.month}-${d.day}');
      }
      final strengthLogs = logs.where((l) => l.exerciseType != ExerciseType.cardio).toList();
      final cardioLogs = logs.where((l) => l.exerciseType == ExerciseType.cardio).toList();
      final totalKcal = TrainingCalorieCalculator.total(logs, bodyWeightKg: bodyWeightKg);
      final totalVolume = strengthLogs.fold(0.0, (s, l) => s + l.totalVolume);
      final totalCardioMin = cardioLogs.fold(0, (s, l) => s + l.durationMinutes);
      final totalCardioKm = cardioLogs.fold(0.0, (s, l) => s + l.distanceKm);
      final exerciseNames = logs.map((l) => l.exerciseName).toSet();
      final rpes = logs.where((l) => l.rpe != null).map((l) => l.rpe!).toList();

      final daysInMonth = monthEnd.difference(monthStart).inDays + 1;
      final weekCount = (daysInMonth / 7).ceil();

      buffer.writeln('  ワークアウト日数: ${daySet.length} 日 / $daysInMonth日');
      buffer.writeln('  週平均ワークアウト日数: ${(daySet.length / weekCount).toStringAsFixed(1)} 日/週');
      buffer.writeln('  総記録数: ${logs.length} 件 / ${exerciseNames.length} 種目');
      buffer.writeln('  推定消費カロリー合計: ${totalKcal.round()} kcal');
      if (strengthLogs.isNotEmpty) {
        final label = totalVolume >= 1000
            ? '${(totalVolume / 1000).toStringAsFixed(1)} t'
            : '${totalVolume.round()} kg';
        buffer.writeln('  筋トレ総ボリューム: $label');
      }
      if (cardioLogs.isNotEmpty) {
        buffer.writeln('  有酸素合計: ${totalCardioKm.toStringAsFixed(1)} km / ${totalCardioMin} 分');
      }
      if (rpes.isNotEmpty) {
        final avgRpe = rpes.fold(0, (s, v) => s + v) / rpes.length;
        buffer.writeln('  平均RPE: ${avgRpe.toStringAsFixed(1)}');
      }

      // 週別内訳
      buffer.writeln();
      buffer.writeln('  週別トレーニング日数:');
      for (int w = 0; w < weekCount; w++) {
        final ws = monthStart.add(Duration(days: w * 7));
        final we = ws.add(const Duration(days: 6));
        final clampedWe = we.isAfter(monthEnd) ? monthEnd : we;
        final weekDays = <String>{};
        for (final l in logs) {
          final d = l.date.toLocal();
          final ld = DateTime(d.year, d.month, d.day);
          if (!ld.isBefore(ws) && !ld.isAfter(clampedWe)) {
            weekDays.add('${d.year}-${d.month}-${d.day}');
          }
        }
        buffer.writeln(
            '  ${DateFormat('M/d').format(ws)}〜${DateFormat('M/d').format(clampedWe)}: ${weekDays.length}日');
      }
    }

    buffer.writeln();

    // ── 食事サマリー
    buffer.writeln('■ 食事サマリー');
    if (foodItems.isEmpty) {
      buffer.writeln('この月の食事記録はありません。');
    } else {
      final byDay = <String, List<FoodItem>>{};
      for (final item in foodItems) {
        final d = item.date.toLocal();
        byDay.putIfAbsent('${d.year}-${d.month}-${d.day}', () => []).add(item);
      }
      final recordedDays = byDay.length;
      final avgCal = foodItems.fold(0, (s, i) => s + i.calories) / recordedDays;
      final avgP = foodItems.fold(0.0, (s, i) => s + i.protein) / recordedDays;
      final avgF = foodItems.fold(0.0, (s, i) => s + i.fat) / recordedDays;
      final avgC = foodItems.fold(0.0, (s, i) => s + i.carbs) / recordedDays;

      buffer.writeln('  食事記録日数: $recordedDays 日');
      buffer.writeln('  1日平均カロリー: ${avgCal.round()} kcal（目標: $calorieGoal kcal）');
      buffer.writeln('  1日平均PFC: P ${avgP.toStringAsFixed(1)}g /'
          ' F ${avgF.toStringAsFixed(1)}g /'
          ' C ${avgC.toStringAsFixed(1)}g');
      buffer.writeln('  目標: P ${proteinGoal}g / F ${fatGoal}g / C ${carbsGoal}g');
    }

    buffer.writeln();
    buffer.writeln('上記データを基に、この1ヶ月の総合評価と来月への具体的な改善アドバイスを提供してください。');
    return buffer.toString();
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  Future<String> getWeeklyReview({
    required List<TrainingLog> logs,
    required List<FoodItem> foodItems,
    required DateTime weekStart,
    required DateTime weekEnd,
    required int calorieGoal,
    required double proteinGoal,
    required double fatGoal,
    required double carbsGoal,
    required double bodyWeightKg,
    required String adviceLevel,
    required String apiKey,
    required AiProviderType provider,
    String? model,
  }) {
    final systemPrompt = _weeklySystemPrompt(adviceLevel);
    final userMessage = _buildWeeklyUserMessage(
      logs: logs,
      foodItems: foodItems,
      weekStart: weekStart,
      weekEnd: weekEnd,
      calorieGoal: calorieGoal,
      proteinGoal: proteinGoal,
      fatGoal: fatGoal,
      carbsGoal: carbsGoal,
      bodyWeightKg: bodyWeightKg,
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

  Future<String> getMonthlyReview({
    required List<TrainingLog> logs,
    required List<FoodItem> foodItems,
    required DateTime monthStart,
    required DateTime monthEnd,
    required int calorieGoal,
    required double proteinGoal,
    required double fatGoal,
    required double carbsGoal,
    required double bodyWeightKg,
    required String adviceLevel,
    required String apiKey,
    required AiProviderType provider,
    String? model,
  }) {
    final systemPrompt = _monthlySystemPrompt(adviceLevel);
    final userMessage = _buildMonthlyUserMessage(
      logs: logs,
      foodItems: foodItems,
      monthStart: monthStart,
      monthEnd: monthEnd,
      calorieGoal: calorieGoal,
      proteinGoal: proteinGoal,
      fatGoal: fatGoal,
      carbsGoal: carbsGoal,
      bodyWeightKg: bodyWeightKg,
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

  // ── Providers ──────────────────────────────────────────────────────────────

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
