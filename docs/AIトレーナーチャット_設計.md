# AIトレーナーチャット機能 設計ドキュメント

最終更新: 2026-06-04

## 1. 目的とコンセプト

トレーニング・食事・日常のルーティンなど、**現在のアプリ機能の枠を越えた相談**を、AIトレーナーと対話形式で行えるチャット機能を追加する。

現状のAI機能（栄養アドバイス・トレーニング評価・食事提案・プラン生成）はすべて「こちらから1回投げて、1回返ってくる」一方通行であり、ユーザーが「なぜ？」「もっと軽くしたい」「膝が痛い」と**続けて聞き返す導線がない**。チャットはこの弱点を補完し、「**あなたのデータを知っているパーソナルトレーナー**」という体験を作る。

汎用チャットボットとの差別化の肝は、**ユーザー自身の記録（トレーニング負荷・体重推移・食事傾向・睡眠）を要約して文脈注入**する点にある。

## 2. スコープとフェーズ

| フェーズ | 内容 | 状態 |
|---|---|---|
| **1. 設計** | 本ドキュメント | ✅ 完了 |
| **2. MVP（課金=サブスク前提）** | チャット本体・マルチターン・要約文脈注入・安全ガードレール・返答長キャップ。サブスク有効ユーザーのみ利用可（§5） | ✅ 実装済み |
| **3. 計測・追加課金** | トークン使用量の計測・月次上限・上限到達時の追加課金（消費型IAP）導線（§6） | ✅ 実装済み |

MVP（フェーズ2）では「サブスク有効なら使い放題（ただしレート制限あり）」とし、厳密な従量計測と追加課金はフェーズ3で載せる。**ただし計測を後付けしやすいよう、MVP時点で全AI呼び出しを `geminiProxy` の単一チョークポイントに通す設計**にしておく。

## 3. 現状アーキテクチャ（前提の整理）

- **AI呼び出し基盤**
  - `lib/services/ai_proxy_service.dart` … サブスク経由のプロキシ呼び出し（`callText` / `callVision`）。Gemini APIキーはサーバ側（Cloud Functions / Secret Manager）で管理しクライアントに露出しない。
  - `functions/index.js` の `geminiProxy` … `assertSubscribed(uid)` でサブスク検証後、`gemini-3.5-flash` で生成。**現状は単一ユーザーメッセージのみ対応で、マルチターン（会話履歴）は未対応。**
  - 各サービス（`training_advice_service` 等）はBYOK（ユーザー自前APIキー）で各プロバイダを直叩きする経路も持つ。**サービスアウト時にBYOKは廃止し、全面プロキシに寄せる方針。**
- **サブスク基盤**
  - 商品ID: `premium_monthly_2500`（月額2,500円） / `premium_annual_25400`（年額25,400円）。`lib/models/subscription.dart`。
  - `subscription_provider.dart` の `isSubscribedProvider` で有効判定。`functions/index.js` に `activateSubscription` / `redeemPromoCode` / `checkSubscription`。
  - Firestore: `users/{uid}/subscription/status`（`active`, `productId`, `expiresAt`, `platform`）。
- **設定**
  - `settings_provider.dart` … プロバイダ・モデル選択、アドバイス口調（`strict` / `normal` / `gentle`）、BYOKキー。
- **UIパターン**
  - Service（ステートレス、プロンプト組立 + API呼び出し） → Notifier（`StateNotifierProvider`、状態管理 + `SharedPreferences` キャッシュ） → Screen の3層。
  - サブスク誘導は `lib/widgets/paywall_sheet.dart`。

## 4. コスト試算（設計の土台）

### 4.1 料金前提（2026-06時点）

- モデル: `gemini-3.5-flash`、リージョン `asia-northeast1`（= non-global）
  - 入力 **$1.65 / 1M tokens**
  - 出力 **$9.90 / 1M tokens**（入力の6倍。**出力長の制御が最重要**）
  - キャッシュ入力 約 **$0.165 / 1M tokens**（入力の90%off）
- 為替: 1 USD ≈ 150円（変数。下振れ前提で見積もる）

### 4.2 収益構造

| 項目 | 月額 | 年額（月割） |
|---|---|---|
| 表示価格 | 2,500円 | 約2,083円 |
| ストア手数料15%後の手取り（Small Business Program等） | 約2,125円 | 約1,771円 |
| ストア手数料30%後の手取り（保守的） | 1,750円 | 約1,458円 |

