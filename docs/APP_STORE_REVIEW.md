# App Store 審査対応メモ

## デモアカウント（登録済み）

| 項目 | 値 |
|------|-----|
| Email | `review@example.com` |
| Password | `Review1234` |

App Store Connect → **App Review Information** に上記をそのまま入力する。

---

## 1. Guideline 2.1(a) — 食事AIの検証

審査員は **API キー不要**。以下の Firebase 設定を完了してからビルドを提出すること。

### A. カスタムクレーム（推奨・クライアントの AI ゲートも通過）

```bash
cd functions
# サービスアカウント JSON のパスを指定
export GOOGLE_APPLICATION_CREDENTIALS=/path/to/serviceAccountKey.json
node scripts/grant_app_review.js review@example.com
```

`review@example.com` が Firebase Auth に存在すること（アプリから一度サインアップ済み、またはコンソールで作成）。

付与後、そのアカウントで **ログアウト → 再ログイン**（トークン更新）。

### B. サーバー許可リスト（`geminiProxy`）

`functions/.env` または Firebase コンソール:

```
APP_REVIEW_EMAILS=review@example.com
```

```bash
cd functions && firebase deploy --only functions:geminiProxy
```

A と B の **両方** を行うと確実（クライアントは A、サーバーは A または B）。

### App Review Information → Notes（コピペ用）

```
Demo account (use credentials in Username/Password fields above):
Email: review@example.com
Password: Review1234

- Premium AI is enabled for this account on our server. No separate API key is required.
- Meal photo analysis: open the app → Meal tab → camera icon → pick or take a food photo → run analysis.

Sources (Guideline 1.4.1):
Profile icon (top-right) → "FAQ / Disclaimer" → "Sources and references" → tap any row to open the link in the browser.

Account deletion (Guideline 5.1.1):
Profile icon → scroll to "Account" → "アカウント削除" (Delete account and all data) → enter password Review1234 → confirm deletion.
```

---

## 2. Guideline 5.1.1(v) — アカウント削除

1. 右上プロフィールアイコン → ドロワー
2. **アカウント** → **アカウント削除**
3. パスワード `Review1234` で確認 → 完全削除

**注意:** 削除テスト後は審査用アカウントを Firebase Auth で再作成し、`grant_app_review.js` を再実行すること。

**再提出時:** 上記フローの実機画面録画を Notes に添付。

---

## 3. Guideline 1.4.1 — 出典

プロフィール → **FAQ / Disclaimer** → **Sources and references**（各項目タップで Safari 等で開く）

---

## 提出前チェックリスト

- [x] Firebase Auth に `review@example.com` が存在（uid: `ORs2ifmdtvfYC0kyZhkcCZhUFrc2`）
- [x] `appReview: true` カスタムクレーム付与済み（2026-06-03）
- [x] `APP_REVIEW_EMAILS=review@example.com` + `geminiProxy` デプロイ済み（asia-northeast1）
- [ ] 審査アカウントで **ログアウト → 再ログイン**（トークン反映）
- [ ] Firebase Auth に `review@example.com` / `Review1234` でログインできる
- [ ] 審査アカウントでログアウト→再ログイン後、食事写真解析が動く
- [ ] Connect にユーザー名・パスワード・英語 Notes を貼付
- [ ] 出典リンクがタップで開く（新ビルド）
- [ ] アカウント削除の画面録画を Notes に添付（または再作成手順を Notes に記載）

---

## 審査後

- 必要なら `review@example.com` の `appReview` クレームを削除
- `APP_REVIEW_EMAILS` からメールを外すか、Functions を再デプロイ
