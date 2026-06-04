import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/legacy.dart';

import '../services/body_progress_advice_service.dart';
import 'ai_access.dart';
import 'energy_profile_provider.dart';
import 'progress_provider.dart';
import 'settings_provider.dart';

class BodyProgressAdviceState {
  final String? advice;
  final bool isLoading;
  final String? error;

  const BodyProgressAdviceState({
    this.advice,
    this.isLoading = false,
    this.error,
  });

  BodyProgressAdviceState copyWith({
    String? advice,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) =>
      BodyProgressAdviceState(
        advice: advice ?? this.advice,
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : (error ?? this.error),
      );
}

class BodyProgressAdviceNotifier
    extends StateNotifier<BodyProgressAdviceState> {
  BodyProgressAdviceNotifier(this._ref)
      : super(const BodyProgressAdviceState());

  final Ref _ref;
  final _service = BodyProgressAdviceService();

  Future<void> generate() async {
    final metrics = _ref.read(progressProvider).metrics;
    if (metrics.length < 2) {
      state = state.copyWith(
        error: '記録が2件以上あると、体型の変化を講評できます。',
      );
      return;
    }

    final access = _ref.read(aiAccessProvider);
    if (!access.allowed) {
      state = state.copyWith(error: '__paywall__');
      return;
    }

    final settings = _ref.read(settingsProvider);
    final energy = _ref.read(energyProfileProvider);
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final text = await _service.getAdvice(
        metrics: metrics,
        targetWeightKg:
            energy.targetWeightKg > 0 ? energy.targetWeightKg : null,
        adviceLevel: settings.adviceLevel,
        useSystemAi: access.useSystemAi,
        apiKey: settings.currentApiKey,
        provider: settings.selectedProvider,
        model: settings.currentModel.isNotEmpty
            ? settings.currentModel
            : settings.selectedProvider.defaultModel,
      );
      state = state.copyWith(
        advice: text.trim(),
        isLoading: false,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  void clear() => state = const BodyProgressAdviceState();
}

final bodyProgressAdviceProvider = StateNotifierProvider<
    BodyProgressAdviceNotifier, BodyProgressAdviceState>(
  (ref) => BodyProgressAdviceNotifier(ref),
);
