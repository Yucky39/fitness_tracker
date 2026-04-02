import 'dart:io';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../models/body_metrics.dart';
import '../providers/energy_profile_provider.dart';
import '../providers/progress_provider.dart';
import 'photo_compare_screen.dart';

// 0 = 日別, 1 = 週別, 2 = 月別
final _aggregationProvider = StateProvider<int>((ref) => 0);

class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(progressProvider);
    final notifier = ref.read(progressProvider.notifier);
    final epState = ref.watch(energyProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('進捗トラッキング'),
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.metrics.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.show_chart,
                          size: 60, color: Colors.grey),
                      const SizedBox(height: 12),
                      const Text('まだ記録がありません',
                          style: TextStyle(color: Colors.grey)),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('最初の記録を追加'),
                        onPressed: () => _showMetricsDialog(
                          context: context,
                          ref: ref,
                          notifier: notifier,
                          heightCm: epState.heightCm,
                        ),
                      ),
                    ],
                  ),
                )
              : _buildBody(context, ref, state, notifier, epState),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showMetricsDialog(
          context: context,
          ref: ref,
          notifier: notifier,
          heightCm: epState.heightCm,
        ),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    ProgressState state,
    ProgressNotifier notifier,
    EnergyProfileState epState,
  ) {
    return CustomScrollView(
      slivers: [
        // ── Latest summary card ──────────────────────────────────────────
        SliverToBoxAdapter(
          child: _LatestSummaryCard(state: state, epState: epState),
        ),

        // ── Chart section ────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: _ChartSection(state: state, epState: epState),
        ),

        // ── List header ──────────────────────────────────────────────────
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text('記録一覧',
                style:
                    TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ),
        ),

        // ── Records list ─────────────────────────────────────────────────
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final reversed = state.metrics.reversed.toList();
              final item = reversed[index];
              final otherWithPhotos = reversed
                  .where((m) => m.imagePath != null && m.id != item.id)
                  .toList();

              return _MetricsCard(
                item: item,
                heightCm: epState.heightCm,
                targetWeightKg: epState.targetWeightKg,
                otherMetricsWithPhotos: otherWithPhotos,
                onEdit: () => _showMetricsDialog(
                  context: context,
                  ref: ref,
                  notifier: notifier,
                  existing: item,
                  heightCm: epState.heightCm,
                ),
                onDelete: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('削除の確認'),
                      content: const Text('この記録を削除しますか？'),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('キャンセル')),
                        TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('削除')),
                      ],
                    ),
                  );
                  if (ok == true) notifier.deleteMetrics(item.id);
                },
              );
            },
            childCount: state.metrics.length,
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ],
    );
  }

  // ── Add / Edit dialog ──────────────────────────────────────────────────────

  void _showMetricsDialog({
    required BuildContext context,
    required WidgetRef ref,
    required ProgressNotifier notifier,
    BodyMetrics? existing,
    required double heightCm,
  }) {
    final isEdit = existing != null;
    final weightCtrl = TextEditingController(
        text: isEdit && existing.weight > 0 ? existing.weight.toString() : '');
    final waistCtrl = TextEditingController(
        text: isEdit && existing.waist > 0 ? existing.waist.toString() : '');
    final fatCtrl = TextEditingController(
        text: isEdit && existing.bodyFatPercentage > 0
            ? existing.bodyFatPercentage.toString()
            : '');
    String? selectedImagePath = existing?.imagePath;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          // Derive live BMI preview
          final w = double.tryParse(weightCtrl.text) ?? 0;
          final bmiVal = heightCm > 0 ? BodyMetrics.bmi(w, heightCm) : 0.0;

          return AlertDialog(
            title: Text(isEdit ? '記録を編集' : '進捗を記録'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: weightCtrl,
                    decoration: const InputDecoration(labelText: '体重 (kg)'),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                  ),
                  if (bmiVal > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, left: 2),
                      child: Text(
                        'BMI: ${bmiVal.toStringAsFixed(1)}  ${BodyMetrics.bmiLabel(bmiVal)}',
                        style: TextStyle(
                            fontSize: 12,
                            color: bmiVal < 18.5 || bmiVal >= 25
                                ? Colors.orange
                                : Colors.green),
                      ),
                    ),
                  TextField(
                    controller: waistCtrl,
                    decoration: const InputDecoration(labelText: '腹囲 (cm)'),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                  TextField(
                    controller: fatCtrl,
                    decoration: const InputDecoration(labelText: '体脂肪率 (%)'),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 16),

                  // Photo
                  if (selectedImagePath != null && !kIsWeb)
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(File(selectedImagePath!),
                              height: 100,
                              width: double.infinity,
                              fit: BoxFit.cover),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () =>
                                setState(() => selectedImagePath = null),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.close,
                                  color: Colors.white, size: 18),
                            ),
                          ),
                        ),
                      ],
                    ),
                  if (!kIsWeb) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.camera_alt, size: 18),
                            label: const Text('カメラ'),
                            onPressed: () async {
                              final path = await _pickImage(
                                  context, ImageSource.camera);
                              if (path != null) {
                                setState(() => selectedImagePath = path);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon:
                                const Icon(Icons.photo_library, size: 18),
                            label: const Text('ギャラリー'),
                            onPressed: () async {
                              final path = await _pickImage(
                                  context, ImageSource.gallery);
                              if (path != null) {
                                setState(() => selectedImagePath = path);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('キャンセル')),
              TextButton(
                onPressed: () {
                  final w = double.tryParse(weightCtrl.text);
                  if (w == null || w <= 0) return;
                  if (isEdit) {
                    notifier.updateMetrics(existing.copyWith(
                      weight: w,
                      waist: double.tryParse(waistCtrl.text) ?? existing.waist,
                      bodyFatPercentage:
                          double.tryParse(fatCtrl.text) ??
                              existing.bodyFatPercentage,
                      imagePath: selectedImagePath,
                      clearImage: selectedImagePath == null,
                    ));
                  } else {
                    notifier.addMetrics(
                      weight: w,
                      waist: double.tryParse(waistCtrl.text) ?? 0,
                      bodyFatPercentage:
                          double.tryParse(fatCtrl.text) ?? 0,
                      imagePath: selectedImagePath,
                    );
                  }
                  Navigator.pop(ctx);
                },
                child: Text(isEdit ? '保存' : '記録'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<String?> _pickImage(BuildContext context, ImageSource source) async {
    try {
      final file = await ImagePicker().pickImage(source: source);
      if (file == null) return null;
      final dir = await getApplicationDocumentsDirectory();
      final dest = '${dir.path}/${p.basename(file.path)}';
      await File(file.path).copy(dest);
      return dest;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('画像の取得に失敗しました: $e')),
        );
      }
      return null;
    }
  }
}

// ── Latest summary card ────────────────────────────────────────────────────

class _LatestSummaryCard extends StatelessWidget {
  final ProgressState state;
  final EnergyProfileState epState;

  const _LatestSummaryCard({required this.state, required this.epState});

  @override
  Widget build(BuildContext context) {
    final latest = state.latest;
    if (latest == null) return const SizedBox.shrink();

    final prev = state.previous;
    final heightCm = epState.heightCm;
    final targetKg = epState.targetWeightKg;

    final bmiVal =
        heightCm > 0 ? BodyMetrics.bmi(latest.weight, heightCm) : 0.0;
    final lbm = latest.leanBodyMass;
    final fatMass = latest.fatMass;

    final weightDelta = prev != null ? latest.weight - prev.weight : null;
    final toTarget =
        targetKg > 0 ? latest.weight - targetKg : null;

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.monitor_weight_outlined,
                    color: Colors.blue, size: 20),
                const SizedBox(width: 8),
                Text(
                  '最新: ${DateFormat('yyyy/M/d').format(latest.date)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const Spacer(),
                if (weightDelta != null)
                  _DeltaBadge(delta: weightDelta, unit: 'kg'),
              ],
            ),
            const SizedBox(height: 12),
            // Primary metrics
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _summaryCol(
                    '体重', '${latest.weight.toStringAsFixed(1)} kg'),
                if (latest.bodyFatPercentage > 0)
                  _summaryCol('体脂肪率',
                      '${latest.bodyFatPercentage.toStringAsFixed(1)} %'),
                if (latest.waist > 0)
                  _summaryCol(
                      '腹囲', '${latest.waist.toStringAsFixed(1)} cm'),
              ],
            ),
            // Derived metrics
            if (bmiVal > 0 || lbm > 0) ...[
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  if (bmiVal > 0)
                    _derivedChip(
                      'BMI',
                      '${bmiVal.toStringAsFixed(1)} (${BodyMetrics.bmiLabel(bmiVal)})',
                      bmiVal >= 18.5 && bmiVal < 25
                          ? Colors.green
                          : Colors.orange,
                    ),
                  if (latest.bodyFatPercentage > 0) ...[
                    _derivedChip(
                      '除脂肪体重',
                      '${lbm.toStringAsFixed(1)} kg',
                      Colors.blue,
                    ),
                    _derivedChip(
                      '体脂肪量',
                      '${fatMass.toStringAsFixed(1)} kg',
                      Colors.orange,
                    ),
                  ],
                ],
              ),
            ],
            // Target distance
            if (toTarget != null) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: toTarget.abs() < 0.5
                      ? Colors.green.shade50
                      : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      toTarget.abs() < 0.5
                          ? Icons.check_circle
                          : Icons.flag_outlined,
                      size: 16,
                      color: toTarget.abs() < 0.5
                          ? Colors.green
                          : Colors.blue,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      toTarget.abs() < 0.5
                          ? '目標体重 ${targetKg.toStringAsFixed(1)} kg 達成！'
                          : toTarget > 0
                              ? '目標まであと ${toTarget.toStringAsFixed(1)} kg 減量'
                              : '目標まであと ${(-toTarget).toStringAsFixed(1)} kg 増量',
                      style: TextStyle(
                        fontSize: 13,
                        color: toTarget.abs() < 0.5
                            ? Colors.green.shade700
                            : Colors.blue.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _summaryCol(String label, String value) => Column(
        children: [
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 16)),
          Text(label,
              style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      );

  Widget _derivedChip(String label, String value, Color color) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text('$label: $value',
              style: TextStyle(fontSize: 12, color: color)),
        ],
      );
}

