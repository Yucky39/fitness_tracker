import 'package:riverpod/legacy.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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

  List<({String id, String label})> get availableModels {
    switch (this) {
      case AiProviderType.anthropic:
        return [
          (id: 'claude-haiku-4-5-20251001', label: 'Haiku 4.5（高速・低コスト）'),
          (id: 'claude-sonnet-4-6', label: 'Sonnet 4.6（バランス）'),
          (id: 'claude-opus-4-6', label: 'Opus 4.6（最高性能）'),
        ];
      case AiProviderType.openai:
        return [
          (id: 'gpt-4o-mini', label: 'GPT-4o mini（高速・低コスト）'),
          (id: 'gpt-4o', label: 'GPT-4o（高性能）'),
          (id: 'gpt-4.1-mini', label: 'GPT-4.1 mini（高速）'),
          (id: 'gpt-4.1', label: 'GPT-4.1（高性能）'),
          (id: 'o4-mini', label: 'o4 mini（推論・高速）'),
          (id: 'o3', label: 'o3（推論・最高性能）'),
          (id: 'gpt-5.4-nano', label: 'GPT-5.4 nano（最新・高速・低コスト）'),
          (id: 'gpt-5.4-mini', label: 'GPT-5.4 mini（最新・高速）'),
          (id: 'gpt-5.4', label: 'GPT-5.4（最新・最高性能）'),
        ];
      case AiProviderType.gemini:
        return [
          (id: 'gemini-2.0-flash', label: 'Gemini 2.0 Flash（高速）'),
          (id: 'gemini-2.5-flash', label: 'Gemini 2.5 Flash（高速）'),
          (id: 'gemini-2.5-pro', label: 'Gemini 2.5 Pro（高性能）'),
          (id: 'gemini-3-flash-preview', label: 'Gemini 3 Flash プレビュー（最新・高速）'),
          (id: 'gemini-3.1-pro-preview', label: 'Gemini 3.1 Pro プレビュー（最新・最高性能）'),
        ];
    }
  }

  String get defaultModel {
    switch (this) {
      case AiProviderType.anthropic:
        return 'claude-haiku-4-5-20251001';
      case AiProviderType.openai:
        return 'gpt-5.4-mini';
      case AiProviderType.gemini:
        return 'gemini-3-flash-preview';
    }
  }

  String get modelLabel {
    switch (this) {
      case AiProviderType.anthropic:
        return 'Claude Haiku 4.5';
      case AiProviderType.openai:
        return 'GPT-5.4 mini';
      case AiProviderType.gemini:
        return 'Gemini 3 Flash';
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

  String get modelStorageKey {
    switch (this) {
      case AiProviderType.anthropic:
        return 'anthropicModel';
      case AiProviderType.openai:
        return 'openAiModel';
      case AiProviderType.gemini:
        return 'geminiModel';
    }
  }
}

class SettingsState {
  final String adviceLevel;
  final AiProviderType selectedProvider;
  final String anthropicApiKey;
  final String openAiApiKey;
  final String geminiApiKey;
  final String selectedAnthropicModel;
  final String selectedOpenAiModel;
  final String selectedGeminiModel;
  final bool mealReminderEnabled;
  final int mealReminderHour;
  final int mealReminderMinute;
  final bool workoutReminderEnabled;
  final int workoutReminderHour;
  final int workoutReminderMinute;
  final bool trainingAdviceEnabled;
  final bool communityFoodContributeEnabled;

  const SettingsState({
    this.adviceLevel = 'normal',
    this.selectedProvider = AiProviderType.anthropic,
    this.anthropicApiKey = '',
    this.openAiApiKey = '',
    this.geminiApiKey = '',
    this.selectedAnthropicModel = 'claude-haiku-4-5-20251001',
    this.selectedOpenAiModel = 'gpt-5.4-mini',
    this.selectedGeminiModel = 'gemini-3-flash-preview',
    this.mealReminderEnabled = false,
    this.mealReminderHour = 12,
    this.mealReminderMinute = 0,
    this.workoutReminderEnabled = false,
    this.workoutReminderHour = 18,
    this.workoutReminderMinute = 0,
    this.trainingAdviceEnabled = true,
    this.communityFoodContributeEnabled = true,
  });

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

  String get currentModel {
    switch (selectedProvider) {
      case AiProviderType.anthropic:
        return selectedAnthropicModel;
      case AiProviderType.openai:
        return selectedOpenAiModel;
      case AiProviderType.gemini:
        return selectedGeminiModel;
    }
  }

  String get currentModelLabel {
    final models = selectedProvider.availableModels;
    return models.firstWhere(
      (m) => m.id == currentModel,
      orElse: () => (id: currentModel, label: currentModel),
    ).label;
  }

  String get adviceLevelLabel =>
      const {'strict': '厳しめ', 'normal': '普通', 'gentle': '優しめ'}[adviceLevel]!;

  SettingsState copyWith({
    String? adviceLevel,
    AiProviderType? selectedProvider,
    String? anthropicApiKey,
    String? openAiApiKey,
    String? geminiApiKey,
    String? selectedAnthropicModel,
    String? selectedOpenAiModel,
    String? selectedGeminiModel,
    bool? mealReminderEnabled,
    int? mealReminderHour,
    int? mealReminderMinute,
    bool? workoutReminderEnabled,
    int? workoutReminderHour,
    int? workoutReminderMinute,
    bool? trainingAdviceEnabled,
    bool? communityFoodContributeEnabled,
  }) =>
      SettingsState(
        adviceLevel: adviceLevel ?? this.adviceLevel,
        selectedProvider: selectedProvider ?? this.selectedProvider,
        anthropicApiKey: anthropicApiKey ?? this.anthropicApiKey,
        openAiApiKey: openAiApiKey ?? this.openAiApiKey,
        geminiApiKey: geminiApiKey ?? this.geminiApiKey,
        selectedAnthropicModel:
            selectedAnthropicModel ?? this.selectedAnthropicModel,
        selectedOpenAiModel: selectedOpenAiModel ?? this.selectedOpenAiModel,
        selectedGeminiModel: selectedGeminiModel ?? this.selectedGeminiModel,
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
        communityFoodContributeEnabled:
            communityFoodContributeEnabled ?? this.communityFoodContributeEnabled,
      );
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier() : super(const SettingsState()) {
    _load();
  }

  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();

    for (final provider in AiProviderType.values) {
      final inPrefs = prefs.getString(provider.storageKey) ?? '';
      if (inPrefs.isNotEmpty) {
        final inSecure = await _secureStorage.read(key: provider.storageKey);
        if (inSecure == null || inSecure.isEmpty) {
          await _secureStorage.write(key: provider.storageKey, value: inPrefs);
        }
        await prefs.remove(provider.storageKey);
      }
    }

    final anthropicKey =
        await _secureStorage.read(key: AiProviderType.anthropic.storageKey) ??
            '';
    final openAiKey =
        await _secureStorage.read(key: AiProviderType.openai.storageKey) ?? '';
    final geminiKey =
        await _secureStorage.read(key: AiProviderType.gemini.storageKey) ?? '';

    state = SettingsState(
      adviceLevel: prefs.getString('adviceLevel') ?? 'normal',
      selectedProvider: AiProviderType.fromString(
        prefs.getString('selectedAiProvider') ?? 'anthropic',
      ),
      anthropicApiKey: anthropicKey,
      openAiApiKey: openAiKey,
      geminiApiKey: geminiKey,
      selectedAnthropicModel:
          prefs.getString(AiProviderType.anthropic.modelStorageKey) ??
              AiProviderType.anthropic.defaultModel,
      selectedOpenAiModel:
          prefs.getString(AiProviderType.openai.modelStorageKey) ??
              AiProviderType.openai.defaultModel,
      selectedGeminiModel:
          prefs.getString(AiProviderType.gemini.modelStorageKey) ??
              AiProviderType.gemini.defaultModel,
      mealReminderEnabled: prefs.getBool('mealReminderEnabled') ?? false,
      mealReminderHour: prefs.getInt('mealReminderHour') ?? 12,
      mealReminderMinute: prefs.getInt('mealReminderMinute') ?? 0,
      workoutReminderEnabled: prefs.getBool('workoutReminderEnabled') ?? false,
      workoutReminderHour: prefs.getInt('workoutReminderHour') ?? 18,
      workoutReminderMinute: prefs.getInt('workoutReminderMinute') ?? 0,
      trainingAdviceEnabled: prefs.getBool('trainingAdviceEnabled') ?? true,
      communityFoodContributeEnabled:
          prefs.getBool('communityFoodContributeEnabled') ?? true,
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

  Future<void> updateModel(AiProviderType provider, String modelId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(provider.modelStorageKey, modelId);
    switch (provider) {
      case AiProviderType.anthropic:
        state = state.copyWith(selectedAnthropicModel: modelId);
      case AiProviderType.openai:
        state = state.copyWith(selectedOpenAiModel: modelId);
      case AiProviderType.gemini:
        state = state.copyWith(selectedGeminiModel: modelId);
    }
  }

  Future<void> updateApiKey(AiProviderType provider, String key) async {
    await _secureStorage.write(key: provider.storageKey, value: key);
    switch (provider) {
      case AiProviderType.anthropic:
        state = state.copyWith(anthropicApiKey: key);
      case AiProviderType.openai:
        state = state.copyWith(openAiApiKey: key);
      case AiProviderType.gemini:
        state = state.copyWith(geminiApiKey: key);
    }
  }

  Future<void> updateTrainingAdviceEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('trainingAdviceEnabled', enabled);
    state = state.copyWith(trainingAdviceEnabled: enabled);
  }

  Future<void> updateCommunityFoodContributeEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('communityFoodContributeEnabled', enabled);
    state = state.copyWith(communityFoodContributeEnabled: enabled);
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
    if (mealEnabled != null) {
      await prefs.setBool('mealReminderEnabled', mealEnabled);
    }
    if (mealHour != null) await prefs.setInt('mealReminderHour', mealHour);
    if (mealMinute != null) {
      await prefs.setInt('mealReminderMinute', mealMinute);
    }
    if (workoutEnabled != null) {
      await prefs.setBool('workoutReminderEnabled', workoutEnabled);
    }
    if (workoutHour != null) {
      await prefs.setInt('workoutReminderHour', workoutHour);
    }
    if (workoutMinute != null) {
      await prefs.setInt('workoutReminderMinute', workoutMinute);
    }
    state = state.copyWith(
      mealReminderEnabled: mealEnabled,
      mealReminderHour: mealHour,
      mealReminderMinute: mealMinute,
      workoutReminderEnabled: workoutEnabled,
      workoutReminderHour: workoutHour,
      workoutReminderMinute: workoutMinute,
    );
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>(
  (_) => SettingsNotifier(),
);
