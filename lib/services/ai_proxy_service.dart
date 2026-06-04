import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';

import 'ai_exceptions.dart';
import 'ai_proxy_purpose.dart';

/// サブスク加入者向けのAI呼び出しプロキシ。
/// Gemini APIキーはCloud Functions側で管理し、クライアントに露出させない。
class AiProxyService {
  static final _functions =
      FirebaseFunctions.instanceFor(region: 'asia-northeast1');

  /// サーバーが受け付ける base64 画像の最大長（functions/index.js と一致）。
  static const maxImageBase64Length = 9 * 1024 * 1024;

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

  static Future<String> callText({
    required String systemPrompt,
    required String userMessage,
    int maxTokens = 1024,
    String? thinkingLevel,
    AiProxyPurpose purpose = AiProxyPurpose.general,
  }) {
    final payload = <String, dynamic>{
      'type': 'text',
      'purpose': purpose.key,
      'systemPrompt': systemPrompt,
      'userMessage': userMessage,
      'maxTokens': maxTokens,
    };
    if (thinkingLevel != null) {
      payload['thinkingLevel'] = thinkingLevel;
    }
    return _invoke(payload);
  }

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

  static Future<String> callVision({
    required List<int> imageBytes,
    required String mediaType,
    required String prompt,
    int maxTokens = 2048,
    AiProxyPurpose purpose = AiProxyPurpose.vision,
  }) {
    final base64Image = base64Encode(imageBytes);
    if (base64Image.length > maxImageBase64Length) {
      throw Exception(
        '画像が大きすぎます。別の写真を選ぶか、解像度を下げてください。',
      );
    }
    return _invoke(
      {
        'type': 'vision',
        'purpose': purpose.key,
        'base64Image': base64Image,
        'mediaType': mediaType,
        'prompt': prompt,
        'maxTokens': maxTokens,
      },
      timeout: const Duration(seconds: 60),
    );
  }
}