- **AI＋インフラ負担の上限を1ユーザーあたり1,500円/月**と置く（手数料40%相当を見込んだ保守的ライン）。これを下回ればシステム利益が出る。
- **年額ユーザーの方が月割手取りが薄い**ため、上限・allowanceは年額基準（厳しい方）で引く。

### 4.3 1会話あたりの試算

1往復（ユーザー発話 + AI返答）を「ターン」とし、データ文脈注入ありで見積もる:

- システムプロンプト + データ文脈（週間負荷・体重推移・食事要約・睡眠）≈ **1,500 tokens**（毎ターン送信、キャッシュ対象）
- ユーザー発話 ≈ 120 tokens / AI返答 ≈ 500 tokens
- マルチターンは履歴を毎ターン再送するため入力が累積する

**8ターンの会話**（履歴を最後まで再送）:
- 累積入力 ≈ 30,300 tokens → $0.050
- 出力 ≈ 4,000 tokens → $0.040
- **合計 ≈ $0.09 ≒ 約13.4円 / 8ターン会話**

### 4.4 月あたりコスト

| 利用者像 | 会話数/月 | AIコスト/月 | 予算1,500円比 |
|---|---|---|---|
| ライト | 5 | 約67円 | 4% |
| 標準 | 20 | 約270円 | 18% |
| ヘビー | 60 | 約800円 | 53% |
| 乱用 | 200 | 約2,700円 | **超過** |

→ **標準利用なら予算の2割以下**。リスクは平均ユーザーではなく**テール（乱用・パワーユーザー）**にある。これをフェーズ3の計測＋上限＋追加課金で構造的に潰す。

## 5. MVP設計（フェーズ2）

### 5.1 方針

- サブスク有効ユーザー（`isSubscribedProvider == true`）のみ利用可。無効ユーザーには `paywall_sheet` を提示。
- 全呼び出しを `geminiProxy` に通す（BYOK経路は作らない）。
- コスト構造に効く制御を**最初から**入れる:
  1. **返答長キャップ**（`maxTokens` を 700〜800 程度に）← 最も効く
  2. **データ文脈は要約のみ**注入（生ログは渡さない）
  3. **会話履歴の上限**（直近Nターンに制限、超過分は要約 or 切り捨て）
  4. **クライアント側の簡易レート制限**（連投抑止）。厳密な月次上限はフェーズ3。

### 5.2 プロキシ拡張（`functions/index.js`）

`geminiProxy` に会話型（マルチターン）リクエストを追加する。

- 新タイプ `type: 'chat'` を追加。
- 入力: `systemPrompt`（システム指示 + 安全ガードレール + 要約文脈）、`messages`（`[{role: 'user'|'model', text}]` の配列）、`maxTokens`。
- Gemini SDK の `contents` に履歴配列をそのまま渡す（`role: 'user' | 'model'`）。
- 既存の `text` / `vision` タイプは変更しない（後方互換）。
- レスポンスは `{ text }`。**フェーズ3で `usageMetadata`（`promptTokenCount` / `candidatesTokenCount` / `cachedContentTokenCount`）も返すよう拡張予定**（MVPでは未使用でも返却フィールドだけ用意してよい）。

### 5.3 クライアント側

#### モデル `lib/models/chat_message.dart`
```
enum ChatRole { user, trainer }
class ChatMessage {
  final String id;
  final ChatRole role;
  final String text;
  final DateTime createdAt;
}
```

#### サービス `lib/services/trainer_chat_service.dart`
- 役割: システムプロンプト（口調 + 安全ガードレール）の組立、データ要約文脈の組立、履歴整形、`AiProxyService` のチャット呼び出し。
- システムプロンプト構成:
  - ベース: 「経験豊富なパーソナルトレーナー。トレーニング・栄養・生活習慣の一般的助言を行う」
  - 口調: `settings_provider` の `strict` / `normal` / `gentle` を流用。
  - **安全ガードレール（§7）**。
- データ要約文脈は既存資産を再利用:
  - `TrainingAdviceService.buildWeeklyLoadContext()`（週間トレ負荷）
  - `period_summary`（期間サマリ: 食事・トレ・体重変化）
  - 直近の体重・睡眠・カロリー収支
- `AiProxyService` に `callChat({systemPrompt, messages, maxTokens})` を追加。

#### プロバイダ `lib/providers/trainer_chat_provider.dart`
- `StateNotifierProvider`。状態: `messages`, `isLoading`, `error`。
- `sendMessage(String text)`: ユーザーメッセージ追加 → 履歴整形（直近Nターン）→ サービス呼び出し → トレーナー返答追加。
- 会話履歴の永続化:
  - **MVPは端末ローカル（`SharedPreferences` / sqlite）** に保存（既存のオフライン優先方針に合わせる）。
  - Firestore同期は将来オプション（§8）。
