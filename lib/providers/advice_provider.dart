import 'package:riverpod/legacy.dart';
import '../models/food_item.dart';
import '../providers/settings_provider.dart';
import '../providers/subscription_provider.dart';
import '../services/nutrition_advice_service.dart';

class AdviceState {
  final String? adviceText;
  final bool isLoading;
  final String? error;

  const AdviceState({this.adviceText, this.isLoading = false, this.error});

  AdviceState copyWith({String? adviceText, bool? isLoading, String? error}) =>
      AdviceState(
        adviceText: adviceText ?? this.adviceText,
        isLoading: isLoading ?? this.isLoading,
        error: error ?? this.error,
      );
}

class AdviceNotifier extends StateNotifier<AdviceState> {
  final Ref _ref;
  AdviceNotifier(this._ref) : super(const AdviceState());

  final _service = NutritionAdviceService();
  String? _cachedKey;

  String _cacheKey(
    List<FoodItem> items,
    String adviceLevel,
    bool useSystemAi,
    AiProviderType provider,
    String model,
  ) {
    final totalCal = items.fold(0, (s, i) => s + i.calories);
    final totalP = items.fold(0.0, (s, i) => s + i.protein);
    final totalF = items.fold(0.0, (s, i) => s + i.fat);
    final totalC = items.fold(0.0, (s, i) => s + i.carbs);
    return '${items.length}_${totalCal}_'
        '${totalP.toStringAsFixed(1)}_'
        '${totalF.toStringAsFixed(1)}_'
        '${totalC.toStringAsFixed(1)}_'
        '${adviceLevel}_${useSystemAi ? 'system' : '${provider.name}_$model'}';
  }

  Future<void> fetchAdvice({
    required List<FoodItem> items,
    required DateTime date,
    required int calorieGoal,
    required double proteinGoal,
    required double fatGoal,
    required double carbsGoal,
    double fiberGoal = 25,
    double sodiumGoal = 2300,
    required String adviceLevel,
    bool forceRefresh = false,
  }) async {
    final isSubscribed = _ref.read(isSubscribedProvider);
    final settings = _ref.read(settingsProvider);
    final apiKey = settings.currentApiKey;
    final provider = settings.selectedProvider;
    final model = settings.currentModel;

    // サブスク未加入 かつ APIキー未設定
    if (!isSubscribed && apiKey.isEmpty) {
      state = const AdviceState(error: '__paywall__');
      return;
    }

    final resolvedModel = model.isNotEmpty ? model : provider.defaultModel;
    final key = _cacheKey(items, adviceLevel, isSubscribed, provider, resolvedModel);
    if (!forceRefresh && key == _cachedKey && state.adviceText != null) {
      return;
    }

    state = const AdviceState(isLoading: true);
    try {
      final text = await _service.getAdvice(
        items: items,
        date: date,
        calorieGoal: calorieGoal,
        proteinGoal: proteinGoal,
        fatGoal: fatGoal,
        carbsGoal: carbsGoal,
        fiberGoal: fiberGoal,
        sodiumGoal: sodiumGoal,
        adviceLevel: adviceLevel,
        useSystemAi: isSubscribed,
        apiKey: apiKey,
        provider: provider,
        model: resolvedModel,
      );
      _cachedKey = key;
      state = AdviceState(adviceText: text);
    } catch (e) {
      state = AdviceState(error: e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void clear() {
    _cachedKey = null;
    state = const AdviceState();
  }
}

final adviceProvider =
    StateNotifierProvider<AdviceNotifier, AdviceState>(
  (ref) => AdviceNotifier(ref),
);
