import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/food_item.dart';
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

  Future<void> fetchAdvice({
    required List<FoodItem> items,
    required DateTime date,
    required int calorieGoal,
    required double proteinGoal,
    required double fatGoal,
    required double carbsGoal,
    required String adviceLevel,
    required String apiKey,
  }) async {
    if (apiKey.isEmpty) {
      state = const AdviceState(
        error: 'APIキーが設定されていません。⚙️設定から「Anthropic APIキー」を入力してください。',
      );
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
      );
      state = AdviceState(adviceText: text);
    } catch (e) {
      state = AdviceState(error: e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void clear() => state = const AdviceState();
}

final adviceProvider = StateNotifierProvider<AdviceNotifier, AdviceState>(
  (_) => AdviceNotifier(),
);