- `clearConversation()`, 履歴ローテーション（古いターンの破棄/要約）。

#### 画面 `lib/screens/trainer_chat_screen.dart`
- チャットUI（吹き出し、入力欄、送信、ローディング、エラー表示）。
- 入口: ダッシュボードのクイックアクセス or AppBar or エンドドロワー（要検討、§8）。
- **免責フッターを常時表示**（§7。プロンプト依存にしない）。
- 未サブスク時は `paywall_sheet` を提示。

### 5.4 MVPで作る/触るファイル一覧

- 追加: `lib/models/chat_message.dart`, `lib/services/trainer_chat_service.dart`, `lib/providers/trainer_chat_provider.dart`, `lib/screens/trainer_chat_screen.dart`
- 変更: `lib/services/ai_proxy_service.dart`（`callChat` 追加）, `functions/index.js`（`type: 'chat'` 追加）, 入口となる画面（ダッシュボード等）
- 既存流用: `training_advice_service.dart`（負荷要約）, `period_summary*`, `settings_provider.dart`（口調）, `paywall_sheet.dart`

## 6. 計測・追加課金フェーズ（フェーズ3）

### 6.1 計測アーキテクチャ

全AI呼び出しが通る `geminiProxy` を計測ポイントにする。

```
[アプリ] → geminiProxy
            ├─ ① 呼び出し前: users/{uid}/usage/{yyyy-mm} を読み、上限超過 & 追加クレジット無し
            │      → "limit-reached" を返す → アプリが追加課金導線を表示
            ├─ ② Gemini呼び出し
            └─ ③ 呼び出し後: usageMetadata の実トークン数を円換算し、当月カウンタに加算
```

- **計測は実トークンで事後記帳**（出力長は呼ぶまで不明なため、コスト予測ではなく `usageMetadata` で事後計上）。
- Firestore: `users/{uid}/usage/{yyyy-mm}` に `costYen`（or `tokensIn`/`tokensOut`）, `extraCreditYen` 等。
- 上限到達=自動ブロックなので、**追加課金しないユーザーの月間最大コストにハード上限**がかかる。

### 6.2 追加課金（オーバーエイジ）

- **消費型IAP（Consumable）**。自動更新サブスクではない。例: 「AI追加パック」。
- ⚠️ **追加パックにもストア手数料がかかる**。500円パックの手取り≈425円（15%）。**付与する利用枠 < 手取り**になるよう価格設計（例: 500円パック→手取り425円→付与は300〜350円相当のGemini枠で利益確保）。
- 購入完了 → サーバ（`activateSubscription` 同様の検証フロー）で `extraCreditYen` を加算。

### 6.3 UX

- ユーザーに「円」を見せず、**「今月のAI利用 70%」のメーター**や「クレジット/メッセージ数」に抽象化（自社コストを露出させない）。
- 上限到達時: チャット送信時に「今月の上限に達しました。追加パックで続けられます」→ 消費型IAPシート。
- 上限の置き方は年額・保守的手数料基準で1本化。

### 6.4 効果

- 追加課金しない人 → コスト上限が読める（下振れ保護）
- 追加課金する人 → 売上が増える（上振れ取り込み）
- §4.4 の「乱用2,700円」問題が構造的に消え、ヘビーユーザーがリスクから収益源に変わる。

### 6.5 実装メモ（フェーズ3）

- **計測**: `functions/index.js` の `geminiProxy` で、生成前に `assertWithinBudget()`（超過時 `resource-exhausted`）、生成後に `accrueUsage()` が `usageMetadata` を円換算して `users/{uid}/ai_usage/{YYYY-MM}` に加算。**全AI機能（text/chat/vision）が同じ経路を通るため一括計測される。**
- **単価・予算定数**（`functions/index.js` 冒頭。運用に応じて更新）:
  - `USD_TO_JPY = 150`、`INPUT 1.65 / OUTPUT 9.90 USD/1M`
  - `MONTHLY_INCLUDED_BUDGET_YEN = 1500`（サブスクに含む月次枠。他インフラ費を切り出すなら下げる）
  - `CREDIT_YEN_BY_PRODUCT`: `ai_credit_500 → 300円`、`ai_credit_1000 → 650円`（手数料15%を見込み付与額 < 手取り）
