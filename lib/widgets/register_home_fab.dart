import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/home_fab_provider.dart';
import '../providers/home_tab_provider.dart';

/// 指定タブ表示中のみ [HomeScreen] の FAB を登録する。
class RegisterHomeFab extends ConsumerStatefulWidget {
  const RegisterHomeFab({
    super.key,
    required this.tabIndex,
    required this.config,
    required this.child,
  });

  final int tabIndex;
  final HomeFabConfig config;
  final Widget child;

  @override
  ConsumerState<RegisterHomeFab> createState() => _RegisterHomeFabState();
}

class _RegisterHomeFabState extends ConsumerState<RegisterHomeFab> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncFab();
  }

  @override
  void didUpdateWidget(RegisterHomeFab oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncFab();
  }

  @override
  void dispose() {
    if (ref.read(homeTabIndexProvider) == widget.tabIndex) {
      ref.read(homeFabProvider.notifier).clear();
    }
    super.dispose();
  }

  void _syncFab() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (ref.read(homeTabIndexProvider) != widget.tabIndex) return;
      ref.read(homeFabProvider.notifier).register(widget.config);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
