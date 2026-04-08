import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/home_tab_provider.dart';
import '../providers/sleep_provider.dart';
import '../providers/steps_provider.dart';
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

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Fitness Tracker'),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle_outlined),
            tooltip: 'プロフィール設定',
            onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
          ),
        ],
      ),
      endDrawer: ProfileSidebar(scaffoldKey: _scaffoldKey),
      body: _screens[selectedIndex],
      bottomNavigationBar: NavigationBar(
        onDestinationSelected: (index) {
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
