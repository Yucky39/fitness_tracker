import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/ai_usage.dart';
import '../models/chat_message.dart';
import '../providers/ai_usage_provider.dart';
import '../providers/subscription_provider.dart';
import '../providers/trainer_chat_provider.dart';
import '../widgets/ai_credit_sheet.dart';
import '../widgets/paywall_sheet.dart';

/// AIトレーナーに、トレーニング・食事・日常のルーティンなどを自由に相談できるチャット画面。
class TrainerChatScreen extends ConsumerStatefulWidget {
  const TrainerChatScreen({super.key});

  @override
  ConsumerState<TrainerChatScreen> createState() => _TrainerChatScreenState();
}

class _TrainerChatScreenState extends ConsumerState<TrainerChatScreen> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();

  static const _suggestions = [
    '今日のトレーニングメニューを相談したい',
    '減量中の食事で気をつけることは？',
    '忙しい日のおすすめルーティンは？',
    '最近の記録から改善点を教えて',
  ];

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send(String text) async {
    final value = text.trim();
    if (value.isEmpty) return;
    _inputController.clear();
    await ref.read(trainerChatProvider.notifier).sendMessage(value);
    _scrollToBottom();
  }

  Future<void> _confirmClear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('会話を消去'),
        content: const Text('この会話の履歴を削除します。よろしいですか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('消去'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(trainerChatProvider.notifier).clearConversation();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSubscribed = ref.watch(isSubscribedProvider);
    final chat = ref.watch(trainerChatProvider);
    final scheme = Theme.of(context).colorScheme;

    ref.listen(trainerChatProvider.select((s) => s.messages.length), (_, __) {
      _scrollToBottom();
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('AIトレーナーに相談'),
        actions: [
          if (chat.messages.isNotEmpty)
            IconButton(
              tooltip: '会話を消去',
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: _confirmClear,
            ),
        ],
      ),
      body: isSubscribed
          ? _buildChat(context, scheme, chat)
          : _buildLockedView(context, scheme),
    );
  }

  // ── 未サブスク時のゲート ──────────────────────────────────────────────────

  Widget _buildLockedView(BuildContext context, ColorScheme scheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome_rounded, size: 56, color: scheme.primary),
            const SizedBox(height: 16),
            Text(
              'AIトレーナーチャットはプレミアム機能です',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'あなたの記録を踏まえて、トレーニング・食事・生活の相談にいつでも答えます。',
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant, height: 1.5),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => PaywallSheet.show(context),
              child: const Text('プレミアムを見る'),
            ),
          ],
        ),
      ),
    );
  }

  // ── チャット本体 ──────────────────────────────────────────────────────────

  Widget _buildChat(
    BuildContext context,
    ColorScheme scheme,
    TrainerChatState chat,
  ) {
    final usage = ref.watch(aiUsageProvider);
    return Column(
      children: [
        _buildUsageMeter(context, scheme, usage),
        Expanded(
          child: chat.messages.isEmpty
              ? _buildEmptyState(context, scheme)
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
                  itemCount: chat.messages.length + (chat.isLoading ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index >= chat.messages.length) {
                      return _buildTypingIndicator(scheme);
                    }
                    return _buildBubble(scheme, chat.messages[index]);
                  },
                ),
        ),
        if (chat.error != null) _buildError(context, scheme, chat),
        _buildDisclaimer(scheme),
        _buildInputBar(context, scheme, chat),
      ],
    );
  }

  /// 当月のAI利用枠メーター。残りが少ないときだけ表示してノイズを抑える。
  Widget _buildUsageMeter(
    BuildContext context,
    ColorScheme scheme,
    AiUsage usage,
  ) {
    // 利用が80%未満なら非表示（普段は意識させない）。
    if (usage.usedRatio < 0.8) return const SizedBox.shrink();
    final pct = (usage.usedRatio * 100).round();
    final atLimit = usage.isLimitReached;
    return Container(
      color: atLimit ? scheme.errorContainer : scheme.surfaceContainerLow,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                atLimit ? '今月のAI利用枠を使い切りました' : '今月のAI利用 $pct%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: atLimit
                      ? scheme.onErrorContainer
                      : scheme.onSurfaceVariant,
                ),
              ),
              if (atLimit)
                GestureDetector(
                  onTap: () => AiCreditSheet.show(context),
                  child: Text(
                    '追加パック',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: scheme.primary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: usage.usedRatio,
              minHeight: 6,
              backgroundColor: scheme.surfaceContainerHighest,
              color: atLimit ? scheme.error : scheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, ColorScheme scheme) {
    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 16),
      children: [
        Icon(Icons.sports_gymnastics_rounded,
            size: 56, color: scheme.primary),
        const SizedBox(height: 16),
        Text(
          'なんでも相談してください',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'トレーニング・食事・睡眠・日々のルーティンまで、'
          'あなたの記録を踏まえてアドバイスします。',
          textAlign: TextAlign.center,
          style: TextStyle(color: scheme.onSurfaceVariant, height: 1.5),
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: _suggestions
              .map((s) => ActionChip(
                    label: Text(s),
                    onPressed: () => _send(s),
                  ))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildBubble(ColorScheme scheme, ChatMessage message) {
    final isUser = message.role == ChatRole.user;
    final bg = isUser ? scheme.primary : scheme.surfaceContainerHigh;
    final fg = isUser ? scheme.onPrimary : scheme.onSurface;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
        ),
        child: SelectableText(
          message.text,
          style: TextStyle(color: fg, height: 1.5, fontSize: 15),
        ),
      ),
    );
  }

  Widget _buildTypingIndicator(ColorScheme scheme) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
        ),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: scheme.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildError(
    BuildContext context,
    ColorScheme scheme,
    TrainerChatState chat,
  ) {
    return Container(
      width: double.infinity,
      color: scheme.errorContainer,
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              chat.error ?? '',
              style: TextStyle(color: scheme.onErrorContainer, fontSize: 13),
            ),
          ),
          if (chat.limitReached)
            FilledButton(
              onPressed: () => AiCreditSheet.show(context),
              child: const Text('追加パック'),
            )
          else
            TextButton(
              onPressed: () =>
                  ref.read(trainerChatProvider.notifier).retryLast(),
              child: const Text('再試行'),
            ),
        ],
      ),
    );
  }

  Widget _buildDisclaimer(ColorScheme scheme) {
    return Container(
      width: double.infinity,
      color: scheme.surfaceContainerLow,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Text(
        '※ 一般的な情報提供であり、医療・診断の代替ではありません。症状や持病がある場合は専門家にご相談ください。',
        style: TextStyle(
          color: scheme.onSurfaceVariant,
          fontSize: 11,
          height: 1.4,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildInputBar(
    BuildContext context,
    ColorScheme scheme,
    TrainerChatState chat,
  ) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _inputController,
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText: 'メッセージを入力…',
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: chat.isLoading
                  ? null
                  : () => _send(_inputController.text),
              icon: const Icon(Icons.send_rounded),
            ),
          ],
        ),
      ),
    );
  }
}