- **クライアント定数**: `AiUsage.monthlyIncludedYen = 1500`（サーバ定数と一致させること。メーター％算出用）。
- **追加課金**: 消費型IAP（`AiCreditProducts`）→ `SubscriptionService.purchaseCredit()` → 購入ストリームで `addAiCredit` を呼び、`purchaseToken` をキーに二重付与防止のうえ `extraCreditYen` を加算。
- **Firestore ルール**: `users/{uid}/ai_usage/{月}` はクライアント読み取りのみ・書き込みは Admin SDK のみ。`ai_credit_purchases` は Callable 専用。
- **UX**: チャット画面に利用80%超で利用枠メーターを表示。上限到達（`resource-exhausted`）で「追加パック」導線（`AiCreditSheet`）を提示。

### 6.6 本番化対応（実装済み）

- **レシート検証**: `functions/receipt_validation.js` を追加し、`activateSubscription` / `addAiCredit` で Apple（verifyReceipt）/ Google（Play Developer API）のサーバ検証を実施。`RECEIPT_VALIDATION_STRICT` で段階導入可能（移行期は未設定プラットフォームを許可、本番は fail-closed）。
- **既存AI機能の上限ハンドリング**: `AiProxyService` が `resource-exhausted` を `AiUsageLimitException`（`lib/services/ai_exceptions.dart`）に変換。全AI機能で分かりやすいメッセージが出る。共通ウィジェット `AiLimitBanner` と各画面（栄養アドバイス・食事提案・トレプラン・トレ日次アドバイス）に**追加パック導線**を配置。
- **ストア商品登録の手順書**: [AI追加パックとレシート検証_設定ガイド.md](./AI追加パックとレシート検証_設定ガイド.md) に、消費型IAP登録・シークレット設定・strictロールアウト・デプロイ手順をまとめた。

#### 残る運用作業（コンソール操作・要シークレット）
- App Store Connect / Google Play Console での `ai_credit_500` / `ai_credit_1000` 登録（手順書参照）。
- `APPLE_SHARED_SECRET` / `GOOGLE_PLAY_SERVICE_ACCOUNT` / `ANDROID_PACKAGE_NAME` のシークレット設定。
- テスト購入で検証確認後、`RECEIPT_VALIDATION_STRICT=true` へ切り替え。

## 7. 安全性（ガードレール）

「アプリ機能以上の相談」に広げる以上、健康相談に踏み込むため2段で担保する。

1. **システムプロンプト**: 「医療診断・治療方針・投薬・極端な食事制限・摂食障害が疑われる相談などには踏み込まず、一般的なエクササイズ／栄養指針の範囲で答える。該当時は専門家（医師・管理栄養士・理学療法士等）への相談を促す」を固定。既存サービスの「医療診断ではなく一般的な指針」という方針と整合。
2. **UI側の免責フッター常時表示**: プロンプト依存だけだとモデルが言い忘れた時に抜けるため、画面に「本機能は一般的な情報提供であり、医療・診断の代替ではありません。症状や持病がある場合は専門家にご相談ください」を常時併記する。

→ AIが言い忘れてもUIで担保され、クッションとして機能する。

## 8. オープン論点（実装前に確定したい）

1. **チャットの入口**: ダッシュボードのクイックアクセス / AppBar / エンドドロワー、どこに置くか（複数可）。
2. **会話履歴の永続化範囲**: MVPは端末ローカルのみで進めるが、Firestore同期（端末間引き継ぎ）をいつ載せるか。現状の同期対象は3テーブルのみ。
3. **履歴ローテーションの方式**: 直近Nターン切り捨て or 古い履歴の要約圧縮。MVPは単純な切り捨てで開始する想定。
4. **返答長キャップの具体値**: 700〜800 tokensを初期値に、UXとコストのバランスを見て調整。
5. **追加パックの価格・付与量**（フェーズ3）。
6. **会話の入力例/サジェスト**（「今日のメニューは？」等のクイック質問）をMVPに含めるか。

---

## 付録: 試算の前提値まとめ

| 項目 | 値 |
|---|---|
| モデル | gemini-3.5-flash（asia-northeast1 / non-global） |
| 入力単価 | $1.65 / 1M tokens |
| 出力単価 | $9.90 / 1M tokens |
| キャッシュ入力単価 | 約 $0.165 / 1M tokens |
| 為替 | 1 USD ≈ 150円（変数） |
| 月額 | 2,500円（`premium_monthly_2500`） |
| 年額 | 25,400円（`premium_annual_25400`） |
| AI＋インフラ負担上限 | 1,500円 / ユーザー / 月 |
| 返答長キャップ（初期値） | 700〜800 tokens |
