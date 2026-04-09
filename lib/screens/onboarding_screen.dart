import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/energy_profile.dart';
import '../providers/energy_profile_provider.dart';
import 'home_screen.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;
  static const _totalPages = 5;

  // プロフィール入力フォームの状態
  BiologicalSex? _sex;
  final _ageController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _targetWeightController = TextEditingController();
  final _weeksController = TextEditingController(text: '12');
  ActivityLevel _activityLevel = ActivityLevel.moderate;
  String _goal = 'cut'; // cut / bulk / maintain

  @override
  void dispose() {
    _pageController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _targetWeightController.dispose();
    _weeksController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _prevPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _complete() async {
    // プロフィールを保存
    final ep = EnergyProfileState(
      sex: _sex,
      age: int.tryParse(_ageController.text) ?? 0,
      heightCm: double.tryParse(_heightController.text) ?? 0,
      weightKg: double.tryParse(_weightController.text) ?? 0,
      targetWeightKg: double.tryParse(_targetWeightController.text) ?? 0,
      goalWeeks: int.tryParse(_weeksController.text) ?? 12,
      activityLevel: _activityLevel,
    );
    await ref.read(energyProfileProvider.notifier).save(ep);

    // オンボーディング完了フラグを保存
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboardingComplete', true);

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // プログレスバー
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (_currentPage + 1) / _totalPages,
                        minHeight: 6,
                        backgroundColor: scheme.surfaceContainerHighest,
                        color: scheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${_currentPage + 1} / $_totalPages',
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // ページビュー
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _currentPage = i),
                children: [
                  _buildWelcomePage(scheme),
                  _buildProfilePage(scheme),
                  _buildGoalPage(scheme),
                  _buildFeaturesPage(scheme),
                  _buildStartPage(scheme),
                ],
              ),
            ),
            // ナビゲーションボタン
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Row(
                children: [
                  if (_currentPage > 0)
                    OutlinedButton(
                      onPressed: _prevPage,
                      child: const Text('戻る'),
                    )
                  else
                    const SizedBox.shrink(),
                  const Spacer(),
                  if (_currentPage < _totalPages - 1)
                    FilledButton(
                      onPressed: _nextPage,
                      child: const Text('次へ'),
                    )
                  else
                    FilledButton(
                      onPressed: _complete,
                      child: const Text('始める'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── ページ1: ウェルカム ────────────────────────────────────────────────────

  Widget _buildWelcomePage(ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.fitness_center_rounded,
              size: 52,
              color: scheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Fitness Trackerへ\nようこそ',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          Text(
            '食事・トレーニング・睡眠・体重をAIと一緒に管理して、理想の体づくりをサポートします。',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _featurePill(Icons.restaurant_rounded, '食事管理', scheme),
              const SizedBox(width: 8),
              _featurePill(Icons.fitness_center_rounded, 'トレーニング', scheme),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _featurePill(Icons.bedtime_rounded, '睡眠', scheme),
              const SizedBox(width: 8),
              _featurePill(Icons.auto_awesome_rounded, 'AI連携', scheme),
            ],
          ),
        ],
      ),
    );
  }

  Widget _featurePill(IconData icon, String label, ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: scheme.onSecondaryContainer),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  color: scheme.onSecondaryContainer,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // ─── ページ2: 身体プロフィール ─────────────────────────────────────────────

  Widget _buildProfilePage(ColorScheme scheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(32, 16, 32, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '身体プロフィール',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            '目標カロリーの自動計算に使用します',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          // 性別
          Text('性別', style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final sex in BiologicalSex.values)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(sex.label),
                    selected: _sex == sex,
                    onSelected: (_) => setState(() => _sex = sex),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ageController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '年齢',
                    suffixText: '歳',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _heightController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '身長',
                    suffixText: 'cm',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _weightController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '現在の体重',
                    suffixText: 'kg',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _targetWeightController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '目標体重',
                    suffixText: 'kg',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _weeksController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: '目標達成期間',
              suffixText: '週間',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '※ 後から設定で変更できます',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  // ─── ページ3: 目標・活動量 ─────────────────────────────────────────────────

  Widget _buildGoalPage(ColorScheme scheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(32, 16, 32, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '目標と活動量',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            '目標に合わせたカロリー配分を計算します',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          Text('目標', style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          for (final entry in [
            ('cut', Icons.trending_down_rounded, '減量（ダイエット）'),
            ('maintain', Icons.trending_flat_rounded, '維持'),
            ('bulk', Icons.trending_up_rounded, '増量（筋肥大）'),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: () => setState(() => _goal = entry.$1),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: _goal == entry.$1
                          ? scheme.primary
                          : scheme.outlineVariant,
                      width: _goal == entry.$1 ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    color: _goal == entry.$1
                        ? scheme.primaryContainer.withValues(alpha: 0.4)
                        : null,
                  ),
                  child: Row(
                    children: [
                      Icon(entry.$2,
                          color: _goal == entry.$1
                              ? scheme.primary
                              : scheme.onSurfaceVariant),
                      const SizedBox(width: 12),
                      Text(entry.$3,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: _goal == entry.$1
                                ? scheme.primary
                                : null,
                          )),
                      const Spacer(),
                      if (_goal == entry.$1)
                        Icon(Icons.check_circle_rounded,
                            color: scheme.primary),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 24),
          Text('活動量', style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          DropdownButtonFormField<ActivityLevel>(
            initialValue: _activityLevel,
            decoration: const InputDecoration(border: OutlineInputBorder()),
            items: ActivityLevel.values
                .map((a) => DropdownMenuItem(
                      value: a,
                      child: Text(a.label, overflow: TextOverflow.ellipsis),
                    ))
                .toList(),
            onChanged: (v) {
              if (v != null) setState(() => _activityLevel = v);
            },
          ),
        ],
      ),
    );
  }

  // ─── ページ4: 機能紹介 ─────────────────────────────────────────────────────

  Widget _buildFeaturesPage(ColorScheme scheme) {
    final features = [
      (
        Icons.restaurant_rounded,
        '食事トラッキング',
        'バーコードスキャン・AI画像解析で簡単記録。マクロ栄養素を自動計算。',
        scheme.primaryContainer,
        scheme.onPrimaryContainer,
      ),
      (
        Icons.fitness_center_rounded,
        'トレーニング管理',
        '種目・重量・セット数を記録。1RMと進捗をグラフで確認。',
        scheme.secondaryContainer,
        scheme.onSecondaryContainer,
      ),
      (
        Icons.bedtime_rounded,
        '睡眠・歩数連携',
        'HealthKitと連携して睡眠・歩数を自動取得。',
        scheme.tertiaryContainer,
        scheme.onTertiaryContainer,
      ),
      (
        Icons.auto_awesome_rounded,
        'AIアドバイス',
        'Claude/GPT/Geminiが食事とトレーニングにパーソナライズされたアドバイスを提供。',
        scheme.surfaceContainerHigh,
        scheme.onSurface,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text(
            '主な機能',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.separated(
              itemCount: features.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) {
                final f = features[i];
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: f.$4,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Icon(f.$1, size: 36, color: f.$5),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(f.$2,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: f.$5,
                                )),
                            const SizedBox(height: 4),
                            Text(f.$3,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: f.$5,
                                )),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ─── ページ5: 開始 ─────────────────────────────────────────────────────────

  Widget _buildStartPage(ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.rocket_launch_rounded,
              size: 52,
              color: scheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            '準備完了！',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          Text(
            'あなたの目標達成をサポートします。まずはダッシュボードから始めましょう。',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 32),
          Card(
            color: scheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _startTip(Icons.qr_code_scanner_rounded,
                      'バーコードスキャンで食品を素早く登録', scheme),
                  const SizedBox(height: 8),
                  _startTip(Icons.settings_rounded,
                      '設定からAI APIキーを追加するとアドバイスが受けられます', scheme),
                  const SizedBox(height: 8),
                  _startTip(Icons.health_and_safety_rounded,
                      'ヘルスケアアプリと連携すると睡眠・歩数が自動取得できます', scheme),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _startTip(IconData icon, String text, ColorScheme scheme) {
    return Row(
      children: [
        Icon(icon, size: 20, color: scheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 13)),
        ),
      ],
    );
  }
}
