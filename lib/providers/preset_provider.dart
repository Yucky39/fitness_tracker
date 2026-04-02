import 'package:riverpod/legacy.dart';
import '../models/food_item.dart';
import '../models/meal_preset.dart';
import '../services/database_service.dart';

class PresetState {
  final List<MealPreset> presets;
  const PresetState({this.presets = const []});
}

class PresetNotifier extends StateNotifier<PresetState> {
  PresetNotifier() : super(const PresetState()) {
    _load();
  }

  Future<void> _load() async {
    final adapter = await DatabaseService().database;
    final maps = await adapter.query(
      'meal_presets',
      orderBy: 'created_at DESC',
    );
    state = PresetState(presets: maps.map(MealPreset.fromMap).toList());
  }

  Future<void> savePreset(String name, List<FoodItem> items) async {
    final preset = MealPreset.create(name: name, items: items);
    final adapter = await DatabaseService().database;
    await adapter.insert('meal_presets', preset.toMap());
    await _load();
  }

  Future<void> deletePreset(String id) async {
    final adapter = await DatabaseService().database;
    await adapter.delete('meal_presets', where: 'id = ?', whereArgs: [id]);
    await _load();
  }
}

final presetProvider = StateNotifierProvider<PresetNotifier, PresetState>(
  (_) => PresetNotifier(),
);
