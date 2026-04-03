import 'package:riverpod/legacy.dart';

/// Bottom navigation index shared with [DashboardScreen] for deep links.
final homeTabIndexProvider = StateProvider<int>((ref) => 0);
