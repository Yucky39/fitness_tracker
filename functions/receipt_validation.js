/**
 * App Store / Google Play のレシート（購入トークン）をサーバ側で検証するモジュール。
 *
 * 不正な購入トークンによる無料付与（サブスク有効化・AIクレジット付与）を防ぐ。
 * `activateSubscription` と `addAiCredit` から利用する。
 *
 * 必要なシークレット / 設定（Secret Manager / 環境変数）:
 *   - APPLE_SHARED_SECRET            … App Store Connect の「App用共有シークレット」
 *   - GOOGLE_PLAY_SERVICE_ACCOUNT    … Google Play Developer API 権限を持つ
 *                                      サービスアカウントJSON（文字列まるごと）
 *   - ANDROID_PACKAGE_NAME           … Android の applicationId（パッケージ名）
 *   - RECEIPT_VALIDATION_STRICT      … 'true' で fail-closed（シークレット未設定時も拒否）。
 *                                      移行期は 'false'（既定）で、設定済みのものだけ検証する。
 */

const { defineSecret, defineString } = require('firebase-functions/params');
const { GoogleAuth } = require('google-auth-library');

const appleSharedSecret = defineSecret('APPLE_SHARED_SECRET');
const googlePlayServiceAccount = defineSecret('GOOGLE_PLAY_SERVICE_ACCOUNT');
const androidPackageName = defineString('ANDROID_PACKAGE_NAME', {
  default: 'com.example.fitness_tracker',
});
const receiptValidationStrict = defineString('RECEIPT_VALIDATION_STRICT', {
  default: 'false',
});

/** これらの値を、利用する関数の `secrets` 配列に渡すこと。 */
const receiptSecrets = [appleSharedSecret, googlePlayServiceAccount];

function isStrict() {
  return String(receiptValidationStrict.value()).toLowerCase() === 'true';
}

// ── Apple ────────────────────────────────────────────────────────────────────

/**
 * StoreKit1 のアプリレシート（base64）を verifyReceipt で検証する。
 * 本番エンドポイントを先に叩き、サンドボックスレシート(status 21007)なら切り替える。
 */
async function verifyApple(receiptData, productId) {
  const secret = appleSharedSecret.value();
  if (!secret) {
    if (isStrict()) {
      throw new Error('APPLE_SHARED_SECRET が未設定です。');
    }
    console.warn('APPLE_SHARED_SECRET 未設定のため Apple 検証をスキップしました。');
    return; // 移行期は許可
  }

  const payload = JSON.stringify({
    'receipt-data': receiptData,
    password: secret,
    'exclude-old-transactions': true,
  });

  async function post(url) {
    const res = await fetch(url, { method: 'POST', body: payload });
    return res.json();
  }

  let json = await post('https://buy.itunes.apple.com/verifyReceipt');
  if (json.status === 21007) {
    json = await post('https://sandbox.itunes.apple.com/verifyReceipt');
  }

  if (json.status !== 0) {
    throw new Error(`Apple レシート検証に失敗しました (status ${json.status})。`);
  }

  // productId がレシートに含まれることを確認する。
  const entries = [
    ...(json.receipt?.in_app || []),
    ...(json.latest_receipt_info || []),
  ];
  const matched = entries.some((e) => e.product_id === productId);
  if (!matched) {
    throw new Error('Apple レシートに該当の商品が含まれていません。');
  }
}

// ── Google Play ───────────────────────────────────────────────────────────────

let _cachedAuth;
async function googleAccessToken() {
  const raw = googlePlayServiceAccount.value();
  if (!raw) return null;
  if (!_cachedAuth) {
    _cachedAuth = new GoogleAuth({
      credentials: JSON.parse(raw),
      scopes: ['https://www.googleapis.com/auth/androidpublisher'],
    });
  }
  const client = await _cachedAuth.getClient();
  const token = await client.getAccessToken();
  return typeof token === 'string' ? token : token?.token;
}

/**
 * Google Play Developer API で購入トークンを検証する。
 * [kind] が 'subscription' のときは subscriptionsv2、'product' のときは products を参照。
 */
async function verifyGoogle(kind, productId, purchaseToken) {
  const accessToken = await googleAccessToken();
  if (!accessToken) {
    if (isStrict()) {
      throw new Error('GOOGLE_PLAY_SERVICE_ACCOUNT が未設定です。');
    }
    console.warn(
      'GOOGLE_PLAY_SERVICE_ACCOUNT 未設定のため Google 検証をスキップしました。');
    return; // 移行期は許可
  }

  const pkg = androidPackageName.value();
  const base =
    `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${pkg}/purchases`;
  const url = kind === 'subscription'
    ? `${base}/subscriptionsv2/tokens/${encodeURIComponent(purchaseToken)}`
    : `${base}/products/${encodeURIComponent(productId)}/tokens/${encodeURIComponent(purchaseToken)}`;

  const res = await fetch(url, {
    headers: { Authorization: `Bearer ${accessToken}` },
  });
  if (!res.ok) {
    const text = await res.text();
    throw new Error(`Google 購入検証に失敗しました (${res.status}): ${text}`);
  }
  const data = await res.json();

  if (kind === 'subscription') {
    // subscriptionsv2: subscriptionState で判定。
    const state = data.subscriptionState;
    const ok = state === 'SUBSCRIPTION_STATE_ACTIVE' ||
      state === 'SUBSCRIPTION_STATE_IN_GRACE_PERIOD';
    if (!ok) {
      throw new Error(`サブスクが有効ではありません (${state})。`);
    }
  } else {
    // products: purchaseState 0 = Purchased。
    if (data.purchaseState !== 0) {
      throw new Error('購入が完了していません。');
    }
  }
}

// ── 統一エントリ ───────────────────────────────────────────────────────────────

/**
 * 購入を検証する。失敗時は例外をスロー（呼び出し側で permission-denied に変換）。
 * @param {object} p
 * @param {'ios'|'android'} p.platform
 * @param {string} p.productId
 * @param {string} p.purchaseToken  iOS: アプリレシート(base64) / Android: 購入トークン
 * @param {'subscription'|'product'} p.kind
 */
async function verifyPurchase({ platform, productId, purchaseToken, kind }) {
  if (platform === 'ios') {
    await verifyApple(purchaseToken, productId);
  } else if (platform === 'android') {
    await verifyGoogle(kind, productId, purchaseToken);
  } else if (platform === 'promo') {
    // プロモは別フロー（redeemPromoCode）で検証済み。
    return;
  } else {
    throw new Error(`未対応のプラットフォームです: ${platform}`);
  }
}

module.exports = { verifyPurchase, receiptSecrets };
