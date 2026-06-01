import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/app_release.dart';

class AppUpdateCheckResult {
  const AppUpdateCheckResult({
    required this.currentVersionCode,
    this.release,
  });

  final int currentVersionCode;
  final AppRelease? release;

  bool get hasUpdate =>
      release != null &&
      release!.active &&
      release!.versionCode > currentVersionCode;
}

class AppUpdateService {
  static final AppUpdateService _instance = AppUpdateService._();
  factory AppUpdateService() => _instance;
  AppUpdateService._();

  static const _releaseDocPath = 'app_releases/android/latest';

  Future<AppUpdateCheckResult> checkForUpdate() async {
    if (!Platform.isAndroid) {
      return AppUpdateCheckResult(currentVersionCode: 0);
    }

    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersionCode = int.tryParse(packageInfo.buildNumber) ?? 0;

    final snap = await FirebaseFirestore.instance.doc(_releaseDocPath).get();
    if (!snap.exists || snap.data() == null) {
      return AppUpdateCheckResult(currentVersionCode: currentVersionCode);
    }

    final release = AppRelease.fromFirestore(snap.data()!);
    if (!release.active || release.storagePath.isEmpty) {
      return AppUpdateCheckResult(currentVersionCode: currentVersionCode);
    }

    return AppUpdateCheckResult(
      currentVersionCode: currentVersionCode,
      release: release,
    );
  }

  /// APK を Storage からダウンロードし、システムのインストーラーを起動する。
  Future<void> downloadAndInstall(
    AppRelease release, {
    void Function(double progress)? onProgress,
  }) async {
    if (!Platform.isAndroid) {
      throw UnsupportedError('APK のインストールは Android のみ対応しています。');
    }

    final ref = FirebaseStorage.instance.ref(release.storagePath);
    final tempDir = await getTemporaryDirectory();
    final fileName = p.basename(release.storagePath);
    final localFile = File(p.join(tempDir.path, fileName));

    if (await localFile.exists()) {
      await localFile.delete();
    }

    final task = ref.writeToFile(localFile);
    if (onProgress != null) {
      task.snapshotEvents.listen((event) {
        final total = event.totalBytes;
        if (total <= 0) return;
        onProgress(event.bytesTransferred / total);
      });
    }
    await task;

    final result = await OpenFilex.open(
      localFile.path,
      type: 'application/vnd.android.package-archive',
    );
    if (result.type != ResultType.done) {
      throw Exception(result.message);
    }
  }
}
