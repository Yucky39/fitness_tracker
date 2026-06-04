const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { setGlobalOptions } = require('firebase-functions/v2');
const { defineSecret } = require('firebase-functions/params');
const { GoogleGenerativeAI } = require('@google/generative-ai');
const admin = require('firebase-admin');
const { verifyPurchase, receiptSecrets } = require('./receipt_validation');

admin.initializeApp();
setGlobalOptions({ region: 'asia-northeast1' });

const MODEL_ID = 'gemini-3.5-flash';

/** Secret Manager 上の名前と一致させる（firebase functions:secrets:set で登録） */
const geminiApiKey = defineSecret('GEMINI_API_KEY');

// ── AI使用量の計測・予算 ─────────────────────────────────────────────────────
// gemini-3.5-flash（asia-northeast1 / non-global）の単価を円換算して記帳する。
// 為替・単価は変数。サービス運用に合わせてここを更新する。
const USD_TO_JPY = 150;
const INPUT_USD_PER_TOKEN = 1.65 / 1e6; // $1.65 / 1M tokens
const OUTPUT_USD_PER_TOKEN = 9.9 / 1e6; // $9.90 / 1M tokens
const INPUT_YEN_PER_TOKEN = INPUT_USD_PER_TOKEN * USD_TO_JPY;
const OUTPUT_YEN_PER_TOKEN = OUTPUT_USD_PER_TOKEN * USD_TO_JPY;

/**
 * 1ユーザー・1ヶ月あたりにサブスクへ含める（無料で使える）AI利用枠（円）。
 * これを超えると追加課金（消費型IAP）の導線が表示される。
 * サブスク手取りから他インフラ費を差し引いて調整する。
 */
const MONTHLY_INCLUDED_BUDGET_YEN = 1500;

/** 追加クレジット商品ID → 付与する利用枠（円）。手数料を見込み付与額 < 手取りにする。 */
const CREDIT_YEN_BY_PRODUCT = {
  ai_credit_500: 300,
  ai_credit_1000: 650,
};

/** JST基準の `YYYY-MM`。月次の使用量ドキュメントキーに使う。 */
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

/** 当月の利用が予算（含む枠 + 追加クレジット）内かを検証。超過なら resource-exhausted。 */
async function assertWithinBudget(uid) {
  const snap = await usageDocRef(uid, currentMonthKey()).get();
  const data = snap.exists ? snap.data() : {};
  const spent = data.costYen || 0;
  const allowance = MONTHLY_INCLUDED_BUDGET_YEN + (data.extraCreditYen || 0);
  if (spent >= allowance) {
    throw new HttpsError('resource-exhausted', 'AI_LIMIT_REACHED');
  }
}

/** 実トークン数（usageMetadata）から円換算し、当月使用量へ加算記帳する（ベストエフォート）。 */
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
    // 記帳失敗は本処理を妨げない（次回以降で再計上される）。
    console.error('accrueUsage error:', err);
  }
}

// ── 共通: サブスク状態の検証 ─────────────────────────────────────────────────

async function assertSubscribed(uid) {
  const snap = await admin.firestore()
    .collection('users').doc(uid)
    .collection('subscription').doc('status')
    .get();

  if (!snap.exists) throw new HttpsError('permission-denied', 'サブスクリプションが必要です。');

  const data = snap.data();
  if (!data.active) throw new HttpsError('permission-denied', 'サブスクリプションが有効ではありません。');

  const expiresAt = data.expiresAt?.toDate?.() ?? null;
  if (expiresAt && expiresAt < new Date()) {
    throw new HttpsError('permission-denied', 'サブスクリプションの有効期限が切れています。');
  }
}

// ── geminiProxy: AI生成プロキシ ───────────────────────────────────────────────

exports.geminiProxy = onCall(
  {
    secrets: [geminiApiKey],
    timeoutSeconds: 60,
    memory: '256MiB',
  },
  async (request) => {
    if (!request.auth) throw new HttpsError('unauthenticated', 'ログインが必要です。');
    await assertSubscribed(request.auth.uid);
    // 当月の利用枠（含む枠 + 追加クレジット）を超えていれば、生成前にブロックする。
    await assertWithinBudget(request.auth.uid);

    const apiKey = geminiApiKey.value();
    if (!apiKey) throw new HttpsError('internal', 'サーバー設定エラーです。管理者にお問い合わせください。');

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
    } = request.data;

    const genAI = new GoogleGenerativeAI(apiKey);
    const model = genAI.getGenerativeModel({ model: MODEL_ID });

    try {
      let result;
      if (type === 'text') {
        // テキスト生成（栄養アドバイス・トレーニング評価・プラン生成）
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
        // 会話型（マルチターン）。AIトレーナーチャット用。
        // messages は [{ role: 'user' | 'model', text }] の配列で、古い順に並ぶ。
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
        // 画像解析（食事写真）
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

      // 実トークン数を当月使用量へ記帳（ベストエフォート）。
      await accrueUsage(request.auth.uid, result);
      return { text: result.response.text() };
    } catch (err) {
      if (err instanceof HttpsError) throw err;
      console.error('Gemini API error:', err);
      throw new HttpsError('internal', 'AI処理中にエラーが発生しました。もう一度試してください。');
    }
  }
);

