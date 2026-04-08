import 'package:flutter/material.dart';
import '../models/food_item.dart';
import '../models/recipe_ingredient.dart';
import '../services/food_search_service.dart';
import '../services/recipe_nutrition_calculator.dart';

class _LineControllers {
  _LineControllers()
      : name = TextEditingController(),
        amount = TextEditingController(text: '100'),
        gramsPerPiece = TextEditingController(),
        calories = TextEditingController(),
        protein = TextEditingController(),
        fat = TextEditingController(),
        carbs = TextEditingController(),
        sugar = TextEditingController(),
        fiber = TextEditingController(),
        sodium = TextEditingController();

  final TextEditingController name;
  final TextEditingController amount;
  final TextEditingController gramsPerPiece;
  final TextEditingController calories;
  final TextEditingController protein;
  final TextEditingController fat;
  final TextEditingController carbs;
  final TextEditingController sugar;
  final TextEditingController fiber;
  final TextEditingController sodium;
  RecipeQuantityUnit quantityUnit = RecipeQuantityUnit.gram;
  RecipeCookingMethod cooking = RecipeCookingMethod.raw;

  void dispose() {
    name.dispose();
    amount.dispose();
    gramsPerPiece.dispose();
    calories.dispose();
    protein.dispose();
    fat.dispose();
    carbs.dispose();
    sugar.dispose();
    fiber.dispose();
    sodium.dispose();
  }

  RecipeIngredientLine? toLine() {
    final n = name.text.trim();
    final amt = double.tryParse(amount.text.replaceAll(',', '')) ?? 0;
    if (n.isEmpty || amt <= 0) return null;
    final gpp = double.tryParse(gramsPerPiece.text.replaceAll(',', ''));
    final grams = RecipeQuantityUnit.amountToGrams(
      quantityUnit,
      amt,
      gramsPerPiece: gpp,
    );
    if (grams == null || grams <= 0) return null;
    final cal = int.tryParse(calories.text) ?? 0;
    final p = double.tryParse(protein.text) ?? 0;
    final f = double.tryParse(fat.text) ?? 0;
    final c = double.tryParse(carbs.text) ?? 0;
    final su = double.tryParse(sugar.text) ?? 0;
    final fi = double.tryParse(fiber.text) ?? 0;
    final so = double.tryParse(sodium.text) ?? 0;
    return RecipeIngredientLine(
      name: n,
      grams: grams,
      amount: amt,
      quantityUnit: quantityUnit,
      gramsPerPiece: quantityUnit == RecipeQuantityUnit.piece ? gpp : null,
      per100g: NutritionPer100g(
        calories: cal,
        protein: p,
        fat: f,
        carbs: c,
        sugar: su,
        fiber: fi,
        sodium: so,
      ),
      cookingMethod: cooking,
    );
  }

  /// 表示用：現在の入力から換算 g
  double? previewGrams() {
    final amt = double.tryParse(amount.text.replaceAll(',', '')) ?? 0;
    if (amt <= 0) return null;
    final gpp = double.tryParse(gramsPerPiece.text.replaceAll(',', ''));
    return RecipeQuantityUnit.amountToGrams(
      quantityUnit,
      amt,
      gramsPerPiece: gpp,
    );
  }
}

/// レシピ（食材・分量・調理法）を入力してプリセット保存するボトムシート
class RecipePresetEditorSheet extends StatefulWidget {
  final void Function(String name, List<RecipeIngredientLine> lines, MealType mealType)
      onSave;

  const RecipePresetEditorSheet({super.key, required this.onSave});

  @override
  State<RecipePresetEditorSheet> createState() => _RecipePresetEditorSheetState();
}

class _RecipePresetEditorSheetState extends State<RecipePresetEditorSheet> {
  final _recipeNameController = TextEditingController();
  MealType _mealType = MealType.detectFromTime(DateTime.now());
  final List<_LineControllers> _lines = [_LineControllers()];

