const { onCall, onRequest, HttpsError } = require('firebase-functions/v2/https');
const { setGlobalOptions } = require('firebase-functions/v2');
const { defineSecret, defineString } = require('firebase-functions/params');
const { GoogleGenerativeAI } = require('@google/generative-ai');
const admin = require('firebase-admin');
const {
  verifyPurchase,
  receiptSecrets,
  appleSharedSecret,
  googlePlayServiceAccount,
  androidPackageName,
} = require('./receipt_validation');

admin.initializeApp();
setGlobalOptions({ region: 'asia-northeast1' });

const { parseAppleNotificationV2 } = require('./appstore');
const { verifyGoogleSubscription, parseGoogleRtdn } = require('./googleplay');
const {
  recordPurchaseLink,
  findUidByPurchaseKey,
  writeSubscriptionStatus,
  purgeUserData: purgeUser,
} = require('./subscriptions');

const MODEL_ID = 'gemini-3.5-flash';

const geminiApiKey = defineSecret('GEMINI_API_KEY');

/**
 * App Store 審査用デモアカウント（カンマ区切りメール）。
 * 例: APP_REVIEW_EMAILS=review@example.com
 */
const appReviewEmails = defineString('APP_REVIEW_EMAILS', { default: '' });

// ── AI使用量の計測・予算 ─────────────────────────────────────────────────────
const USD_TO_JPY = 150;
const INPUT_USD_PER_TOKEN = 1.65 / 1e6;
const OUTPUT_USD_PER_TOKEN = 9.9 / 1e6;
const INPUT_YEN_PER_TOKEN = INPUT_USD_PER_TOKEN * USD_TO_JPY;
const OUTPUT_YEN_PER_TOKEN = OUTPUT_USD_PER_TOKEN * USD_TO_JPY;

const MONTHLY_INCLUDED_BUDGET_YEN = 1500;

const CREDIT_YEN_BY_PRODUCT = {
  ai_credit_500: 300,
  ai_credit_1000: 650,
};

function currentMonthKey() {
  const jst = new Date(Date.now() + 9 * 60 * 60 * 1000);
  const y = jst.getUTCFullYear();
  const m = String(jst.getUTCMonth() + 1).padStart(2, '0');
  return `${y}-${m}`;
}

function usageDocRef(uid, monthKey) {
  return admin.firestore()
    .collection('users').doc(uid)
    .collection('ai_usage').doc(monthKey);
}

async function assertWithinBudget(uid) {
  const snap = await usageDocRef(uid, currentMonthKey()).get();
  const data = snap.exists ? snap.data() : {};
  const spent = data.costYen || 0;
  const allowance = MONTHLY_INCLUDED_BUDGET_YEN + (data.extraCreditYen || 0);
  if (spent >= allowance) {
    throw new HttpsError('resource-exhausted', 'AI_LIMIT_REACHED');
  }
}

