import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/splash_screen.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'services/subscription_service.dart';
import 'services/sync_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // プラグイン／ネイティブが起動直後に触るため、スプラッシュ待ちより先に初期化する
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(
    const ProviderScope(
      child: _BootstrapApp(),
    ),
  );
}

/// 最初のフレームでスプラッシュを描画してからバックグラウンド初期化を行う。
class _BootstrapApp extends StatefulWidget {
  const _BootstrapApp();

  @override
  State<_BootstrapApp> createState() => _BootstrapAppState();
}

class _BootstrapAppState extends State<_BootstrapApp> {
  var _ready = false;
  late final DateTime _splashStartedAt;

  // 課金反映の成否を画面下部のスナックバーで知らせるためのキー。
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  StreamSubscription<SubscriptionActivationEvent>? _activationSub;

  @override
  void initState() {
    super.initState();
    _splashStartedAt = DateTime.now();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    _activationSub?.cancel();
    super.dispose();
  }

  void _listenActivationEvents() {
    _activationSub?.cancel();
    _activationSub = SubscriptionService().activationEvents.listen((event) {
      if (!mounted) return;
      final messenger = _messengerKey.currentState;
      if (messenger == null) return;
      final isError =
          event.status == SubscriptionActivationStatus.failed;
      messenger
        ..clearSnackBars()
        ..showSnackBar(SnackBar(
          content: Text(event.message),
          duration: Duration(seconds: isError ? 8 : 4),
          backgroundColor: isError
              ? Theme.of(context).colorScheme.errorContainer
              : null,
        ));
    });
  }

  /// GIF のデコードと本体初期化を並行し、スプラッシュ開始から最低 [_minSplashDuration] は表示する。
  Future<void> _bootstrap() async {
    const minSplash = Duration(milliseconds: 2400);

    await Future.wait([
      splashGifPrecacheCompleter.future.timeout(
        const Duration(seconds: 6),
        onTimeout: () {},
      ),
      _runCoreInit(),
    ]);

    final elapsed = DateTime.now().difference(_splashStartedAt);
    if (elapsed < minSplash) {
      await Future.delayed(minSplash - elapsed);
    }

    if (!mounted) return;
    setState(() => _ready = true);
  }

  Future<void> _runCoreInit() async {
    await initializeDateFormatting('ja');

    tz.initializeTimeZones();
    try {
      final tzInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(tzInfo.identifier));
    } catch (_) {
      // Fallback to UTC if timezone detection fails
    }

    await NotificationService().initialize();
    // アプリ更新前にスケジュールされた水分リマインダーは、アクションボタン
    // （カテゴリ）が未設定のまま `matchDateTimeComponents` で毎日繰り返し配信
    // され続ける。設定画面を開き直さない限り再登録されないため、起動時に必ず
    // 再スケジュールして、古い通知を最新のアクション付きへ置き換える。
    await NotificationService().rescheduleFromSettings();
    SubscriptionService().initialize();
    _listenActivationEvents();

    // ログイン済み（セッション復元含む）になったら未送信の同期キューを再送する。
    AuthService().authStateChanges.listen((user) {
      if (user != null) {
        SyncService().flushPendingQueue();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BeWell',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: _messengerKey,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      home: _ready ? const AuthGate() : const SplashScreen(),
    );
  }
}

class FitnessTrackerApp extends StatelessWidget {
  const FitnessTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BeWell',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      home: const AuthGate(),
    );
  }
}

/// Watches Firebase auth state and routes to either AuthScreen or HomeScreen.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final onboardingDone = ref.watch(_onboardingProvider);

    return authState.when(
      loading: () => const SplashScreen(
        message: 'ログイン状態を確認しています…',
      ),
      error: (_, __) => const AuthScreen(),
      data: (user) {
        if (user == null) return const AuthScreen();
        return onboardingDone.when(
          loading: () => const SplashScreen(),
          error: (_, __) => const HomeScreen(),
          data: (done) => done ? const HomeScreen() : const OnboardingScreen(),
        );
      },
    );
  }
}

final _onboardingProvider = FutureProvider<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool('onboardingComplete') ?? false;
});
