import 'package:riverpod/legacy.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/sync_service.dart';

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
          (id: 'claude-opus-4-7', label: 'Opus 4.7（最高性能）'),
        ];
      case AiProviderType.openai:
        return [
          (id: 'gpt-4o-mini', label: 'GPT-4o mini（高速・低コスト）'),
          (id: 'gpt-4o', label: 'GPT-4o（高性能）'),
          (id: 'gpt-4.1-mini', label: 'GPT-4.1 mini（高速）'),
          (id: 'gpt-4.1', label: 'GPT-4.1（高性能）'),
          (id: 'o4-mini', label: 'o4 mini（推論・高速）'),
          (id: 'o3', label: 'o3（推論・最高性能）'),
        ];
      case AiProviderType.gemini:
        return [
          (id: 'gemini-3.5-flash', label: 'Gemini 3.5 Flash（最新・高速）'),
          (id: 'gemini-2.0-flash', label: 'Gemini 2.0 Flash（高速）'),
          (id: 'gemini-2.5-flash', label: 'Gemini 2.5 Flash（高速）'),
          (id: 'gemini-2.5-pro', label: 'Gemini 2.5 Pro（高性能）'),
          (id: 'gemini-3-flash-preview', label: 'Gemini 3 Flash プレビュー'),
          (
            id: 'gemini-3.1-pro-preview',
            label: 'Gemini 3.1 Pro プレビュー（最高性能）'
          ),
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
        return 'gemini-3.5-flash';
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
  final bool waterReminderEnabled;

  /// リマインダーの間隔（分）例: 60 = 1時間ごと
  final int waterReminderIntervalMinutes;

  /// リマインダーを送る時間帯の開始時刻（時）
  final int waterReminderStartHour;

  /// リマインダーを送る時間帯の終了時刻（時）
  final int waterReminderEndHour;

  final bool trainingAdviceEnabled;
  final bool communityFoodContributeEnabled;
  final bool mealSuggestionEnabled;

  /// 横断AIコーチの毎日のリマインダー（「今日のコーチングが届いています」）
  final bool coachReminderEnabled;
  final int coachReminderHour;
  final int coachReminderMinute;

  /// トレーニング部位ごとの推奨休息日数（デフォルト5日）。
  /// ホーム画面・トレーニング管理の部位ヒートマップで回復状況の表示に使用する。
  final int restPeriodDays;

  const SettingsState({
    this.adviceLevel = 'normal',
    this.selectedProvider = AiProviderType.anthropic,
    this.anthropicApiKey = '',
    this.openAiApiKey = '',
    this.geminiApiKey = '',
    this.selectedAnthropicModel = 'claude-haiku-4-5-20251001',
    this.selectedOpenAiModel = 'gpt-4o-mini',
    this.selectedGeminiModel = 'gemini-3.5-flash',
    this.mealReminderEnabled = false,
    this.mealReminderHour = 12,
    this.mealReminderMinute = 0,
    this.workoutReminderEnabled = false,
    this.workoutReminderHour = 18,
    this.workoutReminderMinute = 0,
    this.waterReminderEnabled = false,
    this.waterReminderIntervalMinutes = 60,
    this.waterReminderStartHour = 8,
    this.waterReminderEndHour = 21,
    this.trainingAdviceEnabled = true,
    this.communityFoodContributeEnabled = true,
    this.mealSuggestionEnabled = false,
    this.coachReminderEnabled = false,
    this.coachReminderHour = 8,
    this.coachReminderMinute = 0,
    this.restPeriodDays = 5,
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

  /// [selectedProvider] の更新が非同期で遅れる場合でも、UIで正しいモデルIDを参照するために使う。
  String modelForProvider(AiProviderType p) {
    switch (p) {
      case AiProviderType.anthropic:
        return selectedAnthropicModel;
      case AiProviderType.openai:
        return selectedOpenAiModel;
      case AiProviderType.gemini:
        return selectedGeminiModel;
    }
  }

  /// 保存済みIDが [p.availableModels] に無い場合はデフォルトにフォールバック（ドロップダウンと整合させる）。
  String resolvedModelForProvider(AiProviderType p) {
    final id = modelForProvider(p);
    final ids = p.availableModels.map((m) => m.id).toSet();
    return ids.contains(id) ? id : p.defaultModel;
  }

  String get currentModelLabel {
    final models = selectedProvider.availableModels;
    return models
        .firstWhere(
          (m) => m.id == currentModel,
          orElse: () => (id: currentModel, label: currentModel),
        )
        .label;
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
    bool? waterReminderEnabled,
    int? waterReminderIntervalMinutes,
    int? waterReminderStartHour,
    int? waterReminderEndHour,
    bool? trainingAdviceEnabled,
    bool? communityFoodContributeEnabled,
    bool? mealSuggestionEnabled,
    bool? coachReminderEnabled,
    int? coachReminderHour,
    int? coachReminderMinute,
    int? restPeriodDays,
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
        waterReminderEnabled:
            waterReminderEnabled ?? this.waterReminderEnabled,
        waterReminderIntervalMinutes:
            waterReminderIntervalMinutes ?? this.waterReminderIntervalMinutes,
        waterReminderStartHour:
            waterReminderStartHour ?? this.waterReminderStartHour,
        waterReminderEndHour:
            waterReminderEndHour ?? this.waterReminderEndHour,
        trainingAdviceEnabled:
            trainingAdviceEnabled ?? this.trainingAdviceEnabled,
        communityFoodContributeEnabled: communityFoodContributeEnabled ??
            this.communityFoodContributeEnabled,
        mealSuggestionEnabled:
            mealSuggestionEnabled ?? this.mealSuggestionEnabled,
        coachReminderEnabled:
            coachReminderEnabled ?? this.coachReminderEnabled,
        coachReminderHour: coachReminderHour ?? this.coachReminderHour,
        coachReminderMinute: coachReminderMinute ?? this.coachReminderMinute,
        restPeriodDays: restPeriodDays ?? this.restPeriodDays,
      );
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier() : super(const SettingsState()) {
    _load();
  }

  /// `ref` が使えないコールバック（例: Dropdown の非同期 onChanged）から現在状態を読む用。
  SettingsState get currentSettings => state;

  static const _secureStorage = FlutterSecureStorage();

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
      waterReminderEnabled: prefs.getBool('waterReminderEnabled') ?? false,
      waterReminderIntervalMinutes:
          prefs.getInt('waterReminderIntervalMinutes') ?? 60,
      waterReminderStartHour: prefs.getInt('waterReminderStartHour') ?? 8,
      waterReminderEndHour: prefs.getInt('waterReminderEndHour') ?? 21,
      trainingAdviceEnabled: prefs.getBool('trainingAdviceEnabled') ?? true,
      communityFoodContributeEnabled:
          prefs.getBool('communityFoodContributeEnabled') ?? true,
      mealSuggestionEnabled: prefs.getBool('mealSuggestionEnabled') ?? false,
      coachReminderEnabled: prefs.getBool('coachReminderEnabled') ?? false,
      coachReminderHour: prefs.getInt('coachReminderHour') ?? 8,
      coachReminderMinute: prefs.getInt('coachReminderMinute') ?? 0,
      restPeriodDays: prefs.getInt('restPeriodDays') ?? 5,
    );
  }

  Future<void> updateAdviceLevel(String level) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('adviceLevel', level);
    state = state.copyWith(adviceLevel: level);
    SyncService().syncFields({'settings.adviceLevel': level});
  }

  Future<void> updateSelectedProvider(AiProviderType provider) async {
    state = state.copyWith(selectedProvider: provider);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selectedAiProvider', provider.name);
    SyncService().syncFields({'settings.selectedProvider': provider.name});
  }

  Future<void> updateModel(AiProviderType provider, String modelId) async {
    state = switch (provider) {
      AiProviderType.anthropic =>
        state.copyWith(selectedAnthropicModel: modelId),
      AiProviderType.openai => state.copyWith(selectedOpenAiModel: modelId),
      AiProviderType.gemini => state.copyWith(selectedGeminiModel: modelId),
    };
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(provider.modelStorageKey, modelId);
    final firestoreKey = switch (provider) {
      AiProviderType.anthropic => 'settings.anthropicModel',
      AiProviderType.openai => 'settings.openAiModel',
      AiProviderType.gemini => 'settings.geminiModel',
    };
    SyncService().syncFields({firestoreKey: modelId});
  }

  Future<void> updateApiKey(AiProviderType provider, String key) async {
    await _secureStorage.write(key: provider.storageKey, value: key);
    state = switch (provider) {
      AiProviderType.anthropic => state.copyWith(anthropicApiKey: key),
      AiProviderType.openai => state.copyWith(openAiApiKey: key),
      AiProviderType.gemini => state.copyWith(geminiApiKey: key),
    };
    // API keys are NOT synced to Firestore for security reasons.
  }

  Future<void> updateTrainingAdviceEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('trainingAdviceEnabled', enabled);
    state = state.copyWith(trainingAdviceEnabled: enabled);
    SyncService().syncFields({'settings.trainingAdviceEnabled': enabled});
  }

  Future<void> updateCommunityFoodContributeEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('communityFoodContributeEnabled', enabled);
    state = state.copyWith(communityFoodContributeEnabled: enabled);
    SyncService()
        .syncFields({'settings.communityFoodContributeEnabled': enabled});
  }

  Future<void> updateMealSuggestionEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('mealSuggestionEnabled', enabled);
    state = state.copyWith(mealSuggestionEnabled: enabled);
    SyncService().syncFields({'settings.mealSuggestionEnabled': enabled});
  }

  Future<void> updateNotificationSettings({
    bool? mealEnabled,
    int? mealHour,
    int? mealMinute,
    bool? workoutEnabled,
    int? workoutHour,
    int? workoutMinute,
    bool? waterEnabled,
    int? waterIntervalMinutes,
    int? waterStartHour,
    int? waterEndHour,
    bool? coachEnabled,
    int? coachHour,
    int? coachMinute,
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
    if (waterEnabled != null) {
      await prefs.setBool('waterReminderEnabled', waterEnabled);
    }
    if (waterIntervalMinutes != null) {
      await prefs.setInt('waterReminderIntervalMinutes', waterIntervalMinutes);
    }
    if (waterStartHour != null) {
      await prefs.setInt('waterReminderStartHour', waterStartHour);
    }
    if (waterEndHour != null) {
      await prefs.setInt('waterReminderEndHour', waterEndHour);
    }
    if (coachEnabled != null) {
      await prefs.setBool('coachReminderEnabled', coachEnabled);
    }
    if (coachHour != null) await prefs.setInt('coachReminderHour', coachHour);
    if (coachMinute != null) {
      await prefs.setInt('coachReminderMinute', coachMinute);
    }
    state = state.copyWith(
      mealReminderEnabled: mealEnabled,
      mealReminderHour: mealHour,
      mealReminderMinute: mealMinute,
      workoutReminderEnabled: workoutEnabled,
      workoutReminderHour: workoutHour,
      workoutReminderMinute: workoutMinute,
      waterReminderEnabled: waterEnabled,
      waterReminderIntervalMinutes: waterIntervalMinutes,
      waterReminderStartHour: waterStartHour,
      waterReminderEndHour: waterEndHour,
      coachReminderEnabled: coachEnabled,
      coachReminderHour: coachHour,
      coachReminderMinute: coachMinute,
    );

    SyncService().syncFields({
      if (mealEnabled != null) 'settings.mealReminderEnabled': mealEnabled,
      if (mealHour != null) 'settings.mealReminderHour': mealHour,
      if (mealMinute != null) 'settings.mealReminderMinute': mealMinute,
      if (workoutEnabled != null)
        'settings.workoutReminderEnabled': workoutEnabled,
      if (workoutHour != null) 'settings.workoutReminderHour': workoutHour,
      if (workoutMinute != null)
        'settings.workoutReminderMinute': workoutMinute,
      if (waterEnabled != null) 'settings.waterReminderEnabled': waterEnabled,
      if (waterIntervalMinutes != null)
        'settings.waterReminderIntervalMinutes': waterIntervalMinutes,
      if (waterStartHour != null)
        'settings.waterReminderStartHour': waterStartHour,
      if (waterEndHour != null) 'settings.waterReminderEndHour': waterEndHour,
    });
  }

  /// 部位ごとの推奨休息日数を更新（1〜14日にクランプ）。
  Future<void> updateRestPeriodDays(int days) async {
    final clamped = days.clamp(1, 14);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('restPeriodDays', clamped);
    state = state.copyWith(restPeriodDays: clamped);
    SyncService().syncFields({'settings.restPeriodDays': clamped});
  }

  Future<void> reload() => _load();
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>(
  (_) => SettingsNotifier(),
);
