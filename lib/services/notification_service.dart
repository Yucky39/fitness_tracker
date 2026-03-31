import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
    );
    await _plugin.initialize(settings);
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  Future<void> scheduleDailyReminder({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    const androidDetails = AndroidNotificationDetails(
      'fitness_tracker_reminders',
      'フィットネスリマインダー',
      channelDescription: '食事・トレーニングのリマインダー通知',
      importance: Importance.high,
      priority: Priority.high,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduled,
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> cancelAll() => _plugin.cancelAll();
  Future<void> cancel(int id) => _plugin.cancel(id);

  Future<void> rescheduleFromSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await cancelAll();

    if (prefs.getBool('mealReminderEnabled') ?? false) {
      await scheduleDailyReminder(
        id: 1,
        title: '食事記録のリマインダー',
        body: '今日の食事を記録しましょう！',
        hour: prefs.getInt('mealReminderHour') ?? 12,
        minute: prefs.getInt('mealReminderMinute') ?? 0,
      );
    }

    if (prefs.getBool('workoutReminderEnabled') ?? false) {
      await scheduleDailyReminder(
        id: 2,
        title: 'トレーニングのリマインダー',
        body: '今日のトレーニングを忘れずに！',
        hour: prefs.getInt('workoutReminderHour') ?? 18,
        minute: prefs.getInt('workoutReminderMinute') ?? 0,
      );
    }
  }
}
