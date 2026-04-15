import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/food_item.dart';
import '../models/training_log.dart';
import '../providers/energy_profile_provider.dart';
import '../providers/settings_provider.dart';
import '../services/database_service.dart';
import '../services/review_advice_service.dart';
import '../services/training_calorie_calculator.dart';

// ── State classes ──────────────────────────────────────────────────────────

class _ReviewData {
  final List<TrainingLog> trainingLogs;
  final List<FoodItem> foodItems;
  final bool isLoading;
  final String? aiReview;
  final bool aiLoading;
  final String? aiError;

  const _ReviewData({
    this.trainingLogs = const [],
    this.foodItems = const [],
    this.isLoading = true,
    this.aiReview,
    this.aiLoading = false,
    this.aiError,
  });

  _ReviewData copyWith({
    List<TrainingLog>? trainingLogs,
    List<FoodItem>? foodItems,
    bool? isLoading,
    String? aiReview,
    bool? aiLoading,
    String? aiError,
    bool clearAiReview = false,
    bool clearAiError = false,
  }) {
    return _ReviewData(
      trainingLogs: trainingLogs ?? this.trainingLogs,
      foodItems: foodItems ?? this.foodItems,
      isLoading: isLoading ?? this.isLoading,
      aiReview: clearAiReview ? null : (aiReview ?? this.aiReview),
      aiLoading: aiLoading ?? this.aiLoading,
      aiError: clearAiError ? null : (aiError ?? this.aiError),
    );
  }
}

// ── Screen ─────────────────────────────────────────────────────────────────

