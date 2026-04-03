import 'package:riverpod/legacy.dart';
import '../models/food_item.dart';
import '../providers/settings_provider.dart';
import '../services/nutrition_advice_service.dart';

class AdviceState {
  final String? adviceText;
  final bool isLoading;
  final String? error;

  const AdviceState({this.adviceText, this.isLoading = false, this.error});

  AdviceState copyWith({String? adviceText, bool? isLoading, String? error}) => AdviceState(
        adviceText: adviceText ?? this.adviceText,
        isLoading: isLoading ?? this.isLoading,
        error: error ?? this.error,
      );
}

class AdviceNotifier extends StateNotifier<AdviceState> {
  AdviceNotifier() : super(const AdviceState());

  final _service = NutritionAdviceService();
  String? _cachedKey;

  String _cacheKey(
    List<FoodItem> items,
    String adviceLevel,
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
        '${adviceLevel}_${provider.name}_$model';
  }

  Future<void> fetchAdvice({
    required List<FoodItem> items,
    required DateTime date,
    required int calorieGoal,
    required double proteinGoal,
    required double fatGoal,
    required double carbsGoal,
    required String adviceLevel,
    required String apiKey,
    required AiProviderType provider,
    String? model,
    bool forceRefresh = false,
  }) async {
    if (apiKey.isEmpty) {
      state = AdviceState(
        error: '${provider.label} のAPIキーが設定されていません。⚙️設定から入力してください。',
      );
      return;
    }

    final resolvedModel = model ?? provider.defaultModel;
    final key = _cacheKey(items, adviceLevel, provider, resolvedModel);
    if (!forceRefresh && key == _cachedKey && state.adviceText != null) {
      // キャッシュヒット — 食事内容が変わっていないため再取得をスキップ
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
        adviceLevel: adviceLevel,
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

final adviceProvider = StateNotifierProvider<AdviceNotifier, AdviceState>(
  (_) => AdviceNotifier(),
);
