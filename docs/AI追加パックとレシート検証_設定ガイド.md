# AI追加パックとレシート検証 設定ガイド

AIトレーナーチャット等の利用枠を増やす **AI追加パック（消費型IAP）** のストア登録と、
不正購入を防ぐ **サーバ側レシート検証** の設定手順をまとめています。

> 関連: [AIトレーナーチャット_設計.md](./AIトレーナーチャット_設計.md)（機能全体の設計・コスト試算）
> サブスク本体の登録は [サブスクリプション設定ガイド.md](./サブスクリプション設定ガイド.md) を参照。

---

## 目次

1. [AI追加パックの商品ID](#1-ai追加パックの商品id)
2. [App Store Connect での登録](#2-app-store-connect-での登録)
3. [Google Play Console での登録](#3-google-play-console-での登録)
4. [レシート検証のシークレット設定](#4-レシート検証のシークレット設定)
5. [段階的なロールアウト（strictフラグ）](#5-段階的なロールアウトstrictフラグ)
6. [デプロイ手順](#6-デプロイ手順)

---

## 1. AI追加パックの商品ID

アプリに実装済みの消費型（Consumable）商品IDは以下の2つです。
**ストアには必ずこのIDと一致させて登録してください**（`lib/models/subscription.dart` の `AiCreditProducts`）。

| パック | 商品ID | 付与する利用枠 | 参考価格の考え方 |
|---|---|---|---|
| 小 | `ai_credit_500` | 300円相当 | 手取り（手数料15%後 ≈ 425円）> 付与300円で黒字 |
| 大 | `ai_credit_1000` | 650円相当 | 手取り（≈ 850円）> 付与650円で黒字 |

- 付与額は Cloud Functions の `CREDIT_YEN_BY_PRODUCT`（`functions/index.js`）で定義。
- **ストア価格は手数料を見込み「付与する利用枠 < 手取り」になるように設定**すること。
- これらは **消費型（Consumable / 消費アイテム）** として登録する（サブスクでも非消費型でもない）。

---

## 2. App Store Connect での登録

1. **App Store Connect** → 対象アプリ → 「アプリ内課金」
2. 「＋」→ **消費型（Consumable）** を選択
3. 「製品ID」に `ai_credit_500` を入力（参照名は任意、例: AI追加パック小）
4. 価格・各言語の表示名・説明を設定
5. 同様に `ai_credit_1000` を登録
6. 審査用のスクリーンショット等を添付し、「提出準備完了」にする

> サブスク本体（`premium_monthly_2500` / `premium_annual_25400`）の登録は別ガイド参照。

---

## 3. Google Play Console での登録

1. **Google Play Console** → 対象アプリ → 「収益化」→「アプリ内アイテム」→「アプリ内アイテム（管理対象商品）」
2. 「商品を作成」→ 商品ID `ai_credit_500` を入力
3. 名前・説明・価格を設定して「有効化」
4. 同様に `ai_credit_1000` を登録

> 消費型はクライアントで `buyConsumable`（`autoConsume` 既定で消費）されるため、繰り返し購入できます。

---

## 4. レシート検証のシークレット設定

サーバ（Cloud Functions）が `activateSubscription` / `addAiCredit` の購入トークンを検証します。
以下のシークレット / 設定を **Secret Manager / 環境変数** に登録してください。

### 4-1. Apple（共有シークレット）

App Store Connect → 対象アプリ → 「App用共有シークレット（App-Specific Shared Secret）」を生成し、登録:

```bash
firebase functions:secrets:set APPLE_SHARED_SECRET
# プロンプトに共有シークレットを貼り付け
```

### 4-2. Google Play（サービスアカウント）

1. Google Cloud Console でサービスアカウントを作成（または既存を利用）
2. **Google Play Console** → 「ユーザーと権限」でそのサービスアカウントを招待し、
   「財務データの表示」「注文と購入の管理」権限を付与
3. サービスアカウントのJSONキーを発行し、**JSON文字列まるごと** を登録:

```bash
firebase functions:secrets:set GOOGLE_PLAY_SERVICE_ACCOUNT
# JSONファイルの中身を貼り付け（{ ... } 全体）
```

> 反映には Google Play Developer API の有効化と、Play Console 側でのアカウントリンクが必要です。
> 権限反映に最大24〜48時間かかる場合があります。

### 4-3. パッケージ名

`ANDROID_PACKAGE_NAME` を Android の applicationId に合わせます（既定 `com.example.fitness_tracker`）。
本番の applicationId に変更している場合は設定してください:

```bash
firebase functions:config:set  # ではなく、v2 では環境変数 / .env を利用
# functions/.env などに ANDROID_PACKAGE_NAME=com.yourcompany.app
```

---

## 5. 段階的なロールアウト（strictフラグ）

`RECEIPT_VALIDATION_STRICT`（既定 `false`）で検証の厳格さを切り替えます。

| 値 | 挙動 |
|---|---|
| `false`（既定・移行期） | シークレットが設定済みのプラットフォームのみ検証。**未設定なら検証をスキップして許可**（警告ログ）。検証に失敗した購入は拒否。 |
| `true`（本番・推奨） | **fail-closed**。シークレット未設定のプラットフォームの購入も拒否する。 |

### 推奨手順

1. まず現状（`false`）のままコードをデプロイ → 既存の購入フローは壊れない
2. §4 のシークレットを設定し、テスト購入で検証が通ることを確認
3. `RECEIPT_VALIDATION_STRICT=true` に切り替えて本番運用（不正購入を完全に遮断）

> 検証失敗時はクライアントへ `permission-denied`「購入の検証に失敗しました。」を返します。

---

## 6. デプロイ手順

```bash
# 依存関係（google-auth-library を追加済み）
cd functions && npm install

# Firestore ルール（ai_usage / ai_credit_purchases を追加済み）
firebase deploy --only firestore:rules

# Functions（geminiProxy 計測 / addAiCredit / レシート検証）
firebase deploy --only functions
```

### 関連する実装ファイル

| ファイル | 役割 |
|---|---|
| `functions/index.js` | `geminiProxy`（計測）/ `activateSubscription` / `addAiCredit` |
| `functions/receipt_validation.js` | Apple / Google のレシート検証 |
| `firestore.rules` | `ai_usage`（読み取りのみ）/ `ai_credit_purchases`（Callable専用） |
| `lib/models/subscription.dart` | `AiCreditProducts`（商品ID） |
| `lib/services/subscription_service.dart` | 消費型購入と `addAiCredit` 呼び出し |
| `lib/widgets/ai_credit_sheet.dart` | 追加パック購入シート |

---

## チェックリスト（本番化）

- [ ] App Store Connect / Google Play Console に `ai_credit_500` / `ai_credit_1000` を登録
- [ ] ストア価格が「付与する利用枠 < 手取り」になっている
- [ ] `APPLE_SHARED_SECRET` を設定
- [ ] `GOOGLE_PLAY_SERVICE_ACCOUNT` を設定し Play Console とリンク
- [ ] `ANDROID_PACKAGE_NAME` を本番 applicationId に設定
- [ ] テスト購入で検証が通ることを確認
- [ ] `RECEIPT_VALIDATION_STRICT=true` に切り替え
- [ ] `MONTHLY_INCLUDED_BUDGET_YEN`（サーバ）と `AiUsage.monthlyIncludedYen`（クライアント）が一致
