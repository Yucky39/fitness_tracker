import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// [HomeScreen] の FAB を各タブ画面から登録する。
class HomeFabConfig {
  const HomeFabConfig({
    required this.onPressed,
    this.tooltip = '追加',
    this.icon = Icons.add,
  });

  final VoidCallback onPressed;
  final String tooltip;
  final IconData icon;
}

class HomeFabNotifier extends Notifier<HomeFabConfig?> {
  @override
  HomeFabConfig? build() => null;

  void register(HomeFabConfig config) => state = config;

  void clear() => state = null;
}

final homeFabProvider =
    NotifierProvider<HomeFabNotifier, HomeFabConfig?>(HomeFabNotifier.new);