class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({super.key});

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // 週間タブ用
  late DateTime _weekStart;
  late DateTime _weekEnd;
  _ReviewData _weekData = const _ReviewData();

  // 月間タブ用
  late DateTime _monthStart;
  late DateTime _monthEnd;
  _ReviewData _monthData = const _ReviewData();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);

    final now = DateTime.now();
    // 今週の月曜日を計算
    final weekday = now.weekday; // 1=月, 7=日
    _weekStart = DateTime(now.year, now.month, now.day - (weekday - 1));
    _weekEnd = _weekStart.add(const Duration(days: 6));

    // 今月の開始・終了
    _monthStart = DateTime(now.year, now.month, 1);
    _monthEnd = DateTime(now.year, now.month + 1, 0); // 末日

    _loadWeekData();
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.index == 0 && _weekData.isLoading) {
      _loadWeekData();
    } else if (_tabController.index == 1 && _monthData.isLoading) {
      _loadMonthData();
    }
  }

  // ── Data loading ─────────────────────────────────────────────────────────

  Future<void> _loadWeekData() async {
    setState(() => _weekData = _weekData.copyWith(isLoading: true));
    final db = await DatabaseService().database;

    final startStr = DateTime(_weekStart.year, _weekStart.month, _weekStart.day).toIso8601String();
    final endStr = DateTime(_weekEnd.year, _weekEnd.month, _weekEnd.day, 23, 59, 59).toIso8601String();

    final trainingMaps = await db.query(
      'training_logs',
      where: 'date BETWEEN ? AND ?',
      whereArgs: [startStr, endStr],
      orderBy: 'date ASC',
    );
    final foodMaps = await db.query(
      'food_items',
      where: 'date BETWEEN ? AND ?',
      whereArgs: [startStr, endStr],
      orderBy: 'date ASC',
    );

    if (mounted) {
      setState(() {
        _weekData = _weekData.copyWith(
          trainingLogs: trainingMaps.map(TrainingLog.fromMap).toList(),
          foodItems: foodMaps.map(FoodItem.fromMap).toList(),
          isLoading: false,
        );
      });
    }
  }

  Future<void> _loadMonthData() async {
    setState(() => _monthData = _monthData.copyWith(isLoading: true));
    final db = await DatabaseService().database;

    final startStr = DateTime(_monthStart.year, _monthStart.month, _monthStart.day).toIso8601String();
    final endStr = DateTime(_monthEnd.year, _monthEnd.month, _monthEnd.day, 23, 59, 59).toIso8601String();

    final trainingMaps = await db.query(
      'training_logs',
      where: 'date BETWEEN ? AND ?',
      whereArgs: [startStr, endStr],
      orderBy: 'date ASC',
    );
    final foodMaps = await db.query(
      'food_items',
      where: 'date BETWEEN ? AND ?',
      whereArgs: [startStr, endStr],
      orderBy: 'date ASC',
    );

    if (mounted) {
      setState(() {
        _monthData = _monthData.copyWith(
          trainingLogs: trainingMaps.map(TrainingLog.fromMap).toList(),
          foodItems: foodMaps.map(FoodItem.fromMap).toList(),
          isLoading: false,
        );
      });
    }
  }

  // ── Period navigation ─────────────────────────────────────────────────────

  void _prevWeek() {
    setState(() {
      _weekStart = _weekStart.subtract(const Duration(days: 7));
      _weekEnd = _weekEnd.subtract(const Duration(days: 7));
      _weekData = _ReviewData();
    });
    _loadWeekData();
  }

  void _nextWeek() {
    final now = DateTime.now();
    final nextStart = _weekStart.add(const Duration(days: 7));
    if (nextStart.isAfter(now)) return;
    setState(() {
      _weekStart = nextStart;
      _weekEnd = _weekEnd.add(const Duration(days: 7));
      _weekData = _ReviewData();
    });
    _loadWeekData();
  }

  void _prevMonth() {
    setState(() {
      _monthStart = DateTime(_monthStart.year, _monthStart.month - 1, 1);
      _monthEnd = DateTime(_monthStart.year, _monthStart.month + 1, 0);
      _monthData = _ReviewData();
    });
    _loadMonthData();
  }

  void _nextMonth() {
    final now = DateTime.now();
    final nextMonth = DateTime(_monthStart.year, _monthStart.month + 1, 1);
    if (nextMonth.isAfter(now)) return;
    setState(() {
      _monthStart = nextMonth;
      _monthEnd = DateTime(_monthStart.year, _monthStart.month + 1, 0);
      _monthData = _ReviewData();
    });
    _loadMonthData();
  }

  // ── AI review ─────────────────────────────────────────────────────────────

  Future<void> _fetchWeeklyReview() async {
    final settings = ref.read(settingsProvider);
    final apiKey = settings.currentApiKey;
    if (apiKey.isEmpty) {
      setState(() {
        _weekData = _weekData.copyWith(
          aiError: '${settings.selectedProvider.label} のAPIキーが設定されていません。⚙️設定から入力してください。',
        );
      });
      return;
    }

    setState(() {
      _weekData = _weekData.copyWith(
        aiLoading: true,
        clearAiError: true,
        clearAiReview: true,
      );
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final bodyWeightKg = ref.read(energyProfileProvider).weightKg;

      final text = await ReviewAdviceService().getWeeklyReview(
        logs: _weekData.trainingLogs,
        foodItems: _weekData.foodItems,
        weekStart: _weekStart,
        weekEnd: _weekEnd,
        calorieGoal: prefs.getInt('calorieGoal') ?? 2000,
        proteinGoal: prefs.getDouble('proteinGoal') ?? 150,
        fatGoal: prefs.getDouble('fatGoal') ?? 60,
        carbsGoal: prefs.getDouble('carbsGoal') ?? 200,
        bodyWeightKg: bodyWeightKg > 0
            ? bodyWeightKg
            : TrainingCalorieCalculator.defaultBodyWeightKg,
        adviceLevel: settings.adviceLevel,
        apiKey: apiKey,
        provider: settings.selectedProvider,
        model: settings.currentModel,
      );

      if (mounted) {
        setState(() {
          _weekData = _weekData.copyWith(aiReview: text, aiLoading: false);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _weekData = _weekData.copyWith(
            aiLoading: false,
            aiError: e.toString().replaceFirst('Exception: ', ''),
          );
        });
      }
    }
  }

  Future<void> _fetchMonthlyReview() async {
    final settings = ref.read(settingsProvider);
    final apiKey = settings.currentApiKey;
    if (apiKey.isEmpty) {
      setState(() {
        _monthData = _monthData.copyWith(
          aiError: '${settings.selectedProvider.label} のAPIキーが設定されていません。⚙️設定から入力してください。',
        );
      });
      return;
    }

    setState(() {
      _monthData = _monthData.copyWith(
        aiLoading: true,
        clearAiError: true,
        clearAiReview: true,
      );
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final bodyWeightKg = ref.read(energyProfileProvider).weightKg;

      final text = await ReviewAdviceService().getMonthlyReview(
        logs: _monthData.trainingLogs,
        foodItems: _monthData.foodItems,
        monthStart: _monthStart,
        monthEnd: _monthEnd,
        calorieGoal: prefs.getInt('calorieGoal') ?? 2000,
        proteinGoal: prefs.getDouble('proteinGoal') ?? 150,
        fatGoal: prefs.getDouble('fatGoal') ?? 60,
        carbsGoal: prefs.getDouble('carbsGoal') ?? 200,
        bodyWeightKg: bodyWeightKg > 0
            ? bodyWeightKg
            : TrainingCalorieCalculator.defaultBodyWeightKg,
        adviceLevel: settings.adviceLevel,
        apiKey: apiKey,
        provider: settings.selectedProvider,
        model: settings.currentModel,
      );

      if (mounted) {
        setState(() {
          _monthData = _monthData.copyWith(aiReview: text, aiLoading: false);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _monthData = _monthData.copyWith(
            aiLoading: false,
            aiError: e.toString().replaceFirst('Exception: ', ''),
          );
        });
      }
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('振り返り'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.view_week), text: '週間'),
            Tab(icon: Icon(Icons.calendar_month), text: '月間'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildWeeklyTab(),
          _buildMonthlyTab(),
        ],
      ),
    );
  }

  // ── Weekly tab ─────────────────────────────────────────────────────────────

  Widget _buildWeeklyTab() {
    final fmt = DateFormat('M/d');
    final now = DateTime.now();
    final isCurrentWeek = _weekEnd.isAfter(now) || _isSameDay(_weekEnd, now);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Period navigation
          _PeriodNavigation(
            label: '${fmt.format(_weekStart)} 〜 ${fmt.format(_weekEnd)}',
            onPrev: _prevWeek,
            onNext: isCurrentWeek ? null : _nextWeek,
            onRefresh: _loadWeekData,
          ),
          const SizedBox(height: 12),

          if (_weekData.isLoading)
            const Center(child: CircularProgressIndicator())
          else ...[
            _buildTrainingSummaryCard(
              logs: _weekData.trainingLogs,
              periodLabel: 'この週',
              showDayBreakdown: true,
            ),
            const SizedBox(height: 8),
            _buildFoodSummaryCard(
              foodItems: _weekData.foodItems,
              periodLabel: 'この週',
            ),
            const SizedBox(height: 8),
            _buildAiReviewCard(
              reviewData: _weekData,
              onFetch: _fetchWeeklyReview,
              onRefresh: () {
                setState(() => _weekData = _weekData.copyWith(clearAiReview: true, clearAiError: true));
                _fetchWeeklyReview();
              },
              periodLabel: '週間',
            ),
          ],
        ],
      ),
    );
  }

  // ── Monthly tab ────────────────────────────────────────────────────────────

  Widget _buildMonthlyTab() {
    final fmt = DateFormat('yyyy年M月');
    final now = DateTime.now();
    final isCurrentMonth = _monthStart.year == now.year && _monthStart.month == now.month;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Period navigation
          _PeriodNavigation(
            label: fmt.format(_monthStart),
            onPrev: _prevMonth,
            onNext: isCurrentMonth ? null : _nextMonth,
            onRefresh: _loadMonthData,
          ),
          const SizedBox(height: 12),

          if (_monthData.isLoading)
            const Center(child: CircularProgressIndicator())
          else ...[
            _buildMonthCalendar(),
            const SizedBox(height: 8),
            _buildTrainingSummaryCard(
              logs: _monthData.trainingLogs,
              periodLabel: 'この月',
              showDayBreakdown: false,
            ),
            const SizedBox(height: 8),
            _buildFoodSummaryCard(
              foodItems: _monthData.foodItems,
              periodLabel: 'この月',
            ),
            const SizedBox(height: 8),
            _buildAiReviewCard(
              reviewData: _monthData,
              onFetch: _fetchMonthlyReview,
              onRefresh: () {
                setState(() => _monthData = _monthData.copyWith(clearAiReview: true, clearAiError: true));
                _fetchMonthlyReview();
              },
              periodLabel: '月間',
            ),
          ],
        ],
      ),
    );
  }

  // ── Shared widgets ─────────────────────────────────────────────────────────

  Widget _buildTrainingSummaryCard({
    required List<TrainingLog> logs,
    required String periodLabel,
    required bool showDayBreakdown,
  }) {
    final bodyWeightKg = ref.watch(energyProfileProvider).weightKg;
    final effectiveBw = bodyWeightKg > 0
        ? bodyWeightKg
        : TrainingCalorieCalculator.defaultBodyWeightKg;

    final daySet = <String>{};
    for (final l in logs) {
      final d = l.date.toLocal();
      daySet.add('${d.year}-${d.month}-${d.day}');
    }
    final strengthLogs = logs.where((l) => l.exerciseType != ExerciseType.cardio).toList();
    final cardioLogs = logs.where((l) => l.exerciseType == ExerciseType.cardio).toList();
    final totalKcal = TrainingCalorieCalculator.total(logs, bodyWeightKg: effectiveBw);
    final totalVolume = strengthLogs.fold(0.0, (s, l) => s + l.totalVolume);
    final totalCardioKm = cardioLogs.fold(0.0, (s, l) => s + l.distanceKm);
    final exerciseNames = logs.map((l) => l.exerciseName).toSet();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.fitness_center, size: 18),
                const SizedBox(width: 8),
                Text(
                  'トレーニング（$periodLabel）',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (logs.isEmpty)
              const Text('記録なし', style: TextStyle(color: Colors.grey))
            else ...[
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  _StatChip(
                    icon: Icons.calendar_today,
                    label: 'ワークアウト',
                    value: '${daySet.length}日',
                  ),
                  _StatChip(
                    icon: Icons.local_fire_department,
                    label: '消費カロリー',
                    value: '${totalKcal.round()} kcal',
                  ),
                  if (exerciseNames.isNotEmpty)
                    _StatChip(
                      icon: Icons.list_alt,
                      label: '種目数',
                      value: '${exerciseNames.length}種目',
                    ),
                  if (totalVolume > 0)
                    _StatChip(
                      icon: Icons.bar_chart,
                      label: '総ボリューム',
                      value: totalVolume >= 1000
                          ? '${(totalVolume / 1000).toStringAsFixed(1)} t'
                          : '${totalVolume.round()} kg',
                    ),
                  if (totalCardioKm > 0)
                    _StatChip(
                      icon: Icons.directions_run,
                      label: '走行距離',
                      value: '${totalCardioKm.toStringAsFixed(1)} km',
                    ),
                ],
              ),
              if (showDayBreakdown && daySet.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text('日別内訳:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 4),
                ..._buildDayBreakdown(logs),
              ],
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _buildDayBreakdown(List<TrainingLog> logs) {
    final byDay = <String, List<TrainingLog>>{};
    for (final l in logs) {
      final d = l.date.toLocal();
      final key = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      byDay.putIfAbsent(key, () => []).add(l);
    }
    final sorted = byDay.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    return sorted.map((entry) {
      final names = entry.value.map((l) => l.exerciseName).toSet().join('・');
      final parts = entry.key.split('-');
      final label = '${parts[1]}/${parts[2]}';
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            SizedBox(
              width: 40,
              child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ),
            Expanded(
              child: Text(
                names,
                style: const TextStyle(fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '${entry.value.length}件',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildFoodSummaryCard({
    required List<FoodItem> foodItems,
    required String periodLabel,
  }) {
    final byDay = <String, List<FoodItem>>{};
    for (final item in foodItems) {
      final d = item.date.toLocal();
      byDay.putIfAbsent('${d.year}-${d.month}-${d.day}', () => []).add(item);
    }
    final recordedDays = byDay.length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.restaurant, size: 18),
                const SizedBox(width: 8),
                Text(
                  '食事（$periodLabel）',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (foodItems.isEmpty)
              const Text('記録なし', style: TextStyle(color: Colors.grey))
            else ...[
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  _StatChip(
                    icon: Icons.calendar_today,
                    label: '記録日数',
                    value: '$recordedDays日',
                  ),
                  _StatChip(
                    icon: Icons.local_fire_department,
                    label: '1日平均',
                    value: '${(foodItems.fold(0, (s, i) => s + i.calories) / recordedDays).round()} kcal',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _MacroRow(
                label: 'タンパク質 平均',
                value: '${(foodItems.fold(0.0, (s, i) => s + i.protein) / recordedDays).toStringAsFixed(1)} g/日',
                color: Colors.blue,
              ),
              _MacroRow(
                label: '脂質 平均',
                value: '${(foodItems.fold(0.0, (s, i) => s + i.fat) / recordedDays).toStringAsFixed(1)} g/日',
                color: Colors.orange,
              ),
              _MacroRow(
                label: '炭水化物 平均',
                value: '${(foodItems.fold(0.0, (s, i) => s + i.carbs) / recordedDays).toStringAsFixed(1)} g/日',
                color: Colors.green,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMonthCalendar() {
    final daysInMonth = _monthEnd.day;
    final firstWeekday = _monthStart.weekday; // 1=月
    final bodyWeightKg = ref.watch(energyProfileProvider).weightKg;
    final effectiveBw = bodyWeightKg > 0
        ? bodyWeightKg
        : TrainingCalorieCalculator.defaultBodyWeightKg;

    final trainingDays = <int>{};
    final kcalByDay = <int, double>{};
    for (final l in _monthData.trainingLogs) {
      final d = l.date.toLocal();
      if (d.year == _monthStart.year && d.month == _monthStart.month) {
        trainingDays.add(d.day);
        kcalByDay[d.day] = (kcalByDay[d.day] ?? 0) +
            TrainingCalorieCalculator.estimate(
              weight: l.weight,
              reps: l.reps,
              sets: l.sets,
              intervalSec: l.interval,
              exerciseType: l.exerciseType,
              bodyWeightKg: effectiveBw,
              exerciseName: l.exerciseName,
              durationMinutes: l.durationMinutes,
            );
      }
    }

    final foodDays = <int>{};
    for (final item in _monthData.foodItems) {
      final d = item.date.toLocal();
      if (d.year == _monthStart.year && d.month == _monthStart.month) foodDays.add(d.day);
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'トレーニングカレンダー',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: ['月', '火', '水', '木', '金', '土', '日'].map((d) {
                return Expanded(
                  child: Center(
                    child: Text(d,
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 4),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 1,
              ),
              itemCount: (firstWeekday - 1) + daysInMonth,
              itemBuilder: (context, index) {
                if (index < firstWeekday - 1) return const SizedBox();
                final day = index - (firstWeekday - 1) + 1;
                final hasTrain = trainingDays.contains(day);
                final hasFood = foodDays.contains(day);
                final today = DateTime.now();
                final isToday = _monthStart.year == today.year &&
                    _monthStart.month == today.month &&
                    day == today.day;

                return Container(
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: hasTrain
                        ? Colors.deepOrange.withOpacity(0.85)
                        : hasFood
                            ? Colors.blue.withOpacity(0.15)
                            : null,
                    borderRadius: BorderRadius.circular(6),
                    border: isToday
                        ? Border.all(color: Colors.deepOrange, width: 2)
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$day',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                          color: hasTrain ? Colors.white : null,
                        ),
                      ),
                      if (hasTrain && (kcalByDay[day] ?? 0) > 0)
                        Text(
                          '${(kcalByDay[day]! / 1000).toStringAsFixed(1)}k',
                          style: TextStyle(
                            fontSize: 8,
                            color: hasTrain ? Colors.white70 : Colors.grey,
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(width: 12, height: 12,
                    decoration: BoxDecoration(color: Colors.deepOrange.withOpacity(0.85), borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 4),
                const Text('トレーニングあり', style: TextStyle(fontSize: 11)),
                const SizedBox(width: 12),
                Container(width: 12, height: 12,
                    decoration: BoxDecoration(color: Colors.blue.withOpacity(0.2), borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 4),
                const Text('食事記録あり', style: TextStyle(fontSize: 11)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiReviewCard({
    required _ReviewData reviewData,
    required VoidCallback onFetch,
    required VoidCallback onRefresh,
    required String periodLabel,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome, size: 18, color: Colors.deepOrange),
                const SizedBox(width: 8),
                Text(
                  'AI $periodLabel振り返り',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const Spacer(),
                if (reviewData.aiReview != null && !reviewData.aiLoading)
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 18),
                    tooltip: '再取得',
                    onPressed: onRefresh,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (reviewData.aiLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (reviewData.aiError != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    reviewData.aiError!,
                    style: const TextStyle(color: Colors.red, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: onFetch,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('再試行'),
                  ),
                ],
              )
            else if (reviewData.aiReview != null)
              Text(
                reviewData.aiReview!,
                style: const TextStyle(fontSize: 13, height: 1.6),
              )
            else
              FilledButton.icon(
                onPressed: onFetch,
                icon: const Icon(Icons.auto_awesome, size: 16),
                label: Text('AI $periodLabel振り返りを生成'),
              ),
          ],
        ),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

// ── Sub-widgets ────────────────────────────────────────────────────────────

class _PeriodNavigation extends StatelessWidget {
  final String label;
  final VoidCallback onPrev;
  final VoidCallback? onNext;
  final VoidCallback onRefresh;

  const _PeriodNavigation({
    required this.label,
    required this.onPrev,
    this.onNext,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(icon: const Icon(Icons.chevron_left), onPressed: onPrev),
        Expanded(
          child: Center(
            child: Text(
              label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: onNext,
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatChip({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.deepOrange),
          const SizedBox(width: 4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(value,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }
}

class _MacroRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MacroRow({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 12)),
          const Spacer(),
          Text(value,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}
