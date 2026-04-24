import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/legacy.dart';

import '../providers/energy_profile_provider.dart';
import '../services/health_service.dart';
import 'achievement_provider.dart';

/// 歩数の計測データと推定消費カロリーを保持する状態
class StepsState {
  final int steps;
  final int burnedKcal;
  final bool isLoading;
  final bool isSupported;
  final bool permissionGranted;

  const StepsState({
    this.steps = 0,
    this.burnedKcal = 0,
    this.isLoading = false,
    this.isSupported = true,
    this.permissionGranted = false,
  });

  StepsState copyWith({
    int? steps,
    int? burnedKcal,
    bool? isLoading,
    bool? isSupported,
    bool? permissionGranted,
  }) =>
      StepsState(
        steps: steps ?? this.steps,
        burnedKcal: burnedKcal ?? this.burnedKcal,
        isLoading: isLoading ?? this.isLoading,
        isSupported: isSupported ?? this.isSupported,
        permissionGranted: permissionGranted ?? this.permissionGranted,
      );
}

class StepsNotifier extends StateNotifier<StepsState> {
  final Ref _ref;

  StepsNotifier(this._ref) : super(const StepsState()) {
    if (!HealthService.isSupported) {
      state = const StepsState(isSupported: false);
    } else {
      _autoFetch();
    }
  }

  /// 起動時・ダッシュボード表示時：権限を自動リクエストしてデータ取得。
  /// iOS では既に決定済みの場合ダイアログは表示されない。
  Future<void> _autoFetch() async {
    await HealthService.requestPermissions(); // 歩数・睡眠・ワークアウトをまとめてリクエスト
    await _fetchSteps(granted: true);
  }

  /// ホーム（ダッシュボード）を開いたとき・更新したときに呼ぶ。
  /// 権限を再確認し、許可済みなら最新の歩数を取得する。
  Future<void> syncOnDashboardVisible() async {
    if (!state.isSupported) return;
    await _autoFetch();
  }

  /// ユーザーが「歩数を連携」ボタンをタップしたときに呼ぶ
  Future<bool> requestAndFetch() async {
    state = state.copyWith(isLoading: true);
    await HealthService.requestPermissions();
    await _fetchSteps(granted: true);
    final hasData = state.steps > 0;
    if (!hasData) return false;
    return true;
  }

  /// 権限済みの状態で歩数を取得・カロリーを計算してstateを更新
  Future<void> _fetchSteps({required bool granted}) async {
    state = state.copyWith(isLoading: true, permissionGranted: granted);
    final steps = await HealthService.fetchTodaySteps();
    if (steps == null) {
      state = state.copyWith(isLoading: false);
      return;
    }
    final kcal = _calcBurnedKcal(steps);
    state = state.copyWith(
      steps: steps,
      burnedKcal: kcal,
      isLoading: false,
    );
    // バッジ評価（歩数系・全体継続）
    unawaited(_ref.read(achievementProvider.notifier).onStepsUpdated(steps));
  }

  /// 歩数を手動リフレッシュ（権限はすでにある前提）
  Future<void> refresh() async {
    if (!state.permissionGranted) return;
    await _fetchSteps(granted: true);
  }

  /// 歩数 → 消費カロリー（kcal）
  ///
  /// 歩幅（m）= 身長(cm) × 0.415 / 100
  /// 距離(km) = 歩数 × 歩幅 / 1000
  /// 消費(kcal) = 距離(km) × 体重(kg) × 1.036
  ///
  /// 身長・体重が未設定（0）の場合は デフォルト値（身長170cm・体重65kg）を使用
  int _calcBurnedKcal(int steps) {
    final profile = _ref.read(energyProfileProvider);
    final heightCm = profile.heightCm > 0 ? profile.heightCm : 170.0;
    final weightKg = profile.weightKg > 0 ? profile.weightKg : 65.0;
    final strideLengthM = heightCm * 0.415 / 100;
    final distanceKm = steps * strideLengthM / 1000.0;
    final kcal = distanceKm * weightKg * 1.036;
    return kcal.round();
  }
}

final stepsProvider =
    StateNotifierProvider<StepsNotifier, StepsState>((ref) {
  return StepsNotifier(ref);
});
