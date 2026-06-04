/// 当月のAI使用量（Cloud Functions が記帳した円換算コストと追加クレジット）。
class AiUsage {
  /// 当月に消費したAIコスト（円換算、実トークンベース）。
  final double costYen;

  /// 追加パック購入で付与された当月の利用枠（円）。
  final double extraCreditYen;

  const AiUsage({
    this.costYen = 0,
    this.extraCreditYen = 0,
  });

  static const empty = AiUsage();

  /// サブスクに含まれる月次のAI利用枠（円）。
  /// Cloud Functions 側の MONTHLY_INCLUDED_BUDGET_YEN と一致させること。
  static const double monthlyIncludedYen = 1500;

  /// 当月に使える総枠（含む枠 + 追加クレジット）。
  double get allowanceYen => monthlyIncludedYen + extraCreditYen;

  /// 使用率（0.0〜1.0+）。メーター表示用。
  double get usedRatio =>
      allowanceYen <= 0 ? 0 : (costYen / allowanceYen).clamp(0.0, 1.0);

  /// 上限に達しているか。
  bool get isLimitReached => costYen >= allowanceYen;

  /// 残り利用枠（円、下限0）。
  double get remainingYen =>
      (allowanceYen - costYen).clamp(0.0, double.infinity);

  factory AiUsage.fromFirestore(Map<String, dynamic> data) {
    double toDouble(dynamic v) => (v is num) ? v.toDouble() : 0.0;
    return AiUsage(
      costYen: toDouble(data['costYen']),
      extraCreditYen: toDouble(data['extraCreditYen']),
    );
  }
}
