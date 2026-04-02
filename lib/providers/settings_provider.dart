import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AiProviderType {
  anthropic,
  openai,
  gemini;

  String get label {
    switch (this) {
      case AiProviderType.anthropic:
        return 'Anthropic';
      case AiProviderType.openai:
        return 'OpenAI';
      case AiProviderType.gemini:
        return 'Gemini';
    }
  }

  String get modelLabel {
    switch (this) {
      case AiProviderType.anthropic:
        return 'Claude Haiku';
      case AiProviderType.openai:
        return 'GPT-4o mini';
      case AiProviderType.gemini:
        return 'Gemini Flash';
    }
  }

  String get apiKeyHint {
    switch (this) {
      case AiProviderType.anthropic:
        return 'sk-ant-...';
      case AiProviderType.openai:
        return 'sk-...';
      case AiProviderType.gemini:
        return 'AIza...';
    }
  }

  static AiProviderType fromString(String s) {
    switch (s) {
      case 'openai':
        return AiProviderType.openai;
      case 'gemini':
        return AiProviderType.gemini;
      default:
        return AiProviderType.anthropic;
    }
  }

  String get storageKey {
    switch (this) {
      case AiProviderType.anthropic:
        return 'anthropicApiKey';
      case AiProviderType.openai:
        return 'openAiApiKey';
      case AiProviderType.gemini:
        return 'geminiApiKey';
    }
  }
}

class SettingsState {
  final String adviceLevel; // 'strict', 'normal', 'gentle'
  final AiProviderType selectedProvider;
  final String anthropicApiKey;
  final String openAiApiKey;
  final String geminiApiKey;
  // Notification settings
  final bool mealReminderEnabled;
  final int mealReminderHour;
  final int mealReminderMinute;
  final bool workoutReminderEnabled;
  final int workoutReminderHour;
  final int workoutReminderMinute;
  // Training AI advice toggle
  final bool trainingAdviceEnabled;

  const SettingsState({
    this.adviceLevel = 'normal',
    this.selectedProvider = AiProviderType.anthropic,
    this.anthropicApiKey = '',
    this.openAiApiKey = '',
    this.geminiApiKey = '',
    this.mealReminderEnabled = false,
    this.mealReminderHour = 12,
    this.mealReminderMinute = 0,
    this.workoutReminderEnabled = false,
    this.workoutReminderHour = 18,
    this.workoutReminderMinute = 0,
    this.trainingAdviceEnabled = true,
  });

  /// Returns the API key for the currently selected provider.
  String get currentApiKey {
    switch (selectedProvider) {
      case AiProviderType.anthropic:
        return anthropicApiKey;
      case AiProviderType.openai:
        return openAiApiKey;
      case AiProviderType.gemini:
        return geminiApiKey;
    }
  }

  String get adviceLevelLabel =>
      const {'strict': '厳しめ', 'normal': '普通', 'gentle': '優しめ'}[adviceLevel]!;

  SettingsState copyWith({
    String? adviceLevel,
    AiProviderType? selectedProvider,
    String? anthropicApiKey,
    String? openAiApiKey,
    String? geminiApiKey,
    bool? mealReminderEnabled,
    int? mealReminderHour,
    int? mealReminderMinute,
    bool? workoutReminderEnabled,
    int? workoutReminderHour,
    int? workoutReminderMinute,
    bool? trainingAdviceEnabled,
  }) =>
      SettingsState(
        adviceLevel: adviceLevel ?? this.adviceLevel,
        selectedProvider: selectedProvider ?? this.selectedProvider,
        anthropicApiKey: anthropicApiKey ?? this.anthropicApiKey,
        openAiApiKey: openAiApiKey ?? this.openAiApiKey,
        geminiApiKey: geminiApiKey ?? this.geminiApiKey,
        mealReminderEnabled: mealReminderEnabled ?? this.mealReminderEnabled,
        mealReminderHour: mealReminderHour ?? this.mealReminderHour,
        mealReminderMinute: mealReminderMinute ?? this.mealReminderMinute,
        workoutReminderEnabled:
            workoutReminderEnabled ?? this.workoutReminderEnabled,
        workoutReminderHour: workoutReminderHour ?? this.workoutReminderHour,
        workoutReminderMinute:
            workoutReminderMinute ?? this.workoutReminderMinute,
        trainingAdviceEnabled:
            trainingAdviceEnabled ?? this.trainingAdviceEnabled,
      );
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier() : super(const SettingsState()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = SettingsState(
      adviceLevel: prefs.getString('adviceLevel') ?? 'normal',
      selectedProvider: AiProviderType.fromString(
        prefs.getString('selectedAiProvider') ?? 'anthropic',
      ),
      anthropicApiKey: prefs.getString('anthropicApiKey') ?? '',
      openAiApiKey: prefs.getString('openAiApiKey') ?? '',
      geminiApiKey: prefs.getString('geminiApiKey') ?? '',
      mealReminderEnabled: prefs.getBool('mealReminderEnabled') ?? false,
      mealReminderHour: prefs.getInt('mealReminderHour') ?? 12,
      mealReminderMinute: prefs.getInt('mealReminderMinute') ?? 0,
      workoutReminderEnabled: prefs.getBool('workoutReminderEnabled') ?? false,
      workoutReminderHour: prefs.getInt('workoutReminderHour') ?? 18,
      workoutReminderMinute: prefs.getInt('workoutReminderMinute') ?? 0,
      trainingAdviceEnabled: prefs.getBool('trainingAdviceEnabled') ?? true,
    );
  }

  Future<void> updateTrainingAdviceEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('trainingAdviceEnabled', enabled);
    state = state.copyWith(trainingAdviceEnabled: enabled);
  }

  Future<void> updateNotificationSettings({
    bool? mealEnabled,
    int? mealHour,
    int? mealMinute,
    bool? workoutEnabled,
    int? workoutHour,
    int? workoutMinute,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (mealEnabled != null) await prefs.setBool('mealReminderEnabled', mealEnabled);
    if (mealHour != null) await prefs.setInt('mealReminderHour', mealHour);
    if (mealMinute != null) await prefs.setInt('mealReminderMinute', mealMinute);
    if (workoutEnabled != null) await prefs.setBool('workoutReminderEnabled', workoutEnabled);
    if (workoutHour != null) await prefs.setInt('workoutReminderHour', workoutHour);
    if (workoutMinute != null) await prefs.setInt('workoutReminderMinute', workoutMinute);
    state = state.copyWith(
      mealReminderEnabled: mealEnabled,
      mealReminderHour: mealHour,
      mealReminderMinute: mealMinute,
      workoutReminderEnabled: workoutEnabled,
      workoutReminderHour: workoutHour,
      workoutReminderMinute: workoutMinute,
    );
  }

  Future<void> updateAdviceLevel(String level) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('adviceLevel', level);
    state = state.copyWith(adviceLevel: level);
  }

  Future<void> updateSelectedProvider(AiProviderType provider) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selectedAiProvider', provider.name);
    state = state.copyWith(selectedProvider: provider);
  }

  Future<void> updateApiKey(AiProviderType provider, String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(provider.storageKey, key);
    switch (provider) {
      case AiProviderType.anthropic:
        state = state.copyWith(anthropicApiKey: key);
      case AiProviderType.openai:
        state = state.copyWith(openAiApiKey: key);
      case AiProviderType.gemini:
        state = state.copyWith(geminiApiKey: key);
    }
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>(
  (_) => SettingsNotifier(),
);