// ── activateSubscription: 購入完了後にサブスクをFirestoreへ書き込む ──────────────

exports.activateSubscription = onCall(
  { timeoutSeconds: 30, secrets: receiptSecrets },
  async (request) => {
    if (!request.auth) throw new HttpsError('unauthenticated', 'ログインが必要です。');

    const { productId, purchaseToken, platform } = request.data;
    if (!productId || !purchaseToken || !platform) {
      throw new HttpsError('invalid-argument', '必要なパラメータが不足しています。');
    }

    // ストアのレシート（購入トークン）をサーバ検証する。
    try {
      await verifyPurchase({
        platform, productId, purchaseToken, kind: 'subscription',
      });
    } catch (err) {
      console.error('subscription receipt validation failed:', err);
      throw new HttpsError('permission-denied', '購入の検証に失敗しました。');
    }

    // 有効期限の計算
    const now = new Date();
    const isAnnual = productId.includes('annual');
    const expiresAt = new Date(now);
    if (isAnnual) {
      expiresAt.setFullYear(expiresAt.getFullYear() + 1);
    } else {
      expiresAt.setMonth(expiresAt.getMonth() + 1);
    }

    await admin.firestore()
      .collection('users').doc(request.auth.uid)
      .collection('subscription').doc('status')
      .set({
        active: true,
        productId,
        purchaseToken,
        platform,
        activatedAt: admin.firestore.FieldValue.serverTimestamp(),
        expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
      }, { merge: true });

    return { success: true };
  }
);

// ── addAiCredit: 追加パック（消費型IAP）購入で当月のAI利用枠を増やす ──────────────

exports.addAiCredit = onCall(
  { timeoutSeconds: 30, secrets: receiptSecrets },
  async (request) => {
    if (!request.auth) throw new HttpsError('unauthenticated', 'ログインが必要です。');

    const { productId, purchaseToken, platform } = request.data;
    if (!productId || !purchaseToken || !platform) {
      throw new HttpsError('invalid-argument', '必要なパラメータが不足しています。');
    }

    const creditYen = CREDIT_YEN_BY_PRODUCT[productId];
    if (!creditYen) {
      throw new HttpsError('invalid-argument', '不明な商品IDです。');
    }

    // 消費型IAP（プロダクト）の購入をサーバ検証する。
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

    // purchaseToken をキーに二重付与を防止する（消費型は同一トークンの再通知があり得る）。
    await admin.firestore().runTransaction(async (tx) => {
      const existing = await tx.get(purchaseRef);
      if (existing.exists) {
        return; // 既に付与済み
      }
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
  }
);

// ── redeemPromoCode: プロモコードを適用してサブスクを有効化 ─────────────────────

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

      // コードの存在チェック
      if (!promoSnap.exists) {
        throw new HttpsError('not-found', '無効なコードです。もう一度確認してください。');
      }

      const promo = promoSnap.data();

      // 有効フラグ
      if (!promo.active) {
        throw new HttpsError('failed-precondition', 'このコードは現在使用できません。');
      }

      // コード自体の有効期限
      const promoExpiry = promo.expiresAt?.toDate?.() ?? null;
      if (promoExpiry && promoExpiry < new Date()) {
        throw new HttpsError('failed-precondition', 'このコードの有効期限が切れています。');
      }

      // 使用回数の上限
      if (promo.maxUses != null && (promo.usedCount ?? 0) >= promo.maxUses) {
        throw new HttpsError('resource-exhausted', 'このコードは使用上限に達しました。');
      }

      // ユーザーの使用済みチェック
      const usedCodes = userSnap.exists ? (userSnap.data().usedPromoCodes ?? []) : [];
      if (usedCodes.includes(code)) {
        throw new HttpsError('already-exists', 'このコードは既に使用済みです。');
      }

      // 有効期限の計算（既存サブスクがあれば期間を延長）
      const now = new Date();
      let baseDate = now;
      if (userSnap.exists && userSnap.data().active) {
        const currentExpiry = userSnap.data().expiresAt?.toDate?.() ?? null;
        if (currentExpiry && currentExpiry > now) baseDate = currentExpiry;
      }
      const newExpiry = new Date(baseDate);
      newExpiry.setDate(newExpiry.getDate() + promo.durationDays);

      // プロモの使用回数を更新
      tx.update(promoRef, { usedCount: admin.firestore.FieldValue.increment(1) });

      // サブスクを有効化
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
  }
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
  }
);