  @override
  void dispose() {
    _recipeNameController.dispose();
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  void _addLine() {
    setState(() => _lines.add(_LineControllers()));
  }

  void _removeLine(int i) {
    if (_lines.length <= 1) return;
    setState(() {
      _lines[i].dispose();
      _lines.removeAt(i);
    });
  }

  List<RecipeIngredientLine> _collectLines() {
    final out = <RecipeIngredientLine>[];
    for (final l in _lines) {
      final line = l.toLine();
      if (line != null) out.add(line);
    }
    return out;
  }

  String _unitHint(RecipeQuantityUnit u) {
    switch (u) {
      case RecipeQuantityUnit.gram:
        return 'そのままg';
      case RecipeQuantityUnit.milliliter:
        return '水など1ml≈1g';
      case RecipeQuantityUnit.piece:
        return '下欄に1個のg';
      case RecipeQuantityUnit.tablespoon:
        return '15ml≈15g';
      case RecipeQuantityUnit.teaspoon:
        return '5ml≈5g';
      case RecipeQuantityUnit.cup:
        return '200ml≈200g';
    }
  }

  Future<void> _openSearch(int lineIndex) async {
    final line = _lines[lineIndex];
    final searchController = TextEditingController();
    final quantityController = TextEditingController(text: line.amount.text);
    final service = FoodSearchService();
    List<FoodSearchResult> results = [];
    var isSearching = false;
    String? error;

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('食品検索（100gあたりの値）'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '日本語は辞書で英語キーワードに変換してから検索します。'
                    'ヒットしない場合は成分表ベースの目安が表示されることがあります。',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: searchController,
                          decoration: const InputDecoration(
                            labelText: 'キーワード',
                            hintText: '例：卵、鶏むね肉、yogurt',
                          ),
                          onSubmitted: (_) async {
                            setDialogState(() {
                              isSearching = true;
                              error = null;
                            });
                            try {
                              final r = await service.search(searchController.text);
                              setDialogState(() {
                                results = r;
                                isSearching = false;
                              });
                            } catch (_) {
                              setDialogState(() {
                                error = '検索に失敗しました';
                                isSearching = false;
                              });
                            }
                          },
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.search),
                        onPressed: () async {
                          setDialogState(() {
                            isSearching = true;
                            error = null;
                          });
                          try {
                            final r = await service.search(searchController.text);
                            setDialogState(() {
                              results = r;
                              isSearching = false;
                            });
                          } catch (_) {
                            setDialogState(() {
                              error = '検索に失敗しました';
                              isSearching = false;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Text('この食材の分量 ', style: TextStyle(fontSize: 13)),
                      SizedBox(
                        width: 80,
                        child: TextField(
                          controller: quantityController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            suffix: Text('g'),
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (isSearching)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(),
                    )
                  else if (error != null)
                    Text(error!, style: const TextStyle(color: Colors.red))
                  else if (results.isNotEmpty)
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 220),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: results.length,
                        itemBuilder: (context, i) {
                          final r = results[i];
                          return ListTile(
                            dense: true,
                            title: Text(
                              r.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '${r.caloriesPer100g}kcal/100g',
                              style: const TextStyle(fontSize: 11),
                            ),
                            onTap: () {
                              final line = _lines[lineIndex];
                              line.name.text = r.name;
                              line.amount.text = quantityController.text;
                              line.quantityUnit = RecipeQuantityUnit.gram;
                              line.calories.text = '${r.caloriesPer100g}';
                              line.protein.text = r.proteinPer100g.toStringAsFixed(1);
                              line.fat.text = r.fatPer100g.toStringAsFixed(1);
                              line.carbs.text = r.carbsPer100g.toStringAsFixed(1);
                              line.sugar.text = '0';
                              line.fiber.text = '0';
                              line.sodium.text = '0';
                              Navigator.pop(dialogContext);
                              setState(() {});
                            },
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('閉じる'),
              ),
            ],
          );
        },
      ),
    );
    searchController.dispose();
    quantityController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lines = _collectLines();
    final preview =
        lines.isEmpty ? RecipeNutritionTotals.zero : RecipeNutritionCalculator.computeTotal(lines);

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '自分のレシピを保存',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  '食材ごとに100gあたりの栄養と分量（g・個・大さじ・ml など）、調理法を入れると、'
                  'カロリーとPFCなどを合算します。個数は「1個あたりのg」が必要です（調理法は油の目安補正に使います）。',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  children: [
                    TextField(
                      controller: _recipeNameController,
                      decoration: const InputDecoration(
                        labelText: 'レシピ名',
                        hintText: '例：鶏むねのトマト煮',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    const Text('食事タイプ', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      children: MealType.values.map((t) {
                        return ChoiceChip(
                          label: Text(t.label),
                          selected: _mealType == t,
                          onSelected: (_) => setState(() => _mealType = t),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('食材', style: TextStyle(fontWeight: FontWeight.w600)),
                        TextButton.icon(
                          onPressed: _addLine,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('行を追加'),
                        ),
                      ],
                    ),
                    for (var i = 0; i < _lines.length; i++) _buildLineCard(context, i),
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('計算結果（合計）',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Text(
                              '${preview.calories} kcal  '
                              'P ${preview.protein.toStringAsFixed(1)}g  '
                              'F ${preview.fat.toStringAsFixed(1)}g  '
                              'C ${preview.carbs.toStringAsFixed(1)}g',
                              style: const TextStyle(fontSize: 14),
                            ),
                            if (preview.sugar > 0 || preview.fiber > 0 || preview.sodium > 0)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  '糖 ${preview.sugar.toStringAsFixed(1)}g  '
                                  '食物繊維 ${preview.fiber.toStringAsFixed(1)}g  '
                                  'ナトリウム ${preview.sodium.toStringAsFixed(0)}mg',
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: lines.isEmpty || _recipeNameController.text.trim().isEmpty
                          ? null
                          : () {
                              widget.onSave(
                                _recipeNameController.text.trim(),
                                lines,
                                _mealType,
                              );
                              Navigator.pop(context);
                            },
                      child: const Text('プリセットに保存'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLineCard(BuildContext context, int i) {
    final line = _lines[i];
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('食材 ${i + 1}', style: const TextStyle(fontWeight: FontWeight.w600)),
                const Spacer(),
                if (_lines.length > 1)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                    onPressed: () => _removeLine(i),
                    tooltip: 'この行を削除',
                  ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: line.name,
                    decoration: const InputDecoration(
                      labelText: '名前',
                      isDense: true,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: line.amount,
                    decoration: const InputDecoration(
                      labelText: '分量（数値）',
                      isDense: true,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            InputDecorator(
              decoration: const InputDecoration(
                labelText: '単位',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<RecipeQuantityUnit>(
                  value: line.quantityUnit,
                  isExpanded: true,
                  isDense: true,
                  items: RecipeQuantityUnit.values
                      .map(
                        (u) => DropdownMenuItem(
                          value: u,
                          child: Text(
                            '${u.shortLabel} — ${_unitHint(u)}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setState(() => line.quantityUnit = v);
                    }
                  },
                ),
              ),
            ),
            if (line.quantityUnit == RecipeQuantityUnit.piece) ...[
              const SizedBox(height: 6),
              TextField(
                controller: line.gramsPerPiece,
                decoration: const InputDecoration(
                  labelText: '1個あたりの重量（g）',
                  hintText: '例：卵なら約60',
                  isDense: true,
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
              ),
            ],
            if (line.previewGrams() != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '→ 栄養計算用 換算 ${line.previewGrams()!.toStringAsFixed(1)} g',
                  style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.primary),
                ),
              )
            else if (line.quantityUnit == RecipeQuantityUnit.piece &&
                (double.tryParse(line.gramsPerPiece.text) ?? 0) <= 0)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  '個数のときは「1個あたりの重量」を入力してください',
                  style: TextStyle(fontSize: 11, color: Colors.orange),
                ),
              ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () => _openSearch(i),
                icon: const Icon(Icons.search, size: 16),
                label: const Text('食品検索で100g値を入れる', style: TextStyle(fontSize: 12)),
              ),
            ),
            const SizedBox(height: 6),
            const Text('100gあたり', style: TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: line.calories,
                    decoration: const InputDecoration(labelText: 'kcal', isDense: true),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: TextField(
                    controller: line.protein,
                    decoration: const InputDecoration(labelText: 'P g', isDense: true),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: TextField(
                    controller: line.fat,
                    decoration: const InputDecoration(labelText: 'F g', isDense: true),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: TextField(
                    controller: line.carbs,
                    decoration: const InputDecoration(labelText: 'C g', isDense: true),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: line.sugar,
                    decoration: const InputDecoration(labelText: '糖 g', isDense: true),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: TextField(
                    controller: line.fiber,
                    decoration: const InputDecoration(labelText: '繊維 g', isDense: true),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: TextField(
                    controller: line.sodium,
                    decoration: const InputDecoration(labelText: 'Na mg', isDense: true),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            InputDecorator(
              decoration: const InputDecoration(
                labelText: '調理法',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<RecipeCookingMethod>(
                  value: line.cooking,
                  isExpanded: true,
                  isDense: true,
                  items: RecipeCookingMethod.values
                      .map(
                        (m) => DropdownMenuItem(
                          value: m,
                          child: Text(m.label, style: const TextStyle(fontSize: 13)),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setState(() => line.cooking = v);
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
