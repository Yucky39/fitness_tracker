import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_provider.dart';

/// App Store 審査用（Firebase Auth カスタムクレーム `appReview: true`）。
/// 設定後は一度ログアウト／ログインするか、アプリ再起動でトークンが更新される。
final appReviewAccessFutureProvider = FutureProvider<bool>((ref) async {
  ref.watch(authStateProvider);
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return false;
  final result = await user.getIdTokenResult(true);
  return result.claims?['appReview'] == true;
});
