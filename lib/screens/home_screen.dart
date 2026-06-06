import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/badge_definitions.dart';
import '../providers/achievement_provider.dart';
import '../providers/home_fab_provider.dart';
import '../providers/home_tab_provider.dart';
import '../providers/sleep_provider.dart';
import '../providers/steps_provider.dart';
import '../providers/water_provider.dart';
import '../services/notification_service.dart';
import '../widgets/badge_unlock_dialog.dart';
import '../widgets/bewell_logo.dart';
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

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  static const _tabTitles = ['ホーム', '食事', 'トレーニング', '進捗'];

  static const List<Widget> _screens = [
    DashboardScreen(),
    MealScreen(),
    TrainingScreen(),
    ProgressScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    onWaterIntakeRecordedFromNotification = _flushWaterIntakes;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(ref.read(sleepProvider.notifier).syncOnDashboardVisible());
      unawaited(ref.read(stepsProvider.notifier).syncOnDashboardVisible());
      _flushWaterIntakes();
    });
  }

  @override
  void dispose() {
    if (onWaterIntakeRecordedFromNotification == _flushWaterIntakes) {
      onWaterIntakeRecordedFromNotification = null;
    }
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _flushWaterIntakes();
    }
  }

  void _flushWaterIntakes() {
    if (!mounted) return;
    unawaited(ref.read(waterProvider.notifier).flushPendingNotificationIntakes());
  }

  Future<void> _refreshDashboard() async {
    await Future.wait([
      ref.read(sleepProvider.notifier).syncOnDashboardVisible(),
      ref.read(stepsProvider.notifier).syncOnDashboardVisible(),
    ]);
  }

  PreferredSizeWidget _buildAppBar(int selectedIndex) {
    final scheme = Theme.of(context).colorScheme;
    final isHome = selectedIndex == 0;
    final dateStr = DateFormat('M月d日 EEEE', 'ja').format(DateTime.now());

    return AppBar(
      automaticallyImplyLeading: false,
      title: isHome
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const BeWellLogo(size: 24, showLabel: true),
                Text(
                  dateStr,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ],
            )
          : Text(_tabTitles[selectedIndex]),
      actions: [
        if (selectedIndex == 0)
          IconButton.filledTonal(
            onPressed: _refreshDashboard,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: '更新',
          ),
        if (selectedIndex == 2) const TrainingAppBarActions(),
        IconButton(
          icon: const Icon(Icons.account_circle_outlined),
          tooltip: 'プロフィール設定',
          onPressed: () {
            HapticFeedback.lightImpact();
            _scaffoldKey.currentState?.openEndDrawer();
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = ref.watch(homeTabIndexProvider);
    final fabConfig = ref.watch(homeFabProvider);

    ref.listen<int>(homeTabIndexProvider, (_, __) {
      ref.read(homeFabProvider.notifier).clear();
    });

    ref.listen<AchievementState>(achievementProvider, (prev, next) {
      if (next.newlyUnlocked.isEmpty) return;
      final unlockedKeys = List<String>.from(next.newlyUnlocked);
      ref.read(achievementProvider.notifier).clearNewlyUnlocked();

      final defs = unlockedKeys
          .map((k) {
            final def = allBadges.firstWhere(
              (b) => b.key == k,
              orElse: () => allBadges.first,
            );
            return def.key == k ? def : null;
          })
          .whereType<BadgeDefinition>()
          .toList();
      if (defs.isEmpty) return;

      HapticFeedback.mediumImpact();
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
      appBar: _buildAppBar(selectedIndex),
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
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
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
      floatingActionButton: fabConfig == null
          ? null
          : FloatingActionButton(
              onPressed: fabConfig.onPressed,
              tooltip: fabConfig.tooltip,
              child: Icon(fabConfig.icon),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}
