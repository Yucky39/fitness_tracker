import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_review_access_provider.dart';
import 'settings_provider.dart';
import 'subscription_provider.dart';

/// 全AI機能のゲート判定を一箇所に集約するためのモデル。
///
/// 「AIを使える＝サブスクの価値」を機能ごとにブレさせないため、
/// 写真解析・食事提案を含む全てのAI呼び出しは必ず [resolveAiAccess]
/// （または [aiAccessProvider]）を経由して判定する。
class AiAccess {
  /// AI機能を実行できるか（加入済み、または自前APIキーあり）。
  final bool allowed;

  /// サブスク提供のシステムAI（Cloud Functions プロキシ）を使うか。
  ///
  /// 加入者は APIキーの有無に関わらず常にプロキシ経由（＝APIキー不要で使い放題）。
  /// 非加入者は自前APIキー（BYOK）で直接プロバイダを叩く。
  final bool useSystemAi;

  const AiAccess({required this.allowed, required this.useSystemAi});

  /// ペイウォール（課金導線）を出すべき状態か。
  bool get isPaywalled => !allowed;

  static const denied = AiAccess(allowed: false, useSystemAi: false);
}

/// サブスク状態と現在のAPIキーから、統一的にAIゲートを判定する。
///
/// 全AI機能でこの関数だけを使うことで、
/// 「課金したのに一部のAIが使えない」「機能ごとにゲートがバラバラ」を防ぐ。
AiAccess resolveAiAccess({
  required bool isSubscribed,
  required String apiKey,
}) {
  final hasKey = apiKey.trim().isNotEmpty;
  return AiAccess(
    allowed: isSubscribed || hasKey,
    useSystemAi: isSubscribed,
  );
}

/// UI / プロバイダから直接 watch して使える統一ゲート。
final aiAccessProvider = Provider<AiAccess>((ref) {
  final isSubscribed = ref.watch(isSubscribedProvider);
  final isAppReview = ref.watch(appReviewAccessFutureProvider).value ?? false;
  final apiKey = ref.watch(settingsProvider).currentApiKey;
  return resolveAiAccess(
    isSubscribed: isSubscribed || isAppReview,
    apiKey: apiKey,
  );
});
