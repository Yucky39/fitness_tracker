#!/usr/bin/env node
/**
 * Android APK を Firebase Storage にアップロードし、
 * Firestore app_releases/android/latest にメタデータを書き込む。
 *
 * 使い方:
 *   node scripts/upload_android_release.js build/app/outputs/flutter-apk/app-release.apk \
 *     --version 1.0.1 --version-code 3 --notes "初回ベータ配布"
 *
 * 前提:
 *   - firebase login 済み、または GOOGLE_APPLICATION_CREDENTIALS が設定されている
 *   - firebase use fitness-tracker-828df などプロジェクトが選択されている
 */

const fs = require('fs');
const path = require('path');

// functions/ の firebase-admin を利用
const admin = require(path.join(__dirname, '../functions/node_modules/firebase-admin'));

const PROJECT_ID = 'fitness-tracker-828df';
const STORAGE_BUCKET = 'fitness-tracker-828df.firebasestorage.app';

function parseArgs(argv) {
  const positional = [];
  const options = {};

  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === '--version') {
      options.versionName = argv[++i];
    } else if (arg === '--version-code') {
      options.versionCode = Number(argv[++i]);
    } else if (arg === '--notes') {
      options.releaseNotes = argv[++i] ?? '';
    } else if (!arg.startsWith('-')) {
      positional.push(arg);
    }
  }

  return { apkPath: positional[0], options };
}

async function main() {
  const { apkPath, options } = parseArgs(process.argv.slice(2));

  if (!apkPath) {
    console.error('Usage: node scripts/upload_android_release.js <apk-path> --version <name> --version-code <int> [--notes <text>]');
    process.exit(1);
  }

  const resolvedApk = path.resolve(apkPath);
  if (!fs.existsSync(resolvedApk)) {
    console.error(`APK not found: ${resolvedApk}`);
    process.exit(1);
  }

  const versionName = options.versionName;
  const versionCode = options.versionCode;
  const releaseNotes = options.releaseNotes ?? '';

  if (!versionName || !Number.isInteger(versionCode) || versionCode <= 0) {
    console.error('--version と --version-code（正の整数）は必須です。');
    process.exit(1);
  }

  if (!admin.apps.length) {
    admin.initializeApp({
      projectId: PROJECT_ID,
      storageBucket: STORAGE_BUCKET,
    });
  }

  const fileName = `fitness_tracker-${versionName}+${versionCode}.apk`;
  const storagePath = `releases/android/${fileName}`;

  console.log(`Uploading ${resolvedApk} -> gs://${STORAGE_BUCKET}/${storagePath}`);

  const bucket = admin.storage().bucket();
  await bucket.upload(resolvedApk, {
    destination: storagePath,
    metadata: {
      contentType: 'application/vnd.android.package-archive',
      metadata: {
        versionName,
        versionCode: String(versionCode),
      },
    },
  });

  const file = bucket.file(storagePath);
  const [downloadUrl] = await file.getSignedUrl({
    action: 'read',
    expires: '03-01-2500',
  });

  const releaseDoc = {
    versionName,
    versionCode,
    storagePath,
    downloadUrl,
    releaseNotes,
    active: true,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  await admin.firestore().doc('app_releases/android/latest').set(releaseDoc, { merge: true });

  console.log('Upload complete.');
  console.log(`Firestore: app_releases/android/latest`);
  console.log(`  versionName: ${versionName}`);
  console.log(`  versionCode: ${versionCode}`);
  console.log(`  storagePath: ${storagePath}`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
