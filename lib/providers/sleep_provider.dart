import 'package:riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/sleep_log.dart';
import '../services/database_service.dart';
import '../services/health_service.dart';

/// 昨夜の睡眠データと睡眠評価を保持する状態
class SleepState {
  /// 昨夜の睡眠時間（分）。null = 未取得またはデータなし
  final int? sleepMinutes;
  final bool isLoading;
  final bool isSupported;
  final bool permissionGranted;
  /// 過去14日間の睡眠履歴
  final List<SleepLog> recentLogs;
  /// 睡眠目標（分）
  final int goalMinutes;

  const SleepState({
    this.sleepMinutes,
    this.isLoading = false,
    this.isSupported = true,
    this.permissionGranted = false,
    this.recentLogs = const [],
    this.goalMinutes = 420,
  });

  /// 睡眠時間（時間部分）
  int get hours => (sleepMinutes ?? 0) ~/ 60;

  /// 睡眠時間（分部分）
  int get minutes => (sleepMinutes ?? 0) % 60;

  /// 睡眠品質の評価
  SleepQuality get quality {
    final total = sleepMinutes ?? 0;
    if (total <= 0) return SleepQuality.unknown;
    if (total >= 420) return SleepQuality.good;   // 7時間以上
    if (total >= 360) return SleepQuality.fair;   // 6〜7時間
    return SleepQuality.poor;                      // 6時間未満
  }

  /// AIアドバイスに渡す睡眠情報テキスト（未取得時は null）
  String? get adviceContext {
    if (sleepMinutes == null) return null;
    return '昨夜の睡眠: ${hours}時間${minutes}分（${quality.label}）';
  }

  SleepState copyWith({
    int? sleepMinutes,
    bool clearSleep = false,
    bool? isLoading,
    bool? isSupported,
    bool? permissionGranted,
    List<SleepLog>? recentLogs,
    int? goalMinutes,
  }) =>
      SleepState(
        sleepMinutes: clearSleep ? null : (sleepMinutes ?? this.sleepMinutes),
        isLoading: isLoading ?? this.isLoading,
        isSupported: isSupported ?? this.isSupported,
        permissionGranted: permissionGranted ?? this.permissionGranted,
        recentLogs: recentLogs ?? this.recentLogs,
        goalMinutes: goalMinutes ?? this.goalMinutes,
      );
}

enum SleepQuality {
  good,
  fair,
  poor,
  unknown;

  String get label {
    switch (this) {
      case SleepQuality.good:
        return '良好';
      case SleepQuality.fair:
        return 'やや不足';
      case SleepQuality.poor:
        return '不足';
      case SleepQuality.unknown:
        return '不明';
    }
  }

  String get emoji {
    switch (this) {
      case SleepQuality.good:
        return '😴';
      case SleepQuality.fair:
        return '🥱';
      case SleepQuality.poor:
        return '😵';
      case SleepQuality.unknown:
        return '—';
    }
  }
}

class SleepNotifier extends StateNotifier<SleepState> {
  SleepNotifier() : super(const SleepState()) {
    _loadGoal();
    if (!HealthService.isSupported) {
      state = const SleepState(isSupported: false);
    } else {
      _autoFetch();
    }
  }

  static const _uuid = Uuid();

  /// 起動時・ダッシュボード表示時：権限を自動リクエストしてデータ取得。
  /// iOS では既に決定済みの場合ダイアログは表示されない。
  Future<void> _autoFetch() async {
    await HealthService.requestPermissions(); // 歩数・睡眠・ワークアウトをまとめてリクエスト
    await _fetchSleep(granted: true);
  }

  /// ホーム（ダッシュボード）を開いたとき・更新したときに呼ぶ。
  /// 権限を再確認し、許可済みなら最新の睡眠データを取得する。
  Future<void> syncOnDashboardVisible() async {
    if (!state.isSupported) return;
    await _autoFetch();
  }

  /// 「睡眠を連携」ボタンのタップ時に呼ぶ
  ///
  /// iOS HealthKit では requestAuthorization の戻り値が信頼できない
  /// （一度拒否後は false を返す）ため、戻り値に関わらずデータ取得を試みる。
  /// データが取得できれば true、できなければ false を返す。
  Future<bool> requestAndFetch() async {
    state = state.copyWith(isLoading: true);
    final authRequested = await HealthService.requestPermissions();
    await _fetchSleep(granted: true);
    // iOS HealthKit は権限拒否でも authRequested が true を返すことがある。
    // データ取得を試みた結果で判定する:
    // - データあり → 明らかに許可済み → true
    // - データなし & authRequested=false → 拒否された可能性 → false
    // - データなし & authRequested=true → 単純にデータなし → true
    if (state.sleepMinutes == null && !authRequested) {
      return false;
    }
    return true;
  }

  /// 手動リフレッシュ
  Future<void> refresh() async {
    if (!state.permissionGranted) return;
    await _fetchSleep(granted: true);
  }

  Future<void> _loadGoal() async {
    final prefs = await SharedPreferences.getInstance();
    final goal = prefs.getInt('sleepGoalMinutes') ?? 420;
    state = state.copyWith(goalMinutes: goal);
  }

  Future<void> setGoal(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('sleepGoalMinutes', minutes);
    state = state.copyWith(goalMinutes: minutes);
  }

  Future<void> _fetchSleep({required bool granted}) async {
    state = state.copyWith(isLoading: true, permissionGranted: granted);
    final minutes = await HealthService.fetchLastNightSleepMinutes();

    // 取得できた場合は sleep_logs に upsert（日付ベース）
    if (minutes != null && minutes > 0) {
      await _persistSleepLog(minutes);
    }

    // 14日間履歴をロード
    final recentLogs = await _load14DayLogs();

    state = SleepState(
      sleepMinutes: minutes,
      isLoading: false,
      isSupported: state.isSupported,
      permissionGranted: granted,
      recentLogs: recentLogs,
      goalMinutes: state.goalMinutes,
    );
  }

  Future<void> _persistSleepLog(int minutes) async {
    try {
      final adapter = await DatabaseService().database;
      final today = DateTime.now();
      final dateKey = DateTime(today.year, today.month, today.day)
          .toIso8601String();

      // 既存レコードを確認（upsert）
      final existing = await adapter.query(
        'sleep_logs',
        where: 'date = ?',
        whereArgs: [dateKey],
        limit: 1,
      );

      if (existing.isEmpty) {
        await adapter.insert('sleep_logs', {
          'id': _uuid.v4(),
          'date': dateKey,
          'duration_m': minutes,
          'source': 'health',
        });
      } else {
        await adapter.update(
          'sleep_logs',
          {'duration_m': minutes},
          where: 'date = ?',
          whereArgs: [dateKey],
        );
      }
    } catch (_) {
      // 永続化失敗はサイレントに無視
    }
  }

  Future<List<SleepLog>> _load14DayLogs() async {
    try {
      final adapter = await DatabaseService().database;
      final since = DateTime.now()
          .subtract(const Duration(days: 14))
          .toIso8601String();
      final maps = await adapter.query(
        'sleep_logs',
        where: 'date >= ?',
        whereArgs: [since],
        orderBy: 'date ASC',
      );
      return maps.map(SleepLog.fromMap).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> load14DayTrend() async {
    final logs = await _load14DayLogs();
    state = state.copyWith(recentLogs: logs);
  }
}

final sleepProvider =
    StateNotifierProvider<SleepNotifier, SleepState>((_) => SleepNotifier());
