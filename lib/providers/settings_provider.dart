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

  const SettingsState({
    this.adviceLevel = 'normal',
    this.selectedProvider = AiProviderType.anthropic,
    this.anthropicApiKey = '',
    this.openAiApiKey = '',
    this.geminiApiKey = '',
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
  }) =>
      SettingsState(
        adviceLevel: adviceLevel ?? this.adviceLevel,
        selectedProvider: selectedProvider ?? this.selectedProvider,
        anthropicApiKey: anthropicApiKey ?? this.anthropicApiKey,
        openAiApiKey: openAiApiKey ?? this.openAiApiKey,
        geminiApiKey: geminiApiKey ?? this.geminiApiKey,
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
