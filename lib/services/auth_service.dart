import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database_service.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const _secureStorage = FlutterSecureStorage();

  static const _tables = [
    'food_items',
    'training_logs',
    'body_metrics',
    'water_logs',
    'sleep_logs',
    'achievements',
    'training_plans',
    'meal_presets',
    'training_routines',
    'exercise_animations',
    'shopping_ingredient_aliases',
    'shopping_ingredient_surface_stats',
  ];

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

    // Delete Firestore subcollections
    final userDoc = _firestore.collection('users').doc(uid);
    for (final table in _tables) {
      final snapshot = await userDoc.collection(table).get();
      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      if (snapshot.docs.isNotEmpty) await batch.commit();
    }
    await userDoc.delete();

    // Clear local DB
    final adapter = await DatabaseService().database;
    for (final table in _tables) {
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
