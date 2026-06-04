'use strict';

// ── Apple App Store のレシート検証 & 通知デコード ───────────────────────────────
//
// activateSubscription では verifyReceipt エンドポイントでレシートを検証する。
// （StoreKit の serverVerificationData = base64 のアプリレシート）
// 本番→サンドボックスのフォールバック（status 21007）に対応する。

const PROD_URL = 'https://buy.itunes.apple.com/verifyReceipt';
const SANDBOX_URL = 'https://sandbox.itunes.apple.com/verifyReceipt';

async function callVerifyReceipt(url, receiptData, sharedSecret) {
  const res = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      'receipt-data': receiptData,
      password: sharedSecret,
      'exclude-old-transactions': true,
    }),
  });
  if (!res.ok) {
    throw new Error(`verifyReceipt HTTP ${res.status}`);
  }
  return res.json();
}

/// レシートを検証し、サブスクの正規状態を返す。
/// 戻り値: { valid, productId, originalTransactionId, expiresDateMs, isActive, environment }
async function verifyAppleReceipt(receiptData, sharedSecret) {
  if (!sharedSecret) {
    throw new Error('APPLE_SHARED_SECRET が未設定です。');
  }

  let body = await callVerifyReceipt(PROD_URL, receiptData, sharedSecret);

  // 21007 = サンドボックスのレシートを本番に送った場合。サンドボックスへ再送。
  if (body.status === 21007) {
    body = await callVerifyReceipt(SANDBOX_URL, receiptData, sharedSecret);
  }

  if (body.status !== 0) {
    return { valid: false, status: body.status };
  }

  const environment = body.environment || 'Production';
  const infos = Array.isArray(body.latest_receipt_info)
    ? body.latest_receipt_info
    : [];
  if (infos.length === 0) {
    return { valid: false, status: body.status, environment };
  }

  // 最も新しい有効期限のトランザクションを採用。
  let latest = null;
  for (const info of infos) {
    const ms = Number(info.expires_date_ms || 0);
    if (!latest || ms > Number(latest.expires_date_ms || 0)) latest = info;
  }
  if (!latest) return { valid: false, status: body.status, environment };

  const expiresDateMs = Number(latest.expires_date_ms || 0);
  const cancellationMs = Number(latest.cancellation_date_ms || 0);
  const now = Date.now();
  const isActive = cancellationMs === 0 && expiresDateMs > now;

  return {
    valid: true,
    environment,
    productId: latest.product_id,
    originalTransactionId: latest.original_transaction_id,
    expiresDateMs,
    cancellationMs,
    isActive,
  };
}

// ── App Store Server Notifications V2（JWS）のデコード ─────────────────────────
//
// 注: 本番運用では x5c 証明書チェーンの署名検証を加えることを推奨。
// ここではペイロード（Apple 署名済み）をデコードしてルーティングと状態反映に用いる。

function decodeJwsPayload(jws) {
  if (typeof jws !== 'string') return null;
  const parts = jws.split('.');
  if (parts.length !== 3) return null;
  const json = Buffer.from(parts[1], 'base64url').toString('utf8');
  return JSON.parse(json);
}

/// signedPayload を解析して正規化した通知情報を返す。
function parseAppleNotificationV2(signedPayload) {
  const payload = decodeJwsPayload(signedPayload);
  if (!payload) throw new Error('Apple 通知の signedPayload を解析できません。');

  const data = payload.data || {};
  const tx = data.signedTransactionInfo
    ? decodeJwsPayload(data.signedTransactionInfo)
    : null;
  const renewal = data.signedRenewalInfo
    ? decodeJwsPayload(data.signedRenewalInfo)
    : null;

  const expiresDateMs = tx ? Number(tx.expiresDate || 0) : 0;
  const revocationMs = tx ? Number(tx.revocationDate || 0) : 0;
  const now = Date.now();

  // 通知種別から有効/無効を判定。REFUND / EXPIRED / REVOKE は無効化。
  const type = payload.notificationType;
  const deactivating = ['EXPIRED', 'REFUND', 'REVOKE', 'GRACE_PERIOD_EXPIRED']
    .includes(type);
  const isActive = !deactivating && revocationMs === 0 && expiresDateMs > now;

  return {
    notificationType: type,
    subtype: payload.subtype,
    environment: data.environment,
    productId: tx ? tx.productId : null,
    originalTransactionId: tx ? tx.originalTransactionId : null,
    expiresDateMs,
    revocationMs,
    autoRenewStatus: renewal ? renewal.autoRenewStatus : null,
    isActive,
  };
}

module.exports = { verifyAppleReceipt, parseAppleNotificationV2 };