async function accrueUsage(uid, result) {
  try {
    const meta = result?.response?.usageMetadata || {};
    const inputTokens = meta.promptTokenCount || 0;
    const outputTokens = meta.candidatesTokenCount || 0;
    if (inputTokens === 0 && outputTokens === 0) return;
    const costYen =
      inputTokens * INPUT_YEN_PER_TOKEN + outputTokens * OUTPUT_YEN_PER_TOKEN;
    await usageDocRef(uid, currentMonthKey()).set({
      costYen: admin.firestore.FieldValue.increment(costYen),
      inputTokens: admin.firestore.FieldValue.increment(inputTokens),
      outputTokens: admin.firestore.FieldValue.increment(outputTokens),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
  } catch (err) {
    console.error('accrueUsage error:', err);
  }
}

// ── サブスク検証（審査用バイパス含む） ───────────────────────────────────────

function parseReviewEmailAllowlist() {
  return appReviewEmails
    .value()
    .split(',')
    .map((e) => e.trim().toLowerCase())
    .filter(Boolean);
}

async function isAppReviewAccount(uid) {
  const allowlist = parseReviewEmailAllowlist();
  if (allowlist.length === 0) return false;
  try {
    const user = await admin.auth().getUser(uid);
    const email = user.email?.trim().toLowerCase();
    return Boolean(email && allowlist.includes(email));
  } catch (_) {
    return false;
  }
}

async function assertSubscribed(uid, authToken) {
  if (authToken?.appReview === true) return;
  if (await isAppReviewAccount(uid)) return;

  const snap = await admin.firestore()
    .collection('users').doc(uid)
    .collection('subscription').doc('status')
    .get();

  if (!snap.exists) {
    throw new HttpsError('permission-denied', 'サブスクリプションが必要です。');
  }

  const data = snap.data();
  if (!data.active) {
    throw new HttpsError('permission-denied', 'サブスクリプションが有効ではありません。');
  }

  const expiresAt = data.expiresAt?.toDate?.() ?? null;
  if (expiresAt && expiresAt < new Date()) {
    throw new HttpsError('permission-denied', 'サブスクリプションの有効期限が切れています。');
  }
}

// ── geminiProxy ───────────────────────────────────────────────────────────────

exports.geminiProxy = onCall(
  {
    secrets: [geminiApiKey],
    timeoutSeconds: 60,
    memory: '256MiB',
  },
  async (request) => {
    if (!request.auth) throw new HttpsError('unauthenticated', 'ログインが必要です。');
    await assertSubscribed(request.auth.uid, request.auth.token);
    await assertWithinBudget(request.auth.uid);

    const apiKey = geminiApiKey.value();
    if (!apiKey) {
      throw new HttpsError('internal', 'サーバー設定エラーです。管理者にお問い合わせください。');
    }

    const {
      type,
      systemPrompt,
      userMessage,
      messages,
      base64Image,
      mediaType,
      prompt,
      maxTokens = 1024,
      thinkingLevel,
    } = request.data ?? {};

    const genAI = new GoogleGenerativeAI(apiKey);
    const model = genAI.getGenerativeModel({ model: MODEL_ID });

    try {
      let result;
      if (type === 'text') {
        const generationConfig = { maxOutputTokens: maxTokens };
        if (thinkingLevel) {
          generationConfig.thinkingConfig = { thinkingLevel };
        }
        result = await model.generateContent({
          systemInstruction: systemPrompt,
          contents: [{ role: 'user', parts: [{ text: userMessage }] }],
          generationConfig,
        });
      } else if (type === 'chat') {
        if (!Array.isArray(messages) || messages.length === 0) {
          throw new HttpsError('invalid-argument', 'メッセージが空です。');
        }
        const contents = messages.map((m) => ({
          role: m.role === 'model' ? 'model' : 'user',
          parts: [{ text: typeof m.text === 'string' ? m.text : '' }],
        }));
        result = await model.generateContent({
          systemInstruction: systemPrompt,
          contents,
          generationConfig: { maxOutputTokens: maxTokens },
        });
      } else if (type === 'vision') {
        result = await model.generateContent({
          contents: [{
            role: 'user',
            parts: [
              { inlineData: { mimeType: mediaType, data: base64Image } },
              { text: prompt },
            ],
          }],
          generationConfig: { maxOutputTokens: maxTokens },
        });
      } else {
        throw new HttpsError('invalid-argument', '不正なリクエストタイプです。');
      }

      await accrueUsage(request.auth.uid, result);
      return { text: result.response.text() };
    } catch (err) {
      if (err instanceof HttpsError) throw err;
      console.error('Gemini API error:', err);
      throw new HttpsError('internal', 'AI処理中にエラーが発生しました。もう一度試してください。');
    }
  },
);

// ── activateSubscription ──────────────────────────────────────────────────────

exports.activateSubscription = onCall(
  { timeoutSeconds: 30, secrets: receiptSecrets },
  async (request) => {
    if (!request.auth) throw new HttpsError('unauthenticated', 'ログインが必要です。');

    const uid = request.auth.uid;
    const { productId, purchaseToken, platform } = request.data ?? {};
    if (!productId || !purchaseToken || !platform) {
      throw new HttpsError('invalid-argument', '必要なパラメータが不足しています。');
    }

    try {
      await verifyPurchase({
        platform, productId, purchaseToken, kind: 'subscription',
      });
    } catch (err) {
      console.error('subscription receipt validation failed:', err);
      throw new HttpsError('permission-denied', '購入の検証に失敗しました。');
    }

    const now = new Date();
    const isAnnual = productId.includes('annual');
    const expiresAt = new Date(now);
    if (isAnnual) {
      expiresAt.setFullYear(expiresAt.getFullYear() + 1);
    } else {
      expiresAt.setMonth(expiresAt.getMonth() + 1);
    }

    await writeSubscriptionStatus(uid, {
      active: true,
      productId,
      purchaseToken,
      platform,
      activatedAt: admin.firestore.FieldValue.serverTimestamp(),
      expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
    });

    await recordPurchaseLink(purchaseToken, uid);

    return { success: true, expiresAt: expiresAt.toISOString() };
  },
);

// ── addAiCredit ─────────────────────────────────────────────────────────────

exports.addAiCredit = onCall(
  { timeoutSeconds: 30, secrets: receiptSecrets },
  async (request) => {
    if (!request.auth) throw new HttpsError('unauthenticated', 'ログインが必要です。');

    const { productId, purchaseToken, platform } = request.data ?? {};
    if (!productId || !purchaseToken || !platform) {
      throw new HttpsError('invalid-argument', '必要なパラメータが不足しています。');
    }

    const creditYen = CREDIT_YEN_BY_PRODUCT[productId];
    if (!creditYen) {
      throw new HttpsError('invalid-argument', '不明な商品IDです。');
    }

    try {
      await verifyPurchase({
        platform, productId, purchaseToken, kind: 'product',
      });
    } catch (err) {
      console.error('credit receipt validation failed:', err);
      throw new HttpsError('permission-denied', '購入の検証に失敗しました。');
    }

    const uid = request.auth.uid;
    const purchaseRef = admin.firestore()
      .collection('ai_credit_purchases').doc(purchaseToken);
    const usageRef = usageDocRef(uid, currentMonthKey());

    await admin.firestore().runTransaction(async (tx) => {
      const existing = await tx.get(purchaseRef);
      if (existing.exists) return;
      tx.set(purchaseRef, {
        uid,
        productId,
        platform,
        creditYen,
        monthKey: currentMonthKey(),
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      tx.set(usageRef, {
        extraCreditYen: admin.firestore.FieldValue.increment(creditYen),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
    });

    return { success: true, creditYen };
  },
);

// ── redeemPromoCode ───────────────────────────────────────────────────────────

exports.redeemPromoCode = onCall(
  { timeoutSeconds: 30 },
  async (request) => {
    if (!request.auth) throw new HttpsError('unauthenticated', 'ログインが必要です。');

    const code = (request.data.code ?? '').trim().toUpperCase();
    if (!code) throw new HttpsError('invalid-argument', 'コードを入力してください。');

    const promoRef = admin.firestore().collection('promo_codes').doc(code);
    const userSubRef = admin.firestore()
      .collection('users').doc(request.auth.uid)
      .collection('subscription').doc('status');

    const result = await admin.firestore().runTransaction(async (tx) => {
      const [promoSnap, userSnap] = await Promise.all([
        tx.get(promoRef),
        tx.get(userSubRef),
      ]);

      if (!promoSnap.exists) {
        throw new HttpsError('not-found', '無効なコードです。もう一度確認してください。');
      }

      const promo = promoSnap.data();

      if (!promo.active) {
        throw new HttpsError('failed-precondition', 'このコードは現在使用できません。');
      }

      const promoExpiry = promo.expiresAt?.toDate?.() ?? null;
      if (promoExpiry && promoExpiry < new Date()) {
        throw new HttpsError('failed-precondition', 'このコードの有効期限が切れています。');
      }

      if (promo.maxUses != null && (promo.usedCount ?? 0) >= promo.maxUses) {
        throw new HttpsError('resource-exhausted', 'このコードは使用上限に達しました。');
      }

      const usedCodes = userSnap.exists ? (userSnap.data().usedPromoCodes ?? []) : [];
      if (usedCodes.includes(code)) {
        throw new HttpsError('already-exists', 'このコードは既に使用済みです。');
      }

      const now = new Date();
      let baseDate = now;
      if (userSnap.exists && userSnap.data().active) {
        const currentExpiry = userSnap.data().expiresAt?.toDate?.() ?? null;
        if (currentExpiry && currentExpiry > now) baseDate = currentExpiry;
      }
      const newExpiry = new Date(baseDate);
      newExpiry.setDate(newExpiry.getDate() + promo.durationDays);

      tx.update(promoRef, { usedCount: admin.firestore.FieldValue.increment(1) });

      tx.set(userSubRef, {
        active: true,
        productId: `promo_${code}`,
        platform: 'promo',
        promoCode: code,
        activatedAt: admin.firestore.FieldValue.serverTimestamp(),
        expiresAt: admin.firestore.Timestamp.fromDate(newExpiry),
        usedPromoCodes: admin.firestore.FieldValue.arrayUnion(code),
      }, { merge: true });

      return { durationDays: promo.durationDays, expiresAt: newExpiry.toISOString() };
    });

    return { success: true, ...result };
  },
);

exports.checkSubscription = onCall(
  { timeoutSeconds: 10 },
  async (request) => {
    if (!request.auth) throw new HttpsError('unauthenticated', 'ログインが必要です。');

    const snap = await admin.firestore()
      .collection('users').doc(request.auth.uid)
      .collection('subscription').doc('status')
      .get();

    if (!snap.exists) return { active: false };

    const data = snap.data();
    const expiresAt = data.expiresAt?.toDate?.() ?? null;
    const isExpired = expiresAt ? expiresAt < new Date() : false;

    return {
      active: data.active === true && !isExpired,
      productId: data.productId ?? null,
      expiresAt: expiresAt?.toISOString() ?? null,
    };
  },
);

// ── appleNotifications ────────────────────────────────────────────────────────

exports.appleNotifications = onRequest(
  { timeoutSeconds: 30, secrets: [appleSharedSecret] },
  async (req, res) => {
    if (req.method !== 'POST') {
      res.status(405).send('Method Not Allowed');
      return;
    }
    try {
      const signedPayload = req.body && req.body.signedPayload;
      if (!signedPayload) {
        res.status(400).send('signedPayload がありません。');
        return;
      }

      const note = parseAppleNotificationV2(signedPayload);
      const uid = await findUidByPurchaseKey(note.originalTransactionId);

      if (uid) {
        await writeSubscriptionStatus(uid, {
          active: note.isActive,
          expiresAt: note.expiresDateMs > 0
            ? admin.firestore.Timestamp.fromMillis(note.expiresDateMs)
            : null,
          lastNotificationType: note.notificationType,
          autoRenewStatus: note.autoRenewStatus,
        });
      } else {
        console.warn('Apple通知: 該当ユーザーが見つかりません',
          note.originalTransactionId);
      }

      res.status(200).send('OK');
    } catch (err) {
      console.error('Apple通知の処理エラー:', err);
      res.status(200).send('OK');
    }
  },
);

// ── googleNotifications ───────────────────────────────────────────────────────

exports.googleNotifications = onRequest(
  { timeoutSeconds: 30, secrets: [googlePlayServiceAccount] },
  async (req, res) => {
    if (req.method !== 'POST') {
      res.status(405).send('Method Not Allowed');
      return;
    }
    try {
      const rtdn = parseGoogleRtdn(req.body);
      if (rtdn.test || !rtdn.subscription) {
        res.status(200).send('OK');
        return;
      }

      const { purchaseToken, subscriptionId } = rtdn.subscription;
      const uid = await findUidByPurchaseKey(purchaseToken);

      if (uid) {
        const result = await verifyGoogleSubscription({
          packageName: rtdn.packageName || androidPackageName.value(),
          productId: subscriptionId,
          purchaseToken,
          serviceAccountJson: googlePlayServiceAccount.value(),
        });
        await writeSubscriptionStatus(uid, {
          active: result.valid ? result.isActive : false,
          expiresAt: result.expiresDateMs > 0
            ? admin.firestore.Timestamp.fromMillis(result.expiresDateMs)
            : null,
          lastNotificationType: rtdn.subscription.notificationType,
        });
      } else {
        console.warn('Google通知: 該当ユーザーが見つかりません', purchaseToken);
      }

      res.status(200).send('OK');
    } catch (err) {
      console.error('Google通知の処理エラー:', err);
      res.status(200).send('OK');
    }
  },
);

// ── purgeUserData ─────────────────────────────────────────────────────────────

exports.purgeUserData = onCall(
  { timeoutSeconds: 60 },
  async (request) => {
    if (!request.auth) throw new HttpsError('unauthenticated', 'ログインが必要です。');
    await purgeUser(request.auth.uid);
    return { success: true };
  },
);
