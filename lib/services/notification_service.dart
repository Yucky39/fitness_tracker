import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

/// 水分リマインダー通知のアクションボタンが押されたとき、
/// メイン isolate 側へ「保留中の水分記録があるよ」と伝えるためのコールバック。
///
/// アプリ前面時は即座に UI へ反映したいので、登録側（`HomeScreen`）が
/// ここに反映処理を差し込む。アプリ終了／背面時は別 isolate で
/// [_recordWaterIntakeFromAction] が SharedPreferences に積むだけなので、
/// 復帰時に改めてフラッシュする。
void Function()? onWaterIntakeRecordedFromNotification;

/// バックグラウンド／アプリ終了中に通知アクションが押されたときに呼ばれる
/// トップレベルのエントリポイント。別 isolate で実行されるため、
/// プラグインを使う前に [DartPluginRegistrant.ensureInitialized] が必要。
@pragma('vm:entry-point')
void notificationActionBackgroundHandler(NotificationResponse response) {
  DartPluginRegistrant.ensureInitialized();
  // void コールバックだが SharedPreferences への書き込みは非同期。
  // 短時間で完了する書き込みのため fire-and-forget で問題ない。
  NotificationService.handleActionResponse(response);
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  // ── 水分リマインダー関連の定数 ──────────────────────────────
  /// 通知アクションで選べる水分量（ml）。LINE のクイック返信のように
  /// 通知上のボタンから直接記録できる。ここを編集すれば候補を変えられる。
  static const List<int> waterQuickAmountsMl = [100, 200, 300, 500];

  /// アクション ID の接頭辞。`water_intake_250` のように量を埋め込む。
  static const String _waterActionPrefix = 'water_intake_';

  /// iOS の通知カテゴリ ID（アクションの束を識別する）。
  static const String _waterCategoryId = 'water_intake_reminder';

  /// バックグラウンド isolate からも書き込む、未反映の水分記録キュー。
  /// 各要素は `"<ml>|<ISO8601>"` 形式。
  static const String pendingWaterIntakesKey = 'pendingWaterIntakes';

  Future<void> initialize() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    final darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      notificationCategories: [
        DarwinNotificationCategory(
          _waterCategoryId,
          actions: [
            for (final ml in waterQuickAmountsMl)
              DarwinNotificationAction.plain(
                '$_waterActionPrefix$ml',
                '${ml}ml',
              ),
          ],
        ),
      ],
    );
    final settings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
    );
    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: _onForegroundResponse,
      onDidReceiveBackgroundNotificationResponse:
          notificationActionBackgroundHandler,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  /// アプリ前面で通知アクションがタップされたとき。
  static void _onForegroundResponse(NotificationResponse response) {
    final amount = _amountFromActionId(response.actionId);
    if (amount == null) return;
    handleActionResponse(response).then((_) {
      onWaterIntakeRecordedFromNotification?.call();
    });
  }

  /// 前面・背面共通で、通知アクションから水分記録を保留キューへ積む。
  static Future<void> handleActionResponse(NotificationResponse response) async {
    final amount = _amountFromActionId(response.actionId);
    if (amount == null) return;
    await _enqueueWaterIntake(amount);
  }

  /// アクション ID（例: `water_intake_250`）から ml を取り出す。
  static int? _amountFromActionId(String? actionId) {
    if (actionId == null || !actionId.startsWith(_waterActionPrefix)) {
      return null;
    }
    final amount = int.tryParse(actionId.substring(_waterActionPrefix.length));
    if (amount == null || amount <= 0) return null;
    return amount;
  }

  static Future<void> _enqueueWaterIntake(int amountMl) async {
    final prefs = await SharedPreferences.getInstance();
    // 他 isolate（前面側）からの書き込みを取りこぼさないよう最新を読み直す。
    await prefs.reload();
    final list = prefs.getStringList(pendingWaterIntakesKey) ?? <String>[];
    list.add('$amountMl|${DateTime.now().toIso8601String()}');
    await prefs.setStringList(pendingWaterIntakesKey, list);
  }

  /// 水分リマインダー通知に付けるアクションボタン（Android）。
  List<AndroidNotificationAction> _waterAndroidActions() => [
        for (final ml in waterQuickAmountsMl)
          AndroidNotificationAction(
            '$_waterActionPrefix$ml',
            '${ml}ml',
            // アプリを前面に出さずバックグラウンドで記録する。
            showsUserInterface: false,
            // 記録したら通知を消す。
            cancelNotification: true,
          ),
      ];

  Future<void> scheduleDailyReminder({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
    List<AndroidNotificationAction>? androidActions,
    String? darwinCategoryId,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    final androidDetails = AndroidNotificationDetails(
      'fitness_tracker_reminders',
      'フィットネスリマインダー',
      channelDescription: '食事・トレーニングのリマインダー通知',
      importance: Importance.high,
      priority: Priority.high,
      actions: androidActions,
    );
    final details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(categoryIdentifier: darwinCategoryId),
    );

    await _plugin.zonedSchedule(
      id: id,
      scheduledDate: scheduled,
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      title: title,
      body: body,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> cancelAll() => _plugin.cancelAll();
  Future<void> cancel(int id) => _plugin.cancel(id: id);

  /// 端末側のスケジューリングが失敗しても、設定の保存や UI 反映を妨げないよう
  /// 例外はここで握りつぶしてログのみ出力する。
  Future<void> _trySchedule({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
    List<AndroidNotificationAction>? androidActions,
    String? darwinCategoryId,
  }) async {
    try {
      await scheduleDailyReminder(
        id: id,
        title: title,
        body: body,
        hour: hour,
        minute: minute,
        androidActions: androidActions,
        darwinCategoryId: darwinCategoryId,
      );
    } catch (e, st) {
      debugPrint('リマインダーのスケジュールに失敗しました (id=$id): $e\n$st');
    }
  }

  Future<void> rescheduleFromSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await cancelAll();

      if (prefs.getBool('mealReminderEnabled') ?? false) {
        await _trySchedule(
          id: 1,
          title: '食事記録のリマインダー',
          body: '今日の食事を記録しましょう！',
          hour: prefs.getInt('mealReminderHour') ?? 12,
          minute: prefs.getInt('mealReminderMinute') ?? 0,
        );
      }

      if (prefs.getBool('workoutReminderEnabled') ?? false) {
        await _trySchedule(
          id: 2,
          title: 'トレーニングのリマインダー',
          body: '今日のトレーニングを忘れずに！',
          hour: prefs.getInt('workoutReminderHour') ?? 18,
          minute: prefs.getInt('workoutReminderMinute') ?? 0,
        );
      }

      if (prefs.getBool('coachReminderEnabled') ?? false) {
        await _trySchedule(
          id: 3,
          title: '朝のコーチング',
          body: '睡眠と記録を踏まえた今日の一手が届いています。ホームで確認しましょう💪',
          hour: prefs.getInt('coachReminderHour') ?? 8,
          minute: prefs.getInt('coachReminderMinute') ?? 0,
        );
        await _trySchedule(
          id: 4,
          title: '今夜の振り返り',
          body: '今日1日の食事・トレ・睡眠を踏まえたコーチングを確認しましょう。',
          hour: 20,
          minute: 0,
        );
      }

      if (prefs.getBool('waterReminderEnabled') ?? false) {
        final intervalMinutes =
            prefs.getInt('waterReminderIntervalMinutes') ?? 60;
        final startHour = prefs.getInt('waterReminderStartHour') ?? 8;
        final endHour = prefs.getInt('waterReminderEndHour') ?? 21;

        final androidActions = _waterAndroidActions();

        // 時間帯内の各スロットに通知をスケジュール（ID: 100〜）。
        // LINE のクイック返信のように、通知上のボタンから飲んだ量を選べる。
        var id = 100;
        var currentMinutes = startHour * 60;
        final endMinutes = endHour * 60;
        while (currentMinutes <= endMinutes && id < 200) {
          await _trySchedule(
            id: id,
            title: '水分補給のリマインダー',
            body: 'お水は飲みましたか？下のボタンから飲んだ量を記録できます💧',
            hour: currentMinutes ~/ 60,
            minute: currentMinutes % 60,
            androidActions: androidActions,
            darwinCategoryId: _waterCategoryId,
          );
          currentMinutes += intervalMinutes;
          id++;
        }
      }
    } catch (e, st) {
      debugPrint('リマインダーの再スケジュールに失敗しました: $e\n$st');
    }
  }
}
