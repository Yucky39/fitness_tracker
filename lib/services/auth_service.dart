import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'database_service.dart';
import 'sync_tables.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const _secureStorage = FlutterSecureStorage();

  User? get currentUser => _auth.currentUser;
  String? get userId => _auth.currentUser?.uid;
  String? get userEmail => _auth.currentUser?.email;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential> signUp({
    required String email,
    required String password,
  }) async {
    return await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  // ── Social sign-in ──────────────────────────────────────────────────────

  Future<UserCredential> signInWithGoogle() async {
    final googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) throw Exception('キャンセルされました');
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    return await _auth.signInWithCredential(credential);
  }

  Future<UserCredential> signInWithApple() async {
    if (Platform.isIOS || Platform.isMacOS) {
      // iOS/macOS: ネイティブ Apple Sign-In
      final rawNonce = _generateNonce();
      final nonce = _sha256ofString(rawNonce);
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );
      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        rawNonce: rawNonce,
      );
      return await _auth.signInWithCredential(oauthCredential);
    } else {
      // Android: Firebase Auth の Web OAuth フロー経由
      // Apple Developer Portal で Service ID と Firebase のリダイレクト URL の設定が必要
      final provider = OAuthProvider('apple.com')
        ..addScope('email')
        ..addScope('name');
      return await _auth.signInWithProvider(provider);
    }
  }

  Future<UserCredential> signInWithTwitter() async {
    final twitterProvider = TwitterAuthProvider();
    return await _auth.signInWithProvider(twitterProvider);
  }

  Future<UserCredential> signInWithFacebook() async {
    final result = await FacebookAuth.instance.login();
    if (result.status == LoginStatus.cancelled) {
      throw Exception('キャンセルされました');
    }
    if (result.status != LoginStatus.success || result.accessToken == null) {
      throw Exception('Metaログインに失敗しました');
    }
    final credential =
        FacebookAuthProvider.credential(result.accessToken!.tokenString);
    return await _auth.signInWithCredential(credential);
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
        length, (_) => charset[random.nextInt(charset.length)]).join();
  }

  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // ────────────────────────────────────────────────────────────────────────

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  /// Re-authenticates the current user with email/password.
  Future<void> reauthenticate(String password) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) throw Exception('ユーザーが見つかりません');
    final credential = EmailAuthProvider.credential(
      email: user.email!,
      password: password,
    );
    await user.reauthenticateWithCredential(credential);
  }

  /// Deletes all Firestore data, local DB data, and the Firebase Auth account.
  /// Must call [reauthenticate] immediately before this.
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('ユーザーが見つかりません');
    final uid = user.uid;

    // subscription サブコレクションはセキュリティルール上クライアントから削除できない
    // （Admin SDK 専用）。先にサーバー側でユーザーデータを完全削除する。
    // 失敗してもアカウント自体の削除は続行する（孤児ドキュメントは Auth 削除トリガで回収）。
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'asia-northeast1')
          .httpsCallable('purgeUserData');
      await callable.call();
    } catch (_) {
      // サーバー側削除に失敗した場合でも、以下でクライアント可能な範囲を削除する。
    }

    // Delete Firestore subcollections (client-writable tables only)
    final userDoc = _firestore.collection('users').doc(uid);
    for (final table in SyncTables.synced) {
      final snapshot = await userDoc.collection(table).get();
      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      if (snapshot.docs.isNotEmpty) await batch.commit();
    }
    await userDoc.delete();

    // Clear local DB (all local tables, including local-only caches)
    final adapter = await DatabaseService().database;
    for (final table in SyncTables.all) {
      await adapter.delete(table);
    }

    // Clear local preferences and device-only API keys tied to the account.
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await _secureStorage.deleteAll();

    // Delete Firebase Auth account
    await user.delete();
  }
}
