/// 当月のAI利用枠の上限に達したときにスローされる例外。
///
/// `geminiProxy` が `resource-exhausted` を返したケースを、UIで分かりやすく扱える
/// 型に変換するために [AiProxyService] が送出する。各プロバイダの
/// `e.toString()` 経由でもユーザー向けメッセージがそのまま表示される。
class AiUsageLimitException implements Exception {
  /// 画面に表示するユーザー向けメッセージ（追加パック導線の判定にも使う）。
  static const String userMessage = '今月のAI利用枠の上限に達しました。追加パックで続けられます。';

  final String message;
  const AiUsageLimitException([this.message = userMessage]);

  @override
  String toString() => message;

  /// 任意のエラー（例外オブジェクト or 文字列化済みメッセージ）が
  /// 利用枠の上限エラーかどうかを判定する。
  static bool isLimit(Object? error) {
    if (error is AiUsageLimitException) return true;
    return (error?.toString() ?? '').contains(userMessage);
  }
}
