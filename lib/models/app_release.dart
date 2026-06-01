import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore `app_releases/android/latest` に保存する APK 配布メタデータ。
class AppRelease {
  const AppRelease({
    required this.versionName,
    required this.versionCode,
    required this.storagePath,
    this.releaseNotes = '',
    this.active = true,
    this.updatedAt,
  });

  final String versionName;
  final int versionCode;
  final String storagePath;
  final String releaseNotes;
  final bool active;
  final DateTime? updatedAt;

  factory AppRelease.fromFirestore(Map<String, dynamic> data) {
    final updatedAtRaw = data['updatedAt'];
    DateTime? updatedAt;
    if (updatedAtRaw is Timestamp) {
      updatedAt = updatedAtRaw.toDate();
    }

    return AppRelease(
      versionName: data['versionName'] as String? ?? '',
      versionCode: (data['versionCode'] as num?)?.toInt() ?? 0,
      storagePath: data['storagePath'] as String? ?? '',
      releaseNotes: data['releaseNotes'] as String? ?? '',
      active: data['active'] as bool? ?? false,
      updatedAt: updatedAt,
    );
  }
}
