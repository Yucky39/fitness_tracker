import 'package:flutter/material.dart';

class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

  static const _disclaimer =
      '本アプリの情報は一般的な健康・運動記録のサポートを目的としたものであり、'
      '医療上の診断、治療、予防を目的とするものではありません。'
      '健康状態に不安がある場合は医師などの専門家に相談してください。';

  static const _faqs = [
    _FaqItem(
      question: 'データはどこに保存されますか？',
      answer: 'すべての記録はお使いのデバイス内（SQLite）に保存されます。'
          'アカウント登録・ログインするとFirebaseクラウドにも同期され、'
          '複数デバイス間でデータを共有できます。',
    ),
    _FaqItem(
      question: 'APIキーはサーバーに送信されますか？',
      answer: 'APIキーはデバイス内にのみ保存されます。'
          'クラウド同期の対象外であり、外部サーバーに送信されることはありません。',
    ),
    _FaqItem(
      question: 'AIアドバイス機能を使うには何が必要ですか？',
      answer: 'Anthropic・OpenAI・Googleいずれかの有効なAPIキーが必要です。'
          'サイドバーの「AIキー・トレーニングアドバイス設定」から入力してください。',
    ),
    _FaqItem(
      question: 'アカウントを削除するとデータはどうなりますか？',
      answer: 'デバイス内のローカルデータとFirestoreのクラウドデータがすべて削除され、'
          '復元できません。削除前に「データ管理」からCSVエクスポートをお勧めします。',
    ),
    _FaqItem(
      question: 'カロリー計算の精度について教えてください。',
      answer: '基礎代謝はMifflin–St Jeor式、消費カロリーはTDEE（総消費エネルギー量）'
          'を元に算出しています。個人差があるため、あくまで目安としてお使いください。',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('よくある質問')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 免責事項バナー
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline,
                    color: colorScheme.onSecondaryContainer, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _disclaimer,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'よくある質問',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ..._faqs.map((item) => _FaqTile(item: item)),
        ],
      ),
    );
  }
}

class _FaqItem {
  final String question;
  final String answer;
  const _FaqItem({required this.question, required this.answer});
}

class _FaqTile extends StatelessWidget {
  final _FaqItem item;
  const _FaqTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 12),
      title: Text(
        item.question,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      children: [
        Text(
          item.answer,
          style: TextStyle(
            fontSize: 13,
            height: 1.55,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
