import 'package:flutter_riverpod/flutter_riverpod.dart';
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
        ];
      case AiProviderType.gemini:
        return [
          (id: 'gemini-2.0-flash', label: 'Gemini 2.0 Flash（高速）'),
          (id: 'gemini-1.5-pro', label: 'Gemini 1.5 Pro（高性能）'),
        ];
    }
  }

  String get defaultModel {
    switch (this) {
      case AiProviderType.anthropic:
        return 'claude-haiku-4-5-20251001';
      case AiProviderType.openai:
        return 'gpt-4o-mini';
      case AiProviderType.gemini:
        return 'gemini-2.0-flash';
    }
  }

  String get modelLabel {
    switch (this) {
      case AiProviderType.anthropic:
        return 'Claude Haiku 4.5';
      case AiProviderType.openai:
        return 'GPT-4o mini';
      case AiProviderType.gemini:
        return 'Gemini 2.0 Flash';
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
  final String adviceLevel; // 'strict', 'normal', 'gentle'
  final AiProviderType selectedProvider;
  final String anthropicApiKey;
  final String openAiApiKey;
  final String geminiApiKey;
  final String selectedAnthropicModel;
  final String selectedOpenAiModel;
  final String selectedGeminiModel;

  const SettingsState({
    this.adviceLevel = 'normal',
    this.selectedProvider = AiProviderType.anthropic,
    this.anthropicApiKey = '',
    this.openAiApiKey = '',
    this.geminiApiKey = '',
    this.selectedAnthropicModel = 'claude-haiku-4-5-20251001',
    this.selectedOpenAiModel = 'gpt-4o-mini',
    this.selectedGeminiModel = 'gemini-2.0-flash',
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

  /// Returns the selected model ID for the currently selected provider.
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

  /// Returns the display label for the current model.
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
  }) =>
      SettingsState(
        adviceLevel: adviceLevel ?? this.adviceLevel,
        selectedProvider: selectedProvider ?? this.selectedProvider,
        anthropicApiKey: anthropicApiKey ?? this.anthropicApiKey,
        openAiApiKey: openAiApiKey ?? this.openAiApiKey,
        geminiApiKey: geminiApiKey ?? this.geminiApiKey,
        selectedAnthropicModel: selectedAnthropicModel ?? this.selectedAnthropicModel,
        selectedOpenAiModel: selectedOpenAiModel ?? this.selectedOpenAiModel,
        selectedGeminiModel: selectedGeminiModel ?? this.selectedGeminiModel,
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

    // Migrate API keys from SharedPreferences → secure storage if needed
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
        await _secureStorage.read(key: AiProviderType.anthropic.storageKey) ?? '';
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
      selectedAnthropicModel: prefs.getString(AiProviderType.anthropic.modelStorageKey)
          ?? AiProviderType.anthropic.defaultModel,
      selectedOpenAiModel: prefs.getString(AiProviderType.openai.modelStorageKey)
          ?? AiProviderType.openai.defaultModel,
      selectedGeminiModel: prefs.getString(AiProviderType.gemini.modelStorageKey)
          ?? AiProviderType.gemini.defaultModel,
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
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>(
  (_) => SettingsNotifier(),
);
