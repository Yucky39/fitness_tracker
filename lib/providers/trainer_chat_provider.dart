import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/chat_message.dart';
import '../services/trainer_chat_service.dart';
import 'energy_profile_provider.dart';
import 'meal_provider.dart';
import 'period_summary_provider.dart';
import 'settings_provider.dart';

class TrainerChatState {
  final List<ChatMessage> messages;
  final bool isLoading;
  final String? error;

  /// 当月のAI利用枠の上限に達したため送信がブロックされた状態。
  /// true のとき、画面は追加パック購入の導線を表示する。
  final bool limitReached;

  const TrainerChatState({
    this.messages = const [],
    this.isLoading = false,
    this.error,
    this.limitReached = false,
  });

  TrainerChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    String? error,
    bool clearError = false,
    bool? limitReached,
  }) =>
      TrainerChatState(
        messages: messages ?? this.messages,
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : error ?? this.error,
        limitReached: limitReached ?? this.limitReached,
      );
}

class TrainerChatNotifier extends StateNotifier<TrainerChatState> {
  TrainerChatNotifier(this._ref) : super(const TrainerChatState()) {
    _restore();
  }

  final Ref _ref;

  /// 会話履歴は端末ローカルにのみ保存する（MVP方針。Firestore同期は将来フェーズ）。
  static const _storageKey = 'trainer_chat_history';

  /// 端末に保持する履歴の上限。これを超えた古いメッセージは破棄する。
  static const _maxStoredMessages = 60;

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null) return;
    try {
      final list = (jsonDecode(raw) as List)
          .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
          .toList();
      if (!mounted) return;
      state = state.copyWith(messages: list);
    } catch (_) {
      // 壊れたキャッシュは無視する。
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final list = state.messages
        .map((m) => m.toJson())
        .toList(growable: false);
    await prefs.setString(_storageKey, jsonEncode(list));
  }

  String _buildContextSummary() {
    final profile = _ref.read(energyProfileProvider);
    final meal = _ref.read(mealProvider);
    final weekSummary = _ref.read(periodSummaryProvider).summary;
    return TrainerChatService.buildContextSummary(
      profile: profile,
      calorieGoal: meal.calorieGoal,
      proteinGoal: meal.proteinGoal,
      fatGoal: meal.fatGoal,
      carbsGoal: meal.carbsGoal,
      weekSummary: weekSummary,
    );
  }

  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.isLoading) return;

    final now = DateTime.now();
    final userMessage = ChatMessage(
      id: now.microsecondsSinceEpoch.toString(),
      role: ChatRole.user,
      text: trimmed,
      createdAt: now,
    );

    final history = [...state.messages, userMessage];
    state = state.copyWith(
      messages: history,
      isLoading: true,
      clearError: true,
      limitReached: false,
    );
    await _persist();

    try {
      final adviceLevel = _ref.read(settingsProvider).adviceLevel;
      final reply = await TrainerChatService().send(
        history: history,
        adviceLevel: adviceLevel,
        contextSummary: _buildContextSummary(),
      );

      final trainerMessage = ChatMessage(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        role: ChatRole.trainer,
        text: reply.trim(),
        createdAt: DateTime.now(),
      );

      var next = [...state.messages, trainerMessage];
      if (next.length > _maxStoredMessages) {
        next = next.sublist(next.length - _maxStoredMessages);
      }
      state = state.copyWith(messages: next, isLoading: false);
      await _persist();
    } on FirebaseFunctionsException catch (e) {
      // 当月の利用枠を使い切った場合は追加課金の導線を出す。
      if (e.code == 'resource-exhausted') {
        state = state.copyWith(
          isLoading: false,
          limitReached: true,
          error: '今月のAI利用枠の上限に達しました。追加パックで続けられます。',
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          error: e.message ?? 'AI処理中にエラーが発生しました。',
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  /// 直前に失敗したユーザー発話を再送する。
  Future<void> retryLast() async {
    if (state.isLoading) return;
    if (state.messages.isEmpty) return;
    final last = state.messages.last;
    if (last.role != ChatRole.user) return;
    // 末尾のユーザー発話を一旦取り除いてから再送する。
    final text = last.text;
    state = state.copyWith(
      messages: state.messages.sublist(0, state.messages.length - 1),
      clearError: true,
    );
    await sendMessage(text);
  }

  Future<void> clearConversation() async {
    state = const TrainerChatState();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }
}

final trainerChatProvider =
    StateNotifierProvider<TrainerChatNotifier, TrainerChatState>(
  (ref) => TrainerChatNotifier(ref),
);
