import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/badge_definitions.dart';
import '../providers/achievement_provider.dart';
import '../providers/home_tab_provider.dart';
import '../providers/sleep_provider.dart';
import '../providers/steps_provider.dart';
import '../widgets/badge_unlock_dialog.dart';
import 'achievements_screen.dart';
import 'dashboard_screen.dart';
import 'meal_screen.dart';
import 'profile_sidebar.dart';
import 'progress_screen.dart';
import 'training_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  static const List<Widget> _screens = [
    DashboardScreen(),
    MealScreen(),
    TrainingScreen(),
    ProgressScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // ダッシュボード初期表示時に睡眠・歩数を自動同期
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(ref.read(sleepProvider.notifier).syncOnDashboardVisible());
      unawaited(ref.read(stepsProvider.notifier).syncOnDashboardVisible());
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = ref.watch(homeTabIndexProvider);

    ref.listen<AchievementState>(achievementProvider, (prev, next) {
      if (next.newlyUnlocked.isEmpty) return;
      final unlockedKeys = List<String>.from(next.newlyUnlocked);
      // 先に state をクリアしてダイアログ閉じ → 再発火の二重表示を防ぐ
      ref.read(achievementProvider.notifier).clearNewlyUnlocked();

      final defs = unlockedKeys
          .map((k) {
            final def =
                allBadges.firstWhere((b) => b.key == k, orElse: () => allBadges.first);
            return def.key == k ? def : null;
          })
          .whereType<BadgeDefinition>()
          .toList();
      if (defs.isEmpty) return;

      HapticFeedback.mediumImpact();
      // 現在のビルドフレーム後に表示（listen 内で push すると警告になるため）
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(
          showBadgeUnlockedDialog(
            context,
            badges: defs,
            onViewAll: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const AchievementsScreen(),
                ),
              );
            },
          ),
        );
      });
    });

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Fitness Tracker'),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle_outlined),
            tooltip: 'プロフィール設定',
            onPressed: () {
              HapticFeedback.lightImpact();
              _scaffoldKey.currentState?.openEndDrawer();
            },
          ),
        ],
      ),
      endDrawer: ProfileSidebar(scaffoldKey: _scaffoldKey),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, animation) {
          final slideAnim = Tween<Offset>(
            begin: const Offset(0.04, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          ));
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(position: slideAnim, child: child),
          );
        },
        child: KeyedSubtree(
          key: ValueKey<int>(selectedIndex),
          child: _screens[selectedIndex],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        onDestinationSelected: (index) {
          if (index == selectedIndex) return;
          HapticFeedback.selectionClick();
          ref.read(homeTabIndexProvider.notifier).state = index;
          if (index == 0) {
            unawaited(ref.read(sleepProvider.notifier).syncOnDashboardVisible());
            unawaited(ref.read(stepsProvider.notifier).syncOnDashboardVisible());
          }
        },
        selectedIndex: selectedIndex,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'ホーム',
          ),
          NavigationDestination(
            icon: Icon(Icons.restaurant_outlined),
            selectedIcon: Icon(Icons.restaurant),
            label: '食事',
          ),
          NavigationDestination(
            icon: Icon(Icons.fitness_center_outlined),
            selectedIcon: Icon(Icons.fitness_center),
            label: 'トレーニング',
          ),
          NavigationDestination(
            icon: Icon(Icons.show_chart_outlined),
            selectedIcon: Icon(Icons.show_chart),
            label: '進捗',
          ),
        ],
      ),
    );
  }
}
