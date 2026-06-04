import 'package:cloud_firestore/cloud_firestore.dart';

class SubscriptionStatus {
  final bool isActive;
  final String? productId;
  final DateTime? expiresAt;
  final String? platform;

  const SubscriptionStatus({
    this.isActive = false,
    this.productId,
    this.expiresAt,
    this.platform,
  });

  static const empty = SubscriptionStatus();

  bool get isExpired =>
      expiresAt != null && expiresAt!.isBefore(DateTime.now());

  bool get hasActiveAccess => isActive && !isExpired;

  factory SubscriptionStatus.fromFirestore(Map<String, dynamic> data) {
    DateTime? expires;
    final raw = data['expiresAt'];
    if (raw is Timestamp) {
      expires = raw.toDate();
    } else if (raw is String) {
      expires = DateTime.tryParse(raw);
    }
    return SubscriptionStatus(
      isActive: data['active'] == true,
      productId: data['productId'] as String?,
      expiresAt: expires,
      platform: data['platform'] as String?,
    );
  }
}

// アプリ内課金の商品ID
class SubscriptionProducts {
  static const monthlyId = 'premium_monthly_2500';
  static const annualId = 'premium_annual_25400';

  static const all = [monthlyId, annualId];
}

/// AI追加クレジット（消費型IAP）の商品ID。
/// 当月のAI利用枠が上限に達したとき、追加で購入して使い続けるためのパック。
class AiCreditProducts {
  static const credit500 = 'ai_credit_500';
  static const credit1000 = 'ai_credit_1000';

  static const all = [credit500, credit1000];

  static bool isCredit(String productId) => all.contains(productId);
}
