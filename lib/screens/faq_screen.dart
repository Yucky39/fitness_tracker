import 'package:flutter/material.dart';

import '../utils/open_url.dart';

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
      answer: 'プレミアムプラン加入者はAPIキー不要でAI機能を利用できます。'
          '未加入の場合は、Anthropic・OpenAI・Googleいずれかの有効なAPIキーが必要です。'
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

  static const _sources = [
    _SourceItem(
      title: 'World Health Organization: Physical activity',
      url: 'https://www.who.int/news-room/fact-sheets/detail/physical-activity',
    ),
    _SourceItem(
      title: 'U.S. Department of Health and Human Services: Physical Activity Guidelines',
      url:
          'https://health.gov/our-work/nutrition-physical-activity/physical-activity-guidelines',
    ),
    _SourceItem(
      title: 'CDC: Healthy Weight, Nutrition, and Physical Activity',
      url: 'https://www.cdc.gov/healthy-weight-growth/',
    ),
    _SourceItem(
      title:
          'Mifflin MD et al. A new predictive equation for resting energy expenditure in healthy individuals',
      url: 'https://pubmed.ncbi.nlm.nih.gov/2305711/',
    ),
    _SourceItem(
      title: 'National Academies: Dietary Reference Intakes',
      url: 'https://nap.nationalacademies.org/topic/380/food-and-nutrition',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('FAQ / Disclaimer'),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(28),
          child: Padding(
            padding: EdgeInsets.only(left: 16, right: 16, bottom: 10),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'よくある質問・免責事項',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
          const SizedBox(height: 20),
          Text(
            'Sources and references',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            '情報源・参考資料',
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '本アプリ内のカロリー推定、身体活動、栄養、健康管理に関する一般情報は、'
            '以下の公開資料を参考にしています。各項目をタップするとブラウザで開きます。',
            style: TextStyle(
              fontSize: 13,
              height: 1.55,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          ..._sources.map((source) => _SourceTile(source: source)),
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

class _SourceItem {
  final String title;
  final String url;
  const _SourceItem({required this.title, required this.url});
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

class _SourceTile extends StatelessWidget {
  final _SourceItem source;
  const _SourceTile({required this.source});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => openExternalUrl(context, source.url),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      source.title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      source.url,
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.primary,
                        decoration: TextDecoration.underline,
                        decorationColor: colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.open_in_new, size: 18, color: colorScheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}
