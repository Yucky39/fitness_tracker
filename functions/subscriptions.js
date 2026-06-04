'use strict';

// ── サブスク状態の Firestore 書き込み & 購入→ユーザーの逆引き ───────────────────

const admin = require('firebase-admin');

function db() {
  return admin.firestore();
}

function statusRef(uid) {
  return db().collection('users').doc(uid)
    .collection('subscription').doc('status');
}

/// 購入トークン/オリジナルトランザクションIDは webhook でのユーザー特定に使う。
/// Firestore のドキュメントIDに使えるよう base64url 化してキーにする。
function linkKey(rawKey) {
  return Buffer.from(String(rawKey), 'utf8').toString('base64url');
}

function linkRef(rawKey) {
  return db().collection('purchase_links').doc(linkKey(rawKey));
}

/// 購入キー → uid の逆引きを記録する。
async function recordPurchaseLink(rawKey, uid) {
  if (!rawKey) return;
  await linkRef(rawKey).set(
    { uid, updatedAt: admin.firestore.FieldValue.serverTimestamp() },
    { merge: true },
  );
}

/// 購入キーから uid を取得する。
async function findUidByPurchaseKey(rawKey) {
  if (!rawKey) return null;
  const snap = await linkRef(rawKey).get();
  return snap.exists ? snap.data().uid : null;
}

/// サブスク状態を書き込む（status ドキュメントへ merge）。
async function writeSubscriptionStatus(uid, fields) {
  await statusRef(uid).set(
    {
      ...fields,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
}

/// アカウント削除時にユーザー配下を Admin 権限で完全削除する。
/// subscription サブコレクションはクライアントから削除できないためここで消す。
async function purgeUserData(uid) {
  const userDoc = db().collection('users').doc(uid);

  // subscription サブコレクションを削除
  const subSnap = await userDoc.collection('subscription').get();
  const batch = db().batch();
  for (const doc of subSnap.docs) {
    // 逆引きリンクも削除
    const data = doc.data();
    if (data.originalTransactionId) {
      batch.delete(linkRef(data.originalTransactionId));
    }
    if (data.purchaseToken) {
      batch.delete(linkRef(data.purchaseToken));
    }
    batch.delete(doc.reference);
  }
  if (!subSnap.empty) await batch.commit();
}

module.exports = {
  recordPurchaseLink,
  findUidByPurchaseKey,
  writeSubscriptionStatus,
  purgeUserData,
};
