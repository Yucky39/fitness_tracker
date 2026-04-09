import 'package:flutter/material.dart';

/// コールドスタートおよび認証待ちなど、初期化中に表示する画面。
///
/// `assets/splash/loading.gif` は GIF アニメーション（[Image.asset] が再生）。
/// 見た目を変える場合は同パスにファイルを置き換えてください。
/// サンプル GIF を第三者配布物に使う場合は、各ライセンス（表示義務など）に従ってください。
class SplashScreen extends StatelessWidget {
  const SplashScreen({
    super.key,
    this.message = '初期化しています…',
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: Colors.teal,
      brightness: Brightness.dark,
    );

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              scheme.primaryContainer,
              scheme.surface,
              scheme.primary.withValues(alpha: 0.35),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),
              Icon(
                Icons.fitness_center_rounded,
                size: 56,
                color: scheme.onPrimaryContainer.withValues(alpha: 0.95),
              ),
              const SizedBox(height: 28),
              Image.asset(
                'assets/splash/loading.gif',
                width: 160,
                height: 160,
                gaplessPlayback: true,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return SizedBox(
                    width: 64,
                    height: 64,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: scheme.primary,
                    ),
                  );
                },
              ),
              const SizedBox(height: 32),
              Text(
                'Fitness Tracker',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurface.withValues(alpha: 0.75),
                    ),
              ),
              const Spacer(flex: 3),
            ],
          ),
        ),
      ),
    );
  }
}
