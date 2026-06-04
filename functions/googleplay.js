'use strict';

// ── Google Play Developer API によるサブスク検証 & RTDN デコード ────────────────

const { GoogleAuth } = require('google-auth-library');

const SCOPE = 'https://www.googleapis.com/auth/androidpublisher';

let _authClient = null;

function getAuthClient(serviceAccountJson) {
  if (_authClient) return _authClient;
  if (!serviceAccountJson) {
    throw new Error('GOOGLE_PLAY_SA（サービスアカウント）が未設定です。');
  }
  const credentials = typeof serviceAccountJson === 'string'
    ? JSON.parse(serviceAccountJson)
    : serviceAccountJson;
  const auth = new GoogleAuth({ credentials, scopes: [SCOPE] });
  _authClient = auth;
  return _authClient;
}

/// purchases.subscriptions.get を呼び、サブスクの正規状態を返す。
/// 戻り値: { valid, isActive, expiresDateMs, cancelReason, paymentState }
async function verifyGoogleSubscription({
  packageName,
  productId,
  purchaseToken,
  serviceAccountJson,
}) {
  const auth = getAuthClient(serviceAccountJson);
  const token = await auth.getAccessToken();

  const url =
    `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/` +
    `${encodeURIComponent(packageName)}/purchases/subscriptions/` +
    `${encodeURIComponent(productId)}/tokens/${encodeURIComponent(purchaseToken)}`;

  const res = await fetch(url, {
    headers: { Authorization: `Bearer ${token}` },
  });

  if (res.status === 404 || res.status === 410) {
    // トークンが無効、または購入が存在しない。
    return { valid: false, status: res.status };
  }
  if (!res.ok) {
    throw new Error(`Google subscriptions.get HTTP ${res.status}`);
  }

  const data = await res.json();
  const expiresDateMs = Number(data.expiryTimeMillis || 0);
  // paymentState: 0=保留, 1=受領済み, 2=無料トライアル, 3=保留中アップグレード/ダウングレード
  const paymentState =
    data.paymentState != null ? Number(data.paymentState) : null;
  const now = Date.now();
  const isActive =
    expiresDateMs > now && paymentState != null && paymentState !== 0;

  return {
    valid: true,
    isActive,
    expiresDateMs,
    paymentState,
    cancelReason: data.cancelReason != null ? Number(data.cancelReason) : null,
    linkedPurchaseToken: data.linkedPurchaseToken || null,
  };
}

/// Real-time Developer Notifications（Pub/Sub push）の本文を解析する。
function parseGoogleRtdn(body) {
  const message = body && body.message;
  if (!message || !message.data) {
    throw new Error('RTDN メッセージに data がありません。');
  }
  const json = Buffer.from(message.data, 'base64').toString('utf8');
  const payload = JSON.parse(json);

  const sub = payload.subscriptionNotification;
  return {
    packageName: payload.packageName,
    subscription: sub
      ? {
          purchaseToken: sub.purchaseToken,
          subscriptionId: sub.subscriptionId,
          notificationType: sub.notificationType,
        }
      : null,
    test: payload.testNotification != null,
  };
}

module.exports = { verifyGoogleSubscription, parseGoogleRtdn };