// ── Delta badge ────────────────────────────────────────────────────────────

class _DeltaBadge extends StatelessWidget {
  final double delta;
  final String unit;
  const _DeltaBadge({required this.delta, required this.unit});

  @override
  Widget build(BuildContext context) {
    final isGain = delta > 0;
    final color = isGain ? Colors.red : Colors.green;
    final sign = isGain ? '+' : '';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$sign${delta.toStringAsFixed(1)} $unit',
        style: TextStyle(
            fontSize: 12, color: color, fontWeight: FontWeight.bold),
      ),
    );
  }
}

// ── Chart section ──────────────────────────────────────────────────────────

class _ChartSection extends ConsumerWidget {
  final ProgressState state;
  final EnergyProfileState epState;

  const _ChartSection({required this.state, required this.epState});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.metrics.length < 2) {
      return const SizedBox(
        height: 80,
        child: Center(
            child: Text('グラフを表示するには2件以上の記録が必要です',
                style: TextStyle(color: Colors.grey, fontSize: 13))),
      );
    }

    final aggIndex = ref.watch(_aggregationProvider);

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
        child: Column(
          children: [
            // Aggregation toggle
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  const Text('集計単位',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(width: 12),
                  SegmentedButton<int>(
                    style: const ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    segments: const [
                      ButtonSegment(value: 0, label: Text('日別')),
                      ButtonSegment(value: 1, label: Text('週平均')),
                      ButtonSegment(value: 2, label: Text('月平均')),
                    ],
                    selected: {aggIndex},
                    onSelectionChanged: (s) =>
                        ref.read(_aggregationProvider.notifier).state =
                            s.first,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Tab charts
            DefaultTabController(
              length: 3,
              child: Column(
                children: [
                  const TabBar(
                    tabs: [
                      Tab(text: '体重'),
                      Tab(text: '体脂肪率'),
                      Tab(text: '腹囲'),
                    ],
                  ),
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.26,
                    child: TabBarView(children: [
                      _buildChart(context, aggIndex, 0),
                      _buildChart(context, aggIndex, 1),
                      _buildChart(context, aggIndex, 2),
                    ]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// metricIndex: 0=weight, 1=fat%, 2=waist
  Widget _buildChart(BuildContext context, int aggIndex, int metricIndex) {
    final colors = [Colors.blue, Colors.orange, Colors.green];
    final units = ['kg', '%', 'cm'];
    final color = colors[metricIndex];
    final unit = units[metricIndex];

    final List<FlSpot> spots;
    final List<String> labels;

    if (aggIndex == 0) {
      // Daily
      final data = state.metrics;
      spots = data.asMap().entries.map((e) {
        final v = _value(e.value, metricIndex);
        return FlSpot(e.key.toDouble(), v);
      }).toList();
      labels = data
          .map((m) => DateFormat('MM/dd').format(m.date))
          .toList();
    } else if (aggIndex == 1) {
      // Weekly
      final weeks = state.weeklyAverages;
      spots = weeks.asMap().entries.map((e) {
        final v = _weekValue(e.value, metricIndex);
        return FlSpot(e.key.toDouble(), v);
      }).toList();
      labels = weeks
          .map((w) => DateFormat('M/d').format(w.weekStart))
          .toList();
    } else {
      // Monthly
      final months = state.monthlyAverages;
      spots = months.asMap().entries.map((e) {
        final v = _monthValue(e.value, metricIndex);
        return FlSpot(e.key.toDouble(), v);
      }).toList();
      labels = months
          .map((m) => DateFormat('yyyy/M').format(m.monthStart))
          .toList();
    }

    if (spots.isEmpty || spots.every((s) => s.y == 0)) {
      return const Center(
          child: Text('データがありません',
              style: TextStyle(color: Colors.grey, fontSize: 12)));
    }

    final targetLine = metricIndex == 0 && epState.targetWeightKg > 0
        ? epState.targetWeightKg
        : null;

    final int labelInterval =
        (spots.length / 5).ceil().clamp(1, spots.length);

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 16, 8),
      child: LineChart(
        LineChartData(
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (touchedSpots) => touchedSpots.map((s) {
                final label =
                    s.x.toInt() < labels.length ? labels[s.x.toInt()] : '';
                return LineTooltipItem(
                  '$label\n${s.y.toStringAsFixed(1)} $unit',
                  const TextStyle(color: Colors.white, fontSize: 12),
                );
              }).toList(),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: spots.length > 3,
              color: color,
              barWidth: 2.5,
              dotData: FlDotData(
                show: spots.length <= 20,
                getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                  radius: 3,
                  color: color,
                  strokeWidth: 0,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                color: color.withValues(alpha: 0.08),
              ),
            ),
          ],
          extraLinesData: targetLine != null
              ? ExtraLinesData(horizontalLines: [
                  HorizontalLine(
                    y: targetLine,
                    color: Colors.red.withValues(alpha: 0.6),
                    strokeWidth: 1.5,
                    dashArray: [6, 4],
                    label: HorizontalLineLabel(
                      show: true,
                      labelResolver: (_) =>
                          '目標 ${targetLine.toStringAsFixed(1)} kg',
                      style: const TextStyle(
                          color: Colors.red, fontSize: 10),
                      alignment: Alignment.topRight,
                    ),
                  ),
                ])
              : null,
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                interval: labelInterval.toDouble(),
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= labels.length) return const Text('');
                  return Text(labels[i],
                      style: const TextStyle(fontSize: 9));
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 36,
                  getTitlesWidget: (v, _) => Text(
                        v.toStringAsFixed(1),
                        style: const TextStyle(fontSize: 9),
                      )),
            ),
            topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) =>
                FlLine(color: Colors.grey.shade200, strokeWidth: 1),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border(
              bottom: BorderSide(color: Colors.grey.shade300),
              left: BorderSide(color: Colors.grey.shade300),
            ),
          ),
        ),
      ),
    );
  }

  double _value(BodyMetrics m, int metricIndex) {
    switch (metricIndex) {
      case 0:
        return m.weight;
      case 1:
        return m.bodyFatPercentage;
      case 2:
        return m.waist;
      default:
        return 0;
    }
  }

  double _weekValue(
      ({DateTime weekStart, double avgWeight, double avgFat, double avgWaist}) w,
      int metricIndex) {
    switch (metricIndex) {
      case 0:
        return w.avgWeight;
      case 1:
        return w.avgFat;
      case 2:
        return w.avgWaist;
      default:
        return 0;
    }
  }

  double _monthValue(
      ({DateTime monthStart, double avgWeight, double avgFat, double avgWaist}) m,
      int metricIndex) {
    switch (metricIndex) {
      case 0:
        return m.avgWeight;
      case 1:
        return m.avgFat;
      case 2:
        return m.avgWaist;
      default:
        return 0;
    }
  }
}

