import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsState {
  final String adviceLevel; // 'strict', 'normal', 'gentle'
  final String apiKey;

  const SettingsState({this.adviceLevel = 'normal', this.apiKey = ''});

  SettingsState copyWith({String? adviceLevel, String? apiKey}) => SettingsState(
        adviceLevel: adviceLevel ?? this.adviceLevel,
        apiKey: apiKey ?? this.apiKey,
      );

  String get adviceLevelLabel =>
      const {'strict': '厳しめ', 'normal': '普通', 'gentle': '優しめ'}[adviceLevel]!;
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier() : super(const SettingsState()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = SettingsState(
      adviceLevel: prefs.getString('adviceLevel') ?? 'normal',
      apiKey: prefs.getString('anthropicApiKey') ?? '',
    );
  }

  Future<void> updateAdviceLevel(String level) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('adviceLevel', level);
    state = state.copyWith(adviceLevel: level);
  }

  Future<void> updateApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('anthropicApiKey', key);
    state = state.copyWith(apiKey: key);
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>(
  (_) => SettingsNotifier(),
);
