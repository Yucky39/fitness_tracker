import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/splash_screen.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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

  @override
  void initState() {
    super.initState();
    _splashStartedAt = DateTime.now();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
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
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    tz.initializeTimeZones();
    try {
      final tzInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(tzInfo.identifier));
    } catch (_) {
      // Fallback to UTC if timezone detection fails
    }

    await NotificationService().initialize();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fitness Tracker',
      debugShowCheckedModeBanner: false,
      theme: _appLightTheme(),
      darkTheme: _appDarkTheme(),
      themeMode: ThemeMode.system,
      home: _ready ? const AuthGate() : const SplashScreen(),
    );
  }
}

ThemeData _appLightTheme() {
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.teal,
      brightness: Brightness.light,
    ),
    fontFamily: 'Roboto',
    cardTheme: CardThemeData(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
    ),
    // サムフレンドリー: FilledButton の最小タッチターゲットを 48dp に統一
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 48),
      ),
    ),
    // IconButton は Material3 デフォルト 48dp だが明示的に設定
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: const Size(48, 48),
      ),
    ),
  );
}

ThemeData _appDarkTheme() {
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.teal,
      brightness: Brightness.dark,
    ),
    fontFamily: 'Roboto',
    cardTheme: CardThemeData(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 48),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: const Size(48, 48),
      ),
    ),
  );
}

class FitnessTrackerApp extends StatelessWidget {
  const FitnessTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fitness Tracker',
      theme: _appLightTheme(),
      darkTheme: _appDarkTheme(),
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
