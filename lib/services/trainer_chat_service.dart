import 'package:intl/intl.dart';

import '../models/chat_message.dart';
import '../models/period_summary.dart';
import '../providers/energy_profile_provider.dart';
import '../services/ai_proxy_service.dart';

/// AIトレーナーチャットの送信を担うステートレスなサービス。
///
/// - システムプロンプト（口調 + 安全ガードレール + データ要約文脈）の組立
/// - 会話履歴の整形（直近 [maxHistoryMessages] 件のみ送信＝コスト抑制）
/// - [AiProxyService.callChat] によるマルチターン生成
class TrainerChatService {
  /// 返答長キャップ。出力は入力の約6倍高いため、ここでコスト上限を握る。
  static const int maxTokens = 800;

  /// プロキシへ送る直近メッセージ数の上限（古い履歴は切り捨て＝コスト抑制）。
  static const int maxHistoryMessages = 12;

  /// 医療・診断に踏み込まないためのガードレール（システムプロンプトに固定）。
  static const String _safetyGuardrail =
      'あなたは医療従事者ではありません。診断・治療方針・投薬の指示、極端な食事制限の指示は行わないでください。'
      '痛み・しびれ・持病・摂食障害が疑われる相談、または体調の異常に関わる内容には、'
      '一般的なエクササイズ／栄養の情報提供の範囲でのみ触れ、必ず医師・管理栄養士・理学療法士など専門家への相談を促してください。'
      'ユーザーの安全を最優先し、無理を勧めないでください。';

  static String buildSystemPrompt({
    required String adviceLevel,
    required String contextSummary,
  }) {
    const base = 'あなたは経験豊富なパーソナルトレーナー兼コンディショニングの相談相手です。'
        'トレーニング・栄養・睡眠・日常のルーティンなど、ユーザーの健康的な生活づくりを日本語でサポートします。'
        '回答は会話的で簡潔に、要点を押さえて返してください。長くなりすぎないようにし、必要なら箇条書きを使ってください。'
        '一般的なエクササイズ・栄養の知見に基づき、具体的で実践しやすい助言を心がけてください。';
    final modifiers = {
      'strict': '改善点は遠慮なく具体的に指摘し、甘えのない実践的な提案をしてください。',
      'normal': '良い点と改善点をバランスよく伝え、前向きに次の一歩を提案してください。',
      'gentle': 'ポジティブに励ましながら、改善点は短く優しく伝えてください。',
    };
    final tone = modifiers[adviceLevel] ?? modifiers['normal']!;

    final buffer = StringBuffer()
      ..writeln(base)
      ..writeln(tone)
      ..writeln(_safetyGuardrail);

    if (contextSummary.trim().isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('【ユーザーの最近の記録（参考情報。質問に関連する場合のみ自然に活用してください）】')
        ..writeln(contextSummary.trim());
    }
    return buffer.toString();
  }

  /// アプリ内のデータからチャットの文脈となる要約を組み立てる。
  /// 生ログは渡さず要約に留める（トークン＝コスト抑制のため）。
  static String buildContextSummary({
    EnergyProfileState? profile,
    int? calorieGoal,
    double? proteinGoal,
    double? fatGoal,
    double? carbsGoal,
    PeriodSummary? weekSummary,
  }) {
    final buffer = StringBuffer();

    if (profile != null &&
        (profile.weightKg > 0 || profile.heightCm > 0 || profile.age > 0)) {
      final parts = <String>[];
      if (profile.sex != null) parts.add(profile.sex!.label);
      if (profile.age > 0) parts.add('${profile.age}歳');
      if (profile.heightCm > 0) {
        parts.add('身長${profile.heightCm.toStringAsFixed(0)}cm');
      }
      if (profile.weightKg > 0) {
        parts.add('体重${profile.weightKg.toStringAsFixed(1)}kg');
      }
      if (profile.targetWeightKg > 0) {
        parts.add('目標体重${profile.targetWeightKg.toStringAsFixed(1)}kg');
      }
      parts.add('活動量: ${profile.activityLevel.label}');
      buffer.writeln('・プロフィール: ${parts.join(' / ')}');
    }

    if (calorieGoal != null && calorieGoal > 0) {
      final p = proteinGoal?.toStringAsFixed(0) ?? '-';
      final f = fatGoal?.toStringAsFixed(0) ?? '-';
      final c = carbsGoal?.toStringAsFixed(0) ?? '-';
      buffer.writeln(
          '・栄養目標: $calorieGoal kcal/日（P$p g / F$f g / C$c g）');
    }

    if (weekSummary != null && weekSummary.hasAnyData) {
      final s = weekSummary;
      final from = DateFormat('M/d').format(s.rangeStart);
      final to = DateFormat('M/d').format(s.rangeEnd);
      buffer.writeln('・直近7日サマリ（$from〜$to）:');
      if (s.totalFoodCalories > 0) {
        buffer.writeln(
            '  - 平均摂取 ${s.avgDailyCalories.round()} kcal/日、平均タンパク質 ${s.avgDailyProtein.toStringAsFixed(0)} g/日');
      }
      buffer.writeln(
          '  - トレーニング ${s.trainingLogCount} 件 / 運動した日数 ${s.trainingActiveDays} 日（推定消費 ${s.trainingEstimatedKcal.round()} kcal）');
      if (s.weightDeltaKg != null) {
        final sign = s.weightDeltaKg! >= 0 ? '+' : '';
        buffer.writeln(
            '  - 体重変化 $sign${s.weightDeltaKg!.toStringAsFixed(1)} kg');
      }
      buffer.writeln('  - 総合評価: ${s.evaluation.grade}（${s.evaluation.headline}）');
    }

    return buffer.toString();
  }

  /// 会話履歴とユーザーの新しい発話を送り、トレーナーの返答テキストを得る。
  Future<String> send({
    required List<ChatMessage> history,
    required String adviceLevel,
    required String contextSummary,
  }) async {
    final systemPrompt = buildSystemPrompt(
      adviceLevel: adviceLevel,
      contextSummary: contextSummary,
    );

    // 直近 maxHistoryMessages 件のみ送る（コスト抑制）。
    final recent = history.length > maxHistoryMessages
        ? history.sublist(history.length - maxHistoryMessages)
        : history;

    final messages = recent
        .map((m) => {'role': m.role.apiRole, 'text': m.text})
        .toList();

    return AiProxyService.callChat(
      systemPrompt: systemPrompt,
      messages: messages,
      maxTokens: maxTokens,
    );
  }
}
