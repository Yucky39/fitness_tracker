import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';
import 'database_service.dart';

/// Handles bidirectional sync between local SQLite/SharedPreferences and Firestore.
///
/// Strategy:
/// - On register: upload existing local data to Firestore (keep data when creating account)
/// - On login: download Firestore data and merge into local DB + SharedPreferences
/// - On write: persist locally then sync to Firestore in background (fire-and-forget)
/// - On delete: remove locally then sync deletion to Firestore
class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Tables synced per-record to Firestore subcollections
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
  ];

  String? get _userId => AuthService().userId;

  DocumentReference get _userDoc =>
      _firestore.collection('users').doc(_userId);

  CollectionReference _collection(String table) =>
      _userDoc.collection(table);

  // ── SQLite Sync ───────────────────────────────────────────────────────────

  /// Upload all local SQLite records and user profile to Firestore.
  Future<void> uploadAllData() async {
    if (_userId == null) return;
    final adapter = await DatabaseService().database;

    for (final table in _tables) {
      final rows = await adapter.query(table);
      if (rows.isEmpty) continue;

      final batch = _firestore.batch();
      for (final row in rows) {
        final docRef = _collection(table).doc(row['id'] as String);
        batch.set(docRef, row);
      }
      await batch.commit();
    }

    await uploadUserProfile();
  }

  /// Download Firestore data and merge into local DB + SharedPreferences.
  Future<void> downloadAndMergeData() async {
    if (_userId == null) return;
    final adapter = await DatabaseService().database;

    for (final table in _tables) {
      final snapshot = await _collection(table).get();
      if (snapshot.docs.isEmpty) continue;

      final localRows = await adapter.query(table);
      final localIds = localRows.map((r) => r['id'] as String).toSet();

      for (final doc in snapshot.docs) {
        if (!localIds.contains(doc.id)) {
          final row = Map<String, dynamic>.from(doc.data() as Map);
          row['id'] ??= doc.id;
          await adapter.insert(table, row);
        }
      }
    }

    await downloadAndApplyUserProfile();
  }

  /// Sync a single record to Firestore (fire-and-forget).
  void syncRecord(String table, Map<String, dynamic> data) {
    if (_userId == null) return;
    _collection(table)
        .doc(data['id'] as String)
        .set(data)
        .catchError((_) {});
  }

  /// Delete a record from Firestore (fire-and-forget).
  void deleteRecord(String table, String id) {
    if (_userId == null) return;
    _collection(table).doc(id).delete().catchError((_) {});
  }

  // ── User Profile (SharedPreferences) Sync ────────────────────────────────

  /// Writes an entire top-level section of the user document (e.g. 'profile', 'settings').
  /// Uses merge:true so other sections are not overwritten.
  void syncSection(String section, Map<String, dynamic> data) {
    if (_userId == null) return;
    _userDoc
        .set({section: data}, SetOptions(merge: true))
        .catchError((_) {});
  }

  /// Updates specific dot-notation fields (e.g. 'goals.waterGoalMl').
  /// Uses update() so nested sibling fields are preserved.
  void syncFields(Map<String, dynamic> dotFields) {
    if (_userId == null) return;
    _userDoc.update(dotFields).catchError((_) {});
  }

  /// Reads all relevant SharedPreferences and uploads them to the user's Firestore document.
  Future<void> uploadUserProfile() async {
    if (_userId == null) return;
    final prefs = await SharedPreferences.getInstance();

    final streakRaw = prefs.getString('streakData');
    final streaks = streakRaw != null
        ? jsonDecode(streakRaw) as Map<String, dynamic>
        : <String, dynamic>{};

    await _userDoc.set(
      {
        'profile': {
          'sex': prefs.getString('energyProfileSex'),
          'age': prefs.getInt('energyProfileAge') ?? 0,
          'heightCm': prefs.getDouble('energyProfileHeightCm') ?? 0.0,
          'weightKg': prefs.getDouble('energyProfileWeightKg') ?? 0.0,
          'targetWeightKg': prefs.getDouble('energyProfileTargetKg') ?? 0.0,
          'goalWeeks': prefs.getInt('energyProfileGoalWeeks') ?? 12,
          'activityLevel':
              prefs.getString('energyProfileActivity') ?? 'moderate',
        },
        'goals': {
          'calorieGoal': prefs.getInt('calorieGoal') ?? 2000,
          'proteinGoal': prefs.getDouble('proteinGoal') ?? 150.0,
          'fatGoal': prefs.getDouble('fatGoal') ?? 60.0,
          'carbsGoal': prefs.getDouble('carbsGoal') ?? 200.0,
          'fiberGoal': prefs.getDouble('fiberGoal') ?? 25.0,
          'sodiumGoal': prefs.getDouble('sodiumGoal') ?? 2300.0,
          'waterGoalMl': prefs.getInt('waterGoalMl') ?? 2000,
          'sleepGoalMinutes': prefs.getInt('sleepGoalMinutes') ?? 420,
        },
        'settings': {
          'adviceLevel': prefs.getString('adviceLevel') ?? 'normal',
          'selectedProvider':
              prefs.getString('selectedAiProvider') ?? 'anthropic',
          'anthropicModel': prefs.getString('anthropicModel') ??
              'claude-haiku-4-5-20251001',
          'openAiModel':
              prefs.getString('openAiModel') ?? 'gpt-4o-mini',
          'geminiModel':
              prefs.getString('geminiModel') ?? 'gemini-3.5-flash',
          'mealReminderEnabled':
              prefs.getBool('mealReminderEnabled') ?? false,
          'mealReminderHour': prefs.getInt('mealReminderHour') ?? 12,
          'mealReminderMinute': prefs.getInt('mealReminderMinute') ?? 0,
          'workoutReminderEnabled':
              prefs.getBool('workoutReminderEnabled') ?? false,
          'workoutReminderHour':
              prefs.getInt('workoutReminderHour') ?? 18,
          'workoutReminderMinute':
              prefs.getInt('workoutReminderMinute') ?? 0,
          'trainingAdviceEnabled':
              prefs.getBool('trainingAdviceEnabled') ?? true,
          'communityFoodContributeEnabled':
              prefs.getBool('communityFoodContributeEnabled') ?? true,
          'mealSuggestionEnabled':
              prefs.getBool('mealSuggestionEnabled') ?? false,
        },
        'streaks': streaks,
      },
      SetOptions(merge: true),
    );
  }

  /// Downloads the user's Firestore profile document and writes to SharedPreferences.
  /// If the document doesn't exist yet, uploads current local data instead.
  Future<void> downloadAndApplyUserProfile() async {
    if (_userId == null) return;
    final snap = await _userDoc.get();

    if (!snap.exists) {
      await uploadUserProfile();
      return;
    }

    final data = snap.data() as Map<String, dynamic>;
    final prefs = await SharedPreferences.getInstance();

    final profile = data['profile'] as Map<String, dynamic>?;
    if (profile != null) {
      final sex = profile['sex'] as String?;
      if (sex != null && sex.isNotEmpty) {
        await prefs.setString('energyProfileSex', sex);
      }
      await prefs.setInt(
          'energyProfileAge', _toInt(profile['age']) ?? 0);
      await prefs.setDouble(
          'energyProfileHeightCm', _toDouble(profile['heightCm']) ?? 0.0);
      await prefs.setDouble(
          'energyProfileWeightKg', _toDouble(profile['weightKg']) ?? 0.0);
      await prefs.setDouble('energyProfileTargetKg',
          _toDouble(profile['targetWeightKg']) ?? 0.0);
      await prefs.setInt(
          'energyProfileGoalWeeks', _toInt(profile['goalWeeks']) ?? 12);
      await prefs.setString('energyProfileActivity',
          profile['activityLevel'] as String? ?? 'moderate');
    }

    final goals = data['goals'] as Map<String, dynamic>?;
    if (goals != null) {
      await prefs.setInt(
          'calorieGoal', _toInt(goals['calorieGoal']) ?? 2000);
      await prefs.setDouble(
          'proteinGoal', _toDouble(goals['proteinGoal']) ?? 150.0);
      await prefs.setDouble(
          'fatGoal', _toDouble(goals['fatGoal']) ?? 60.0);
      await prefs.setDouble(
          'carbsGoal', _toDouble(goals['carbsGoal']) ?? 200.0);
      await prefs.setDouble(
          'fiberGoal', _toDouble(goals['fiberGoal']) ?? 25.0);
      await prefs.setDouble(
          'sodiumGoal', _toDouble(goals['sodiumGoal']) ?? 2300.0);
      await prefs.setInt(
          'waterGoalMl', _toInt(goals['waterGoalMl']) ?? 2000);
      await prefs.setInt(
          'sleepGoalMinutes', _toInt(goals['sleepGoalMinutes']) ?? 420);
    }

    final settings = data['settings'] as Map<String, dynamic>?;
    if (settings != null) {
      await prefs.setString(
          'adviceLevel', settings['adviceLevel'] as String? ?? 'normal');
      await prefs.setString('selectedAiProvider',
          settings['selectedProvider'] as String? ?? 'anthropic');
      await prefs.setString('anthropicModel',
          settings['anthropicModel'] as String? ?? 'claude-haiku-4-5-20251001');
      await prefs.setString('openAiModel',
          settings['openAiModel'] as String? ?? 'gpt-4o-mini');
      await prefs.setString('geminiModel',
          settings['geminiModel'] as String? ?? 'gemini-3.5-flash');
      await prefs.setBool('mealReminderEnabled',
          settings['mealReminderEnabled'] as bool? ?? false);
      await prefs.setInt('mealReminderHour',
          _toInt(settings['mealReminderHour']) ?? 12);
      await prefs.setInt('mealReminderMinute',
          _toInt(settings['mealReminderMinute']) ?? 0);
      await prefs.setBool('workoutReminderEnabled',
          settings['workoutReminderEnabled'] as bool? ?? false);
      await prefs.setInt('workoutReminderHour',
          _toInt(settings['workoutReminderHour']) ?? 18);
      await prefs.setInt('workoutReminderMinute',
          _toInt(settings['workoutReminderMinute']) ?? 0);
      await prefs.setBool('trainingAdviceEnabled',
          settings['trainingAdviceEnabled'] as bool? ?? true);
      await prefs.setBool('communityFoodContributeEnabled',
          settings['communityFoodContributeEnabled'] as bool? ?? true);
      await prefs.setBool('mealSuggestionEnabled',
          settings['mealSuggestionEnabled'] as bool? ?? false);
    }

    final streaks = data['streaks'] as Map<String, dynamic>?;
    if (streaks != null && streaks.isNotEmpty) {
      await prefs.setString('streakData', jsonEncode(streaks));
    }
  }

  int? _toInt(dynamic v) => v == null ? null : (v as num).toInt();
  double? _toDouble(dynamic v) => v == null ? null : (v as num).toDouble();
}
