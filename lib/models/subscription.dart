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
  static const annualId = 'premium_annual_25500';

  static const all = [monthlyId, annualId];
}
