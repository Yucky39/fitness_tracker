#!/usr/bin/env node
'use strict';

/**
 * App Store 審査用アカウントに appReview カスタムクレームを付与する。
 *
 * 使い方（プロジェクトルートで）:
 *   cd functions
 *   export GOOGLE_APPLICATION_CREDENTIALS=/path/to/serviceAccount.json
 *   node scripts/grant_app_review.js review@example.com
 *
 * または firebase ログイン済みなら:
 *   npx firebase functions:shell  # 不要 — 下記で十分
 *   node scripts/grant_app_review.js
 */

const admin = require('firebase-admin');

const email = (process.argv[2] || 'review@example.com').trim().toLowerCase();

if (!email) {
  console.error('Usage: node scripts/grant_app_review.js <email>');
  process.exit(1);
}

admin.initializeApp();

async function main() {
  const user = await admin.auth().getUserByEmail(email);
  await admin.auth().setCustomUserClaims(user.uid, { appReview: true });
  console.log(`OK: appReview=true for ${email}`);
  console.log(`    uid: ${user.uid}`);
  console.log('Next: deploy functions with APP_REVIEW_EMAILS (optional), then sign out/in on device.');
}

main().catch((err) => {
  console.error(err.message || err);
  process.exit(1);
});
