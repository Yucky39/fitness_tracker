import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/legacy.dart';
import 'package:uuid/uuid.dart';

import '../models/training_log.dart';
import '../models/training_session_record.dart';
import '../services/database_service.dart';
import '../services/stretch_recommendation_service.dart';
import 'settings_provider.dart';
import 'subscription_provider.dart';

class TrainingSessionState {
  final List<TrainingSessionRecord> sessions;
  final bool isLoading;

  /// ストレッチ推奨を取得中のセッションID
  final String? fetchingStretchForId;

  /// エラーが発生したセッションID → エラーメッセージ
  final Map<String, String> stretchErrorById;

  const TrainingSessionState({
    this.sessions = const [],
    this.isLoading = true,
    this.fetchingStretchForId,
    this.stretchErrorById = const {},
  });

  TrainingSessionState copyWith({
    List<TrainingSessionRecord>? sessions,
    bool? isLoading,
    String? fetchingStretchForId,
    bool clearFetching = false,
    Map<String, String>? stretchErrorById,
  }) {
    return TrainingSessionState(
      sessions: sessions ?? this.sessions,
      isLoading: isLoading ?? this.isLoading,
      fetchingStretchForId: clearFetching
          ? null
          : (fetchingStretchForId ?? this.fetchingStretchForId),
      stretchErrorById: stretchErrorById ?? this.stretchErrorById,
    );
  }

  /// 指定日のセッション一覧（新しい順）
  List<TrainingSessionRecord> sessionsForDate(DateTime date) {
    return sessions.where((s) {
      final d = s.startedAt.toLocal();
      return d.year == date.year && d.month == date.month && d.day == date.day;
    }).toList()
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
  }
}

class TrainingSessionNotifier extends StateNotifier<TrainingSessionState> {
  TrainingSessionNotifier(this._ref) : super(const TrainingSessionState()) {
    _load();
  }

  final Ref _ref;
  static const _uuid = Uuid();

  Future<void> _load() async {
    state = state.copyWith(isLoading: true);
    final db = await DatabaseService().database;
    final rows = await db.query(
      'training_session_records',
      orderBy: 'started_at DESC',
    );
    state = state.copyWith(
      sessions: rows.map(TrainingSessionRecord.fromMap).toList(),
      isLoading: false,
    );
  }

  /// セッションを登録し、AIストレッチ推奨を非同期で取得する。
  Future<TrainingSessionRecord> addSession({
    required List<TrainingLog> logs,
    String? name,
    String? note,
    DateTime? startedAt,
    DateTime? finishedAt,
  }) async {
    final session = TrainingSessionRecord(
      id: _uuid.v4(),
      name: name,
      startedAt: startedAt ?? DateTime.now(),
      finishedAt: finishedAt,
      logIds: logs.map((l) => l.id).toList(),
      exerciseNames: logs.map((l) => l.exerciseName).toSet().toList(),
      note: note,
    );

    final db = await DatabaseService().database;
    await db.insert('training_session_records', session.toMap());

    state = state.copyWith(
      sessions: [session, ...state.sessions],
    );

    // ストレッチ推奨を非同期で取得
    _fetchStretch(session, logs);

    return session;
  }

  Future<void> _fetchStretch(
    TrainingSessionRecord session,
    List<TrainingLog> logs,
  ) async {
    if (logs.isEmpty) return;

    state = state.copyWith(fetchingStretchForId: session.id);

    try {
      final settings = _ref.read(settingsProvider);
      final isSubscribed = _ref.read(isSubscribedProvider);
      final useSystemAi = isSubscribed && settings.currentApiKey.isEmpty;

      final text = await StretchRecommendationService().getRecommendation(
        sessionLogs: logs,
        useSystemAi: useSystemAi,
        apiKey: settings.currentApiKey,
        provider: settings.selectedProvider,
        model: settings.currentModel,
      );

      await _updateStretchRecommendation(session.id, text);
    } catch (e) {
      final errors = Map<String, String>.from(state.stretchErrorById);
      errors[session.id] = e.toString();
      state = state.copyWith(
        clearFetching: true,
        stretchErrorById: errors,
      );
    }
  }

  Future<void> _updateStretchRecommendation(String id, String text) async {
    final db = await DatabaseService().database;
    await db.update(
      'training_session_records',
      {'stretch_recommendation': text},
      where: 'id = ?',
      whereArgs: [id],
    );

    final updatedSessions = state.sessions.map((s) {
      if (s.id == id) return s.copyWith(stretchRecommendation: text);
      return s;
    }).toList();

    state = state.copyWith(
      sessions: updatedSessions,
      clearFetching: true,
    );
  }

  /// ストレッチ推奨を再取得する
  Future<void> retryStretch(
    TrainingSessionRecord session,
    List<TrainingLog> allLogs,
  ) async {
    final errors = Map<String, String>.from(state.stretchErrorById)
      ..remove(session.id);
    state = state.copyWith(stretchErrorById: errors);

    final sessionLogs =
        allLogs.where((l) => session.logIds.contains(l.id)).toList();
    await _fetchStretch(session, sessionLogs);
  }

  Future<void> deleteSession(String id) async {
    final db = await DatabaseService().database;
    await db.delete(
      'training_session_records',
      where: 'id = ?',
      whereArgs: [id],
    );
    state = state.copyWith(
      sessions: state.sessions.where((s) => s.id != id).toList(),
    );
  }
}

final trainingSessionProvider =
    StateNotifierProvider<TrainingSessionNotifier, TrainingSessionState>(
  (ref) => TrainingSessionNotifier(ref),
);
