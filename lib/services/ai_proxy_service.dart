import 'dart:convert';
import 'package:cloud_functions/cloud_functions.dart';

import 'ai_exceptions.dart';

/// サブスク加入済みユーザー向けのAI呼び出しプロキシ。
/// Gemini APIキーはCloud Functions側で管理し、クライアントに露出させない。
class AiProxyService {
  static final _functions =
      FirebaseFunctions.instanceFor(region: 'asia-northeast1');

  /// 共通の呼び出し。`geminiProxy` の `resource-exhausted`（利用枠の上限）を
  /// [AiUsageLimitException] に変換し、全AI機能で統一的に扱えるようにする。
  static Future<String> _invoke(
    Map<String, dynamic> payload, {
    Duration? timeout,
  }) async {
    final callable = _functions.httpsCallable(
      'geminiProxy',
      options: timeout != null
          ? HttpsCallableOptions(timeout: timeout)
          : null,
    );
    try {
      final result = await callable.call(payload);
      final text = result.data['text'];
      if (text == null || text is! String) {
        throw Exception('AIからの応答が不正です。もう一度試してください。');
      }
      return text;
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'resource-exhausted') {
        throw const AiUsageLimitException();
      }
      throw Exception(e.message ?? 'AI処理中にエラーが発生しました。もう一度試してください。');
    }
  }

  // ── テキスト生成 ─────────────────────────────────────────────────────────

  static Future<String> callText({
    required String systemPrompt,
    required String userMessage,
    int maxTokens = 1024,
    String? thinkingLevel,
  }) {
    final payload = <String, dynamic>{
      'type': 'text',
      'systemPrompt': systemPrompt,
      'userMessage': userMessage,
      'maxTokens': maxTokens,
    };
    if (thinkingLevel != null) {
      payload['thinkingLevel'] = thinkingLevel;
    }
    return _invoke(payload);
  }

  // ── 会話（マルチターン） ─────────────────────────────────────────────────

  /// AIトレーナーチャット用。会話履歴を保ったまま生成する。
  /// [messages] は古い順に並んだ `{role: 'user'|'model', text}` の配列。
  static Future<String> callChat({
    required String systemPrompt,
    required List<Map<String, String>> messages,
    int maxTokens = 800,
  }) {
    return _invoke(
      {
        'type': 'chat',
        'systemPrompt': systemPrompt,
        'messages': messages,
        'maxTokens': maxTokens,
      },
      timeout: const Duration(seconds: 60),
    );
  }

  // ── 画像解析 ─────────────────────────────────────────────────────────────

  static Future<String> callVision({
    required List<int> imageBytes,
    required String mediaType,
    required String prompt,
    int maxTokens = 2048,
  }) {
    final base64Image = base64Encode(imageBytes);
    return _invoke(
      {
        'type': 'vision',
        'base64Image': base64Image,
        'mediaType': mediaType,
        'prompt': prompt,
        'maxTokens': maxTokens,
      },
      timeout: const Duration(seconds: 60),
    );
  }
}
