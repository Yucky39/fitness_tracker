# AI API コスト防御（geminiProxy）

Cloud Functions `geminiProxy`（`functions/index.js`）でサブスクユーザーの Gemini 利用を制限する。

## 環境変数（Firebase Functions params / `.env`）

| 変数 | デフォルト | 説明 |
|------|-----------|------|
| `AI_DAILY_TEXT_LIMIT` | 40 | 1ユーザー・1日あたりのテキスト系呼び出し上限 |
| `AI_DAILY_VISION_LIMIT` | 12 | 食事写真など vision の日次上限 |
| `AI_MIN_INTERVAL_MS` | 2500 | 連続リクエストの最小間隔（ミリ秒） |
| `GEMINI_MODEL` | gemini-3.5-flash | 使用モデル |

旧 `AI_DAILY_LIMIT` は廃止。既存の `ai_usage` ドキュメントに `count` のみある場合は `textCount` として読み取る。

## 用途別 maxOutputTokens 上限

クライアントは `purpose` を送る（`lib/services/ai_proxy_purpose.dart`）。サーバーは要求値と用途上限の小さい方を採用する。

| purpose | 上限 |
|---------|------|
| coach | 768 |
| nutrition | 1024 |
| training_advice | 2048 |
| training_plan | 4096 |
| meal_suggestion | 4096 |
| review | 2048 |
| stretch | 1024 |
| body_progress | 768 |
| vision | 2048 |
| default | 1024 |

絶対上限は 8192 トークン。プロンプト合計 24000 文字、画像 base64 約 9MB。

## クォータの加算タイミング

- 呼び出し直前に Firestore `users/{uid}/ai_usage/{YYYY-MM-DD}` で `textCount` / `visionCount` を加算
- Gemini 失敗・入力検証失敗時は `refundAiQuota` で 1 件返却
- 日次上限・連打は消費前に `resource-exhausted` で拒否

## デプロイ

```bash
cd functions && npm install && firebase deploy --only functions:geminiProxy
```

全 Functions を更新する場合は `firebase deploy --only functions`。
