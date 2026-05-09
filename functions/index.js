const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { setGlobalOptions } = require('firebase-functions/v2');
const { GoogleGenerativeAI } = require('@google/generative-ai');
const admin = require('firebase-admin');

admin.initializeApp();
setGlobalOptions({ region: 'asia-northeast1' });

const MODEL_ID = 'gemini-3-flash-preview';

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
  { timeoutSeconds: 60, memory: '256MiB' },
  async (request) => {
    if (!request.auth) throw new HttpsError('unauthenticated', 'ログインが必要です。');
    await assertSubscribed(request.auth.uid);

    const apiKey = process.env.GEMINI_API_KEY;
    if (!apiKey) throw new HttpsError('internal', 'サーバー設定エラーです。管理者にお問い合わせください。');

    const { type, systemPrompt, userMessage, base64Image, mediaType, prompt, maxTokens = 1024 } = request.data;

    const genAI = new GoogleGenerativeAI(apiKey);
    const model = genAI.getGenerativeModel({ model: MODEL_ID });

    try {
      if (type === 'text') {
        // テキスト生成（栄養アドバイス・トレーニング評価・プラン生成）
        const result = await model.generateContent({
          systemInstruction: systemPrompt,
          contents: [{ role: 'user', parts: [{ text: userMessage }] }],
          generationConfig: { maxOutputTokens: maxTokens },
        });
        return { text: result.response.text() };

      } else if (type === 'vision') {
        // 画像解析（食事写真）
        const result = await model.generateContent({
          contents: [{
            role: 'user',
            parts: [
              { inlineData: { mimeType: mediaType, data: base64Image } },
              { text: prompt },
            ],
          }],
          generationConfig: { maxOutputTokens: maxTokens },
        });
        return { text: result.response.text() };

      } else {
        throw new HttpsError('invalid-argument', '不正なリクエストタイプです。');
      }
    } catch (err) {
      if (err instanceof HttpsError) throw err;
      console.error('Gemini API error:', err);
      throw new HttpsError('internal', 'AI処理中にエラーが発生しました。もう一度試してください。');
    }
  }
);

// ── activateSubscription: 購入完了後にサブスクをFirestoreへ書き込む ──────────────

exports.activateSubscription = onCall(
  { timeoutSeconds: 30 },
  async (request) => {
    if (!request.auth) throw new HttpsError('unauthenticated', 'ログインが必要です。');

    const { productId, purchaseToken, platform } = request.data;
    if (!productId || !purchaseToken || !platform) {
      throw new HttpsError('invalid-argument', '必要なパラメータが不足しています。');
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

// ── checkSubscription: サブスク状態の確認 ─────────────────────────────────────

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
