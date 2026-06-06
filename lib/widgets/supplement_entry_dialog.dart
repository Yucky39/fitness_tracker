import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/community_supplement_entry.dart';
import '../models/detailed_nutrients.dart';
import '../models/food_item.dart';
import '../models/micronutrients.dart';
import '../providers/meal_provider.dart';
import '../services/community_supplement_service.dart';

/// サプリメント専用（食事タイプは [MealType.supplement] 固定）
///
/// [contributeEnabled] と [userId] が揃っているとき、保存時に共有DB
/// （`community_supplements`）へ登録し、他ユーザーと内容を共有する。
Future<void> showSupplementEntryDialog({
  required BuildContext context,
  required MealNotifier notifier,
  FoodItem? existingItem,
  bool contributeEnabled = false,
  String? userId,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => _SupplementEntryDialog(
      existingItem: existingItem,
      notifier: notifier,
      contributeEnabled: contributeEnabled,
      userId: userId,
    ),
  );
}

class _SupplementEntryDialog extends StatefulWidget {
  const _SupplementEntryDialog({
    required this.existingItem,
    required this.notifier,
    required this.contributeEnabled,
    required this.userId,
  });

  final FoodItem? existingItem;
  final MealNotifier notifier;
  final bool contributeEnabled;
  final String? userId;

  @override
  State<_SupplementEntryDialog> createState() => _SupplementEntryDialogState();
}

class _SupplementEntryDialogState extends State<_SupplementEntryDialog> {
  late final TextEditingController _name;
  late final TextEditingController _brand;
  late final TextEditingController _serving;
  late final TextEditingController _calories;
  late final TextEditingController _protein;
  late final TextEditingController _fat;
  late final TextEditingController _carbs;
  late final TextEditingController _sugar;
  late final TextEditingController _fiber;
  late final TextEditingController _sodium;
  final Map<String, TextEditingController> _micro = {};
  final Map<String, TextEditingController> _detailed = {};

  @override
  void initState() {
    super.initState();
    final e = widget.existingItem;
    _name = TextEditingController(text: e?.name ?? '');
    _brand = TextEditingController();
    _serving = TextEditingController();
    _calories = TextEditingController(text: e != null ? '${e.calories}' : '');
    _protein = TextEditingController(text: e != null ? '${e.protein}' : '');
    _fat = TextEditingController(text: e != null ? '${e.fat}' : '');
    _carbs = TextEditingController(text: e != null ? '${e.carbs}' : '');
    _sugar = TextEditingController(
        text: e != null && e.sugar > 0 ? '${e.sugar}' : '');
    _fiber = TextEditingController(
        text: e != null && e.fiber > 0 ? '${e.fiber}' : '');
    _sodium = TextEditingController(
        text: e != null && e.sodium > 0 ? '${e.sodium}' : '');

    for (final k in Micronutrients.zero.toMap().keys) {
      _micro[k] = TextEditingController();
    }
    for (final k in DetailedNutrients.zero.toMap().keys) {
      _detailed[k] = TextEditingController();
    }

    if (e != null) {
      _fillMapControllers(e.micronutrients.toMap(), _micro);
      _fillMapControllers(e.detailedNutrients.toMap(), _detailed);
    }
  }

