import 'package:flutter/material.dart';

import '../models/detailed_nutrients.dart';
import '../models/food_item.dart';
import '../models/micronutrients.dart';
import '../providers/meal_provider.dart';

/// サプリメント専用（食事タイプは [MealType.supplement] 固定）
Future<void> showSupplementEntryDialog({
  required BuildContext context,
  required MealNotifier notifier,
  FoodItem? existingItem,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => _SupplementEntryDialog(
      existingItem: existingItem,
      notifier: notifier,
    ),
  );
}

class _SupplementEntryDialog extends StatefulWidget {
  const _SupplementEntryDialog({
    required this.existingItem,
    required this.notifier,
  });

  final FoodItem? existingItem;
  final MealNotifier notifier;

  @override
  State<_SupplementEntryDialog> createState() => _SupplementEntryDialogState();
}

class _SupplementEntryDialogState extends State<_SupplementEntryDialog> {
  late final TextEditingController _name;
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

  void _fillMapControllers(Map<String, dynamic> map, Map<String, TextEditingController> ctrls) {
    for (final e in map.entries) {
      final c = ctrls[e.key];
      if (c == null) continue;
      final v = (e.value as num).toDouble();
      if (v <= 0) {
        c.text = '';
        continue;
      }
      c.text = v == v.roundToDouble() ? '${v.toInt()}' : v.toStringAsFixed(v.abs() >= 1 ? 2 : 3);
    }
  }

  @override
  void dispose() {
    _name.dispose();
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
    Navigator.of(context).pop();
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
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: '製品名・内容'),
              textCapitalization: TextCapitalization.sentences,
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
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('糖質・繊維・ナトリウム', style: TextStyle(fontSize: 13)),
                children: [
                  TextField(
                    controller: _sugar,
                    decoration: const InputDecoration(labelText: '糖質 (g)'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                  TextField(
                    controller: _fiber,
                    decoration: const InputDecoration(labelText: '食物繊維 (g)'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                  TextField(
                    controller: _sodium,
                    decoration: const InputDecoration(labelText: 'ナトリウム (mg)'),
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
            ),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('ビタミン・ミネラル（1回分）', style: TextStyle(fontSize: 13)),
              children: [_microGrid()],
            ),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('詳細：脂肪酸・必須アミノ酸', style: TextStyle(fontSize: 13)),
              children: [_fieldGrid(DetailedNutrients.editorFieldsFatty)],
            ),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('詳細：必須アミノ酸（9種）', style: TextStyle(fontSize: 13)),
              children: [_fieldGrid(DetailedNutrients.editorFieldsEaa)],
            ),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('詳細：その他アミノ酸', style: TextStyle(fontSize: 13)),
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
