import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';
import 'database_service.dart';
import 'sync_tables.dart';

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

  // Tables synced per-record to Firestore subcollections (single source of truth)
  static const _tables = SyncTables.synced;

  // クラウド専用フィールド（ローカルDBには書き戻さない）。
  static const _kUpdatedAt = 'updatedAt'; // LWW 用の更新時刻（ms）
  static const _kDeleted = 'deleted'; // tombstone（削除マーカー）

  // オフライン中に失敗した書き込み/削除を保持する再送キュー。
  static const _queueKey = 'sync_pending_queue';
  bool _flushing = false;

  // body_metrics の写真: ローカルパス列 → クラウドに保存する Storage パス列。
  // ローカルパスは端末固有なのでクラウドには保存せず、Storage パスのみ保存する。
  static const _photoFields = {
    'image_front_path': 'image_front_remote',
    'image_side_path': 'image_side_remote',
    'image_back_path': 'image_back_remote',
  };

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
    final now = DateTime.now().millisecondsSinceEpoch;

    for (final table in _tables) {
      final rows = await adapter.query(table);
      if (rows.isEmpty) continue;

      // body_metrics は写真を Storage へアップロードしてから同期する。
      if (table == 'body_metrics') {
        for (final row in rows) {
          await syncBodyMetrics(row);
        }
        continue;
      }

      final batch = _firestore.batch();
      for (final row in rows) {
        final docRef = _collection(table).doc(row['id'] as String);
        batch.set(docRef, {...row, _kUpdatedAt: now});
      }
      await batch.commit();
    }

    await uploadUserProfile();
  }

  /// Download Firestore data and merge into local DB + SharedPreferences.
  ///
  /// 双方向マージ:
  /// - tombstone（deleted=true）はローカルからも削除し、ゾンビ復活を防ぐ。
  /// - 既存IDは update、未知IDは insert（upsert）。編集がローカルへ反映される。
  /// - ログインはクラウドを正とする同期点（cloud-wins）。
  Future<void> downloadAndMergeData() async {
    if (_userId == null) return;

    // 先に未送信キューを送り切ってからクラウドを取り込む。
    await flushPendingQueue();

    final adapter = await DatabaseService().database;

    for (final table in _tables) {
      final snapshot = await _collection(table).get();
      if (snapshot.docs.isEmpty) continue;

      for (final doc in snapshot.docs) {
        final raw = Map<String, dynamic>.from(doc.data() as Map);

        // tombstone はローカル削除。
        if (raw[_kDeleted] == true) {
          await adapter.delete(table, where: 'id = ?', whereArgs: [doc.id]);
          continue;
        }

        // クラウド専用フィールドを除去してからローカルへ書く。
        raw.remove(_kUpdatedAt);
        raw.remove(_kDeleted);
        raw['id'] ??= doc.id;

        // body_metrics は Storage パスを端末ローカルへダウンロードして
        // image_*_path に書き戻す（UI は Image.file を使うため）。
        if (table == 'body_metrics') {
          await _applyBodyPhotos(raw);
        }

        try {
          await _upsertLocal(adapter, table, raw);
        } catch (_) {
          // 制約違反などで1件失敗しても全体は止めない。
        }
      }
    }

    await downloadAndApplyUserProfile();
  }

  Future<void> _upsertLocal(
    dynamic adapter,
    String table,
    Map<String, dynamic> row,
  ) async {
    final id = row['id'];
    final existing =
        await adapter.query(table, where: 'id = ?', whereArgs: [id], limit: 1);
    if (existing.isNotEmpty) {
      await adapter.update(table, row, where: 'id = ?', whereArgs: [id]);
    } else {
      await adapter.insert(table, row);
    }
  }

  /// Sync a single record to Firestore. 失敗時は再送キューへ退避する。
  void syncRecord(String table, Map<String, dynamic> data) {
    if (_userId == null) return;
    final id = data['id'] as String;
    final payload = {
      ...data,
      _kUpdatedAt: DateTime.now().millisecondsSinceEpoch,
    };
    _setRemote(table, id, payload);
  }

  /// Delete a record from Firestore via tombstone（他端末へ削除を伝播）。
  void deleteRecord(String table, String id) {
    if (_userId == null) return;
    _deleteRemote(table, id);
  }

  // ── 体型写真（Firebase Storage）────────────────────────────────────────────

  String _photoStoragePath(String id, String dir) =>
      'users/$_userId/body_photos/${id}_$dir.jpg';

  String _dirOf(String pathKey) => pathKey.contains('front')
      ? 'front'
      : pathKey.contains('side')
          ? 'side'
          : 'back';

  /// body_metrics を同期する。写真は Storage へアップロードし、
  /// クラウドには Storage パスのみ保存する（端末固有のローカルパスは保存しない）。
  Future<void> syncBodyMetrics(Map<String, dynamic> data) async {
    if (_userId == null) return;
    final payload = Map<String, dynamic>.from(data);
    final id = data['id'] as String;

    for (final entry in _photoFields.entries) {
      final pathKey = entry.key;
      final remoteKey = entry.value;
      // 端末固有のローカルパスはクラウドへ保存しない。
      payload.remove(pathKey);

      final localPath = data[pathKey] as String?;
      if (kIsWeb || localPath == null || localPath.isEmpty) continue;
      // 既にリモートURL/パスが入っている場合はそのまま使う。
      if (localPath.startsWith('http') || localPath.startsWith('users/')) {
        payload[remoteKey] = localPath;
        continue;
      }
      try {
        final file = File(localPath);
        if (!await file.exists()) continue;
        final storagePath = _photoStoragePath(id, _dirOf(pathKey));
        await FirebaseStorage.instance.ref(storagePath).putFile(file);
        payload[remoteKey] = storagePath;
      } catch (_) {
        // アップロード失敗時は写真なしで本文だけ同期する。
      }
    }

    syncRecord('body_metrics', payload);
  }

  /// body_metrics を削除する。Storage 上の写真も併せて削除する。
  Future<void> deleteBodyMetrics(String id) async {
    if (_userId == null) return;
    if (!kIsWeb) {
      for (final pathKey in _photoFields.keys) {
        try {
          await FirebaseStorage.instance
              .ref(_photoStoragePath(id, _dirOf(pathKey)))
              .delete();
        } catch (_) {
          // 元々写真が無い場合などは無視。
        }
      }
    }
    deleteRecord('body_metrics', id);
  }

  /// ダウンロードした body_metrics の Storage パスを端末ローカルへ取得し、
  /// image_*_path に書き戻す。クラウド専用の *_remote 列は除去する。
  Future<void> _applyBodyPhotos(Map<String, dynamic> raw) async {
    final id = raw['id'] as String?;
    for (final entry in _photoFields.entries) {
      final pathKey = entry.key;
      final remoteKey = entry.value;
      final remote = raw.remove(remoteKey) as String?;
      if (kIsWeb || id == null || remote == null || remote.isEmpty) continue;
      final localPath = await _downloadBodyPhoto(remote, id, _dirOf(pathKey));
      if (localPath != null) raw[pathKey] = localPath;
    }
  }

  Future<String?> _downloadBodyPhoto(
      String storagePath, String id, String dir) async {
    try {
      final docs = await getApplicationDocumentsDirectory();
      final destDir = Directory('${docs.path}/body_photos');
      if (!await destDir.exists()) await destDir.create(recursive: true);
      final dest = File('${destDir.path}/${id}_$dir.jpg');
      // 既に取得済みなら再ダウンロードしない。
      if (await dest.exists()) return dest.path;

      final ref = storagePath.startsWith('http')
          ? FirebaseStorage.instance.refFromURL(storagePath)
          : FirebaseStorage.instance.ref(storagePath);
      await ref.writeToFile(dest);
      return dest.path;
    } catch (_) {
      return null;
    }
  }

  Future<void> _setRemote(
      String table, String id, Map<String, dynamic> payload) async {
    if (_userId == null) return;
    try {
      await _collection(table).doc(id).set(payload);
      flushPendingQueue();
    } catch (_) {
      await _enqueue({'op': 'set', 'table': table, 'id': id, 'data': payload});
    }
  }

  Future<void> _deleteRemote(String table, String id) async {
    if (_userId == null) return;
    final tombstone = {
      _kDeleted: true,
      _kUpdatedAt: DateTime.now().millisecondsSinceEpoch,
    };
    try {
      await _collection(table).doc(id).set(tombstone, SetOptions(merge: true));
      flushPendingQueue();
    } catch (_) {
      await _enqueue({
        'op': 'delete',
        'table': table,
        'id': id,
        'data': tombstone,
      });
    }
  }

  // ── オフライン再送キュー ───────────────────────────────────────────────────

  List<Map<String, dynamic>> _readQueue(SharedPreferences prefs) {
    final raw = prefs.getString(_queueKey);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _enqueue(Map<String, dynamic> op) async {
    final prefs = await SharedPreferences.getInstance();
    final list = _readQueue(prefs);
    op['uid'] = _userId;
    list.add(op);
    // 暴走防止に上限を設ける。
    if (list.length > 2000) {
      list.removeRange(0, list.length - 2000);
    }
    await prefs.setString(_queueKey, jsonEncode(list));
  }

  /// 未送信の書き込み/削除を再送する。オンライン復帰時・起動時・ログイン時に呼ぶ。
  Future<void> flushPendingQueue() async {
    if (_userId == null || _flushing) return;
    _flushing = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _readQueue(prefs);
      if (list.isEmpty) return;

      final remaining = <Map<String, dynamic>>[];
      for (final op in list) {
        // 別ユーザーの残骸は破棄する。
        if (op['uid'] != _userId) continue;
        try {
          await _applyOp(op);
        } catch (_) {
          remaining.add(op); // 失敗分は次回へ持ち越す。
        }
      }
      await prefs.setString(_queueKey, jsonEncode(remaining));
    } finally {
      _flushing = false;
    }
  }

  Future<void> _applyOp(Map<String, dynamic> op) async {
    final table = op['table'] as String;
    final id = op['id'] as String;
    final data = op['data'] is Map
        ? Map<String, dynamic>.from(op['data'] as Map)
        : <String, dynamic>{};
    if (op['op'] == 'set') {
      await _collection(table).doc(id).set(data);
    } else if (op['op'] == 'delete') {
      await _collection(table).doc(id).set(data, SetOptions(merge: true));
    }
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