  void _fillMapControllers(
      Map<String, dynamic> map, Map<String, TextEditingController> ctrls) {
    for (final e in map.entries) {
      final c = ctrls[e.key];
      if (c == null) continue;
      final v = (e.value as num).toDouble();
      if (v <= 0) {
        c.text = '';
        continue;
      }
      c.text = v == v.roundToDouble()
          ? '${v.toInt()}'
          : v.toStringAsFixed(v.abs() >= 1 ? 2 : 3);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _brand.dispose();
    _serving.dispose();
    _calories.dispose();
    _protein.dispose();
    _fat.dispose();
    _carbs.dispose();
    _sugar.dispose();
    _fiber.dispose();
    _sodium.dispose();
    for (final c in _micro.values) {
      c.dispose();
    }
    for (final c in _detailed.values) {
      c.dispose();
    }
    super.dispose();
  }

  Micronutrients _parseMicro() {
    final m = <String, dynamic>{};
    for (final e in _micro.entries) {
      final t = e.value.text.replaceAll(',', '').trim();
      m[e.key] = double.tryParse(t) ?? 0.0;
    }
    return Micronutrients.fromMap(m);
  }

  DetailedNutrients _parseDetailed() {
    final m = <String, dynamic>{};
    for (final e in _detailed.entries) {
      final t = e.value.text.replaceAll(',', '').trim();
      m[e.key] = double.tryParse(t) ?? 0.0;
    }
    return DetailedNutrients.fromMap(m);
  }

  /// 共有DBから選択した登録内容をフォームへ反映する。
  void _applyEntry(CommunitySupplementEntry entry) {
    String fmt(double v) =>
        v == v.roundToDouble() ? '${v.toInt()}' : v.toStringAsFixed(1);
    setState(() {
      _name.text = entry.name;
      _brand.text = entry.brand;
      _serving.text = entry.servingNote;
      _calories.text = entry.calories > 0 ? '${entry.calories}' : '';
      _protein.text = entry.protein > 0 ? fmt(entry.protein) : '';
      _fat.text = entry.fat > 0 ? fmt(entry.fat) : '';
      _carbs.text = entry.carbs > 0 ? fmt(entry.carbs) : '';
      _sugar.text = entry.sugar > 0 ? fmt(entry.sugar) : '';
      _fiber.text = entry.fiber > 0 ? fmt(entry.fiber) : '';
      _sodium.text = entry.sodium > 0 ? fmt(entry.sodium) : '';
      _fillMapControllers(entry.micronutrients.toMap(), _micro);
      _fillMapControllers(entry.detailedNutrients.toMap(), _detailed);
    });
  }

  void _save() {
    if (_name.text.trim().isEmpty) return;
    final calories = int.tryParse(_calories.text) ?? 0;
    final protein = double.tryParse(_protein.text) ?? 0;
    final fat = double.tryParse(_fat.text) ?? 0;
    final carbs = double.tryParse(_carbs.text) ?? 0;
    final sugar = double.tryParse(_sugar.text) ?? 0;
    final fiber = double.tryParse(_fiber.text) ?? 0;
    final sodium = double.tryParse(_sodium.text) ?? 0;
    final micro = _parseMicro();
    final detailed = _parseDetailed();

    final existing = widget.existingItem;

    if (existing != null) {
      widget.notifier.updateFoodItem(
        existing.copyWith(
          name: _name.text.trim(),
          calories: calories,
          protein: protein,
          fat: fat,
          carbs: carbs,
          sugar: sugar,
          fiber: fiber,
          sodium: sodium,
          micronutrients: micro,
          detailedNutrients: detailed,
          mealType: MealType.supplement,
        ),
      );
    } else {
      widget.notifier.addFoodItem(
        name: _name.text.trim(),
        calories: calories,
        protein: protein,
        fat: fat,
        carbs: carbs,
        sugar: sugar,
        fiber: fiber,
        sodium: sodium,
        micronutrients: micro,
        detailedNutrients: detailed,
        mealType: MealType.supplement,
      );
    }

    _maybeContribute(
      calories: calories,
      protein: protein,
      fat: fat,
      carbs: carbs,
      sugar: sugar,
      fiber: fiber,
      sodium: sodium,
      micro: micro,
      detailed: detailed,
    );

    Navigator.of(context).pop();
  }

  /// 共有DBへ登録（fire-and-forget）。中身が空のものは登録しない。
  void _maybeContribute({
    required int calories,
    required double protein,
    required double fat,
    required double carbs,
    required double sugar,
    required double fiber,
    required double sodium,
    required Micronutrients micro,
    required DetailedNutrients detailed,
  }) {
    final userId = widget.userId;
    if (!widget.contributeEnabled || userId == null) return;
    final name = _name.text.trim();
    final hasContent = calories > 0 ||
        protein > 0 ||
        fat > 0 ||
        carbs > 0 ||
        micro.hasAnyPositive ||
        detailed.hasAnyPositive;
    if (name.isEmpty || !hasContent) return;

    CommunitySupplementService().contribute(CommunitySupplementEntry(
      id: const Uuid().v4(),
      name: name,
      nameSearch: name.toLowerCase(),
      brand: _brand.text.trim(),
      servingNote: _serving.text.trim(),
      calories: calories,
      protein: protein,
      fat: fat,
      carbs: carbs,
      sugar: sugar,
      fiber: fiber,
      sodium: sodium,
      micronutrients: micro,
      detailedNutrients: detailed,
      contributedBy: userId,
      createdAt: DateTime.now(),
    ));
  }

  Future<void> _openRecallDialog() async {
    final entry = await showDialog<CommunitySupplementEntry>(
      context: context,
      builder: (_) => const _SupplementRecallDialog(),
    );
    if (entry != null && mounted) {
      _applyEntry(entry);
      CommunitySupplementService().incrementUseCount(entry.id);
    }
  }

  Widget _fieldGrid(List<({String key, String label, String unit})> fields) {
    return LayoutBuilder(
      builder: (ctx, c) {
        final w = ((c.maxWidth - 8) / 2).clamp(120.0, 520.0);
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final f in fields)
              SizedBox(
                width: w,
                child: TextField(
                  controller: _detailed[f.key],
                  decoration: InputDecoration(
                    labelText: '${f.label} (${f.unit})',
                    isDense: true,
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _microGrid() {
    return LayoutBuilder(
      builder: (ctx, c) {
        final w = ((c.maxWidth - 8) / 2).clamp(120.0, 520.0);
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final f in Micronutrients.editorFields)
              SizedBox(
                width: w,
                child: TextField(
                  controller: _micro[f.key],
                  decoration: InputDecoration(
                    labelText: '${f.label} (${f.unit})',
                    isDense: true,
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existingItem != null;
    return AlertDialog(
      title: Text(isEdit ? 'サプリを編集' : 'サプリメントを記録'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '食事タイミングとは別のカテゴリとして記録されます（朝食・昼食などは選べません）。',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _openRecallDialog,
              icon: const Icon(Icons.search, size: 18),
              label: const Text('登録済みのサプリから探す'),
            ),
            const SizedBox(height: 4),
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: '製品名・内容'),
              textCapitalization: TextCapitalization.sentences,
            ),
            TextField(
              controller: _brand,
              decoration: const InputDecoration(
                labelText: 'ブランド・メーカー（任意）',
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
            TextField(
              controller: _serving,
              decoration: const InputDecoration(
                labelText: '1回分の目安（任意。例: 付属スプーン2杯 / 30g）',
              ),
            ),
            TextField(
              controller: _calories,
              decoration: const InputDecoration(labelText: 'カロリー (kcal)'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: _protein,
              decoration: const InputDecoration(labelText: 'タンパク質 (g)'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            TextField(
              controller: _fat,
              decoration: const InputDecoration(labelText: '脂質 (g)'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            TextField(
              controller: _carbs,
              decoration: const InputDecoration(labelText: '炭水化物 (g)'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            Theme(
              data:
                  Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('糖質・繊維・ナトリウム',
                    style: TextStyle(fontSize: 13)),
                children: [
                  TextField(
                    controller: _sugar,
                    decoration: const InputDecoration(labelText: '糖質 (g)'),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                  TextField(
                    controller: _fiber,
                    decoration: const InputDecoration(labelText: '食物繊維 (g)'),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                  TextField(
                    controller: _sodium,
                    decoration:
                        const InputDecoration(labelText: 'ナトリウム (mg)'),
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
            ),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('ビタミン・ミネラル（1回分）',
                  style: TextStyle(fontSize: 13)),
              children: [_microGrid()],
            ),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('詳細：脂肪酸・必須アミノ酸',
                  style: TextStyle(fontSize: 13)),
              children: [_fieldGrid(DetailedNutrients.editorFieldsFatty)],
            ),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('詳細：必須アミノ酸（9種, mg）',
                  style: TextStyle(fontSize: 13)),
              children: [_fieldGrid(DetailedNutrients.editorFieldsEaa)],
            ),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('詳細：その他アミノ酸（mg）',
                  style: TextStyle(fontSize: 13)),
              children: [_fieldGrid(DetailedNutrients.editorFieldsOtherAa)],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        TextButton(
          onPressed: _save,
          child: Text(isEdit ? '保存' : '追加'),
        ),
      ],
    );
  }
}

/// 共有DBに登録済みのサプリを検索し、名称と栄養内容を詳細確認して選ぶダイアログ。
class _SupplementRecallDialog extends StatefulWidget {
  const _SupplementRecallDialog();

  @override
  State<_SupplementRecallDialog> createState() =>
      _SupplementRecallDialogState();
}

class _SupplementRecallDialogState extends State<_SupplementRecallDialog> {
  final _search = TextEditingController();
  final _service = CommunitySupplementService();
  List<CommunitySupplementEntry> _results = [];
  bool _loading = false;
  bool _searched = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _doSearch() async {
    setState(() {
      _loading = true;
      _searched = true;
    });
    final res = await _service.search(_search.text);
    if (!mounted) return;
    setState(() {
      _results = res;
      _loading = false;
    });
  }

  List<String> _detailLines(CommunitySupplementEntry e) {
    final lines = <String>[
      'カロリー ${e.calories} kcal',
      'P ${e.protein}g / F ${e.fat}g / C ${e.carbs}g',
    ];
    if (e.sugar > 0) lines.add('糖質 ${e.sugar}g');
    if (e.fiber > 0) lines.add('食物繊維 ${e.fiber}g');
    if (e.sodium > 0) lines.add('ナトリウム ${e.sodium.toInt()}mg');
    lines.addAll(e.micronutrients.summaryLines());
    lines.addAll(e.detailedNutrients.summaryLines());
    return lines;
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.sizeOf(context);
    final showEmpty = _searched &&
        !_loading &&
        _results.isEmpty &&
        _search.text.trim().isNotEmpty;
    return AlertDialog(
      scrollable: true,
      constraints: BoxConstraints(maxWidth: 560, maxHeight: media.height * 0.85),
      title: const Text('登録済みサプリを検索'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _search,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: '製品名で検索',
                    isDense: true,
                  ),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _doSearch(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.search),
                onPressed: _loading ? null : _doSearch,
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (showEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('該当するサプリが見つかりませんでした。',
                  style: TextStyle(color: Colors.grey)),
            )
          else
            for (final e in _results)
              Card(
                margin: const EdgeInsets.symmetric(vertical: 3),
                child: Theme(
                  data: Theme.of(context)
                      .copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding:
                        const EdgeInsets.symmetric(horizontal: 12),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    title: Text(e.displayName,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      [
                        if (e.servingNote.trim().isNotEmpty) e.servingNote.trim(),
                        '${e.calories}kcal・P${e.protein}g',
                      ].join('  '),
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final line in _detailLines(e))
                              Padding(
                                padding: const EdgeInsets.only(bottom: 2),
                                child: Text('・$line',
                                    style: const TextStyle(fontSize: 12)),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton(
                          onPressed: () => Navigator.pop(context, e),
                          child: const Text('この内容を反映'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('閉じる'),
        ),
      ],
    );
  }
}
