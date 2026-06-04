import 'dart:convert';
import 'package:cloud_functions/cloud_functions.dart';

/// サブスク加入済みユーザー向けのAI呼び出しプロキシ。
/// Gemini APIキーはCloud Functions側で管理し、クライアントに露出させない。
class AiProxyService {
  static final _functions =
      FirebaseFunctions.instanceFor(region: 'asia-northeast1');

  // ── テキスト生成 ─────────────────────────────────────────────────────────

  static Future<String> callText({
    required String systemPrompt,
    required String userMessage,
    int maxTokens = 1024,
    String? thinkingLevel,
  }) async {
    final callable = _functions.httpsCallable('geminiProxy');
    final payload = <String, dynamic>{
      'type': 'text',
      'systemPrompt': systemPrompt,
      'userMessage': userMessage,
      'maxTokens': maxTokens,
    };
    if (thinkingLevel != null) {
      payload['thinkingLevel'] = thinkingLevel;
    }
    final result = await callable.call(payload);
    final text = result.data['text'];
    if (text == null || text is! String) {
      throw Exception('AIからの応答が不正です。もう一度試してください。');
    }
    return text;
  }

  // ── 会話（マルチターン） ─────────────────────────────────────────────────

  /// AIトレーナーチャット用。会話履歴を保ったまま生成する。
  /// [messages] は古い順に並んだ `{role: 'user'|'model', text}` の配列。
  static Future<String> callChat({
    required String systemPrompt,
    required List<Map<String, String>> messages,
    int maxTokens = 800,
  }) async {
    final callable = _functions.httpsCallable(
      'geminiProxy',
      options: HttpsCallableOptions(
        timeout: const Duration(seconds: 60),
      ),
    );
    final result = await callable.call({
      'type': 'chat',
      'systemPrompt': systemPrompt,
      'messages': messages,
      'maxTokens': maxTokens,
    });
    final text = result.data['text'];
    if (text == null || text is! String) {
      throw Exception('AIからの応答が不正です。もう一度試してください。');
    }
    return text;
  }

  // ── 画像解析 ─────────────────────────────────────────────────────────────

  static Future<String> callVision({
    required List<int> imageBytes,
    required String mediaType,
    required String prompt,
    int maxTokens = 2048,
  }) async {
    final base64Image = base64Encode(imageBytes);
    final callable = _functions.httpsCallable(
      'geminiProxy',
      options: HttpsCallableOptions(
        timeout: const Duration(seconds: 60),
      ),
    );
    final result = await callable.call({
      'type': 'vision',
      'base64Image': base64Image,
      'mediaType': mediaType,
      'prompt': prompt,
      'maxTokens': maxTokens,
    });
    final text = result.data['text'];
    if (text == null || text is! String) {
      throw Exception('AIからの応答が不正です。もう一度試してください。');
    }
    return text;
  }
}