// ── Metrics card ───────────────────────────────────────────────────────────

class _MetricsCard extends StatelessWidget {
  final BodyMetrics item;
  final double heightCm;
  final double targetWeightKg;
  final List<BodyMetrics> otherMetricsWithPhotos;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _MetricsCard({
    required this.item,
    required this.heightCm,
    required this.targetWeightKg,
    required this.otherMetricsWithPhotos,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final bmiVal =
        heightCm > 0 ? BodyMetrics.bmi(item.weight, heightCm) : 0.0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Photo thumbnail
              if (item.imagePath != null && !kIsWeb)
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PhotoCompareScreen(
                        currentImagePath: item.imagePath!,
                        otherMetrics: otherMetricsWithPhotos,
                      ),
                    ),
                  ),
                  child: Hero(
                    tag: 'photo_${item.id}',
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        File(item.imagePath!),
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                )
              else
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.person_outline,
                      color: Colors.grey),
                ),
              const SizedBox(width: 12),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('yyyy/MM/dd (E)', 'ja').format(item.date),
                      style: const TextStyle(
                          fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 12,
                      runSpacing: 2,
                      children: [
                        _metricText('体重', '${item.weight} kg'),
                        if (item.bodyFatPercentage > 0)
                          _metricText(
                              '体脂肪率', '${item.bodyFatPercentage} %'),
                        if (item.waist > 0)
                          _metricText('腹囲', '${item.waist} cm'),
                      ],
                    ),
                    if (bmiVal > 0 || item.bodyFatPercentage > 0) ...[
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 10,
                        children: [
                          if (bmiVal > 0)
                            Text(
                              'BMI: ${bmiVal.toStringAsFixed(1)}',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: bmiVal >= 18.5 && bmiVal < 25
                                      ? Colors.green
                                      : Colors.orange),
                            ),
                          if (item.bodyFatPercentage > 0)
                            Text(
                              '除脂肪: ${item.leanBodyMass.toStringAsFixed(1)} kg',
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.blue),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              // Menu
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 20),
                itemBuilder: (_) => [
                  const PopupMenuItem(
                      value: 'edit',
                      child: Row(children: [
                        Icon(Icons.edit, size: 18),
                        SizedBox(width: 8),
                        Text('編集')
                      ])),
                  const PopupMenuItem(
                      value: 'delete',
                      child: Row(children: [
                        Icon(Icons.delete_outline,
                            size: 18, color: Colors.red),
                        SizedBox(width: 8),
                        Text('削除',
                            style: TextStyle(color: Colors.red))
                      ])),
                ],
                onSelected: (v) {
                  if (v == 'edit') onEdit();
                  if (v == 'delete') onDelete();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metricText(String label, String value) => RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.black87),
          children: [
            TextSpan(
                text: '$label: ',
                style: const TextStyle(
                    fontSize: 11, color: Colors.grey)),
            TextSpan(
                text: value,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
      );
}
