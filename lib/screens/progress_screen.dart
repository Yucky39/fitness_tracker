import 'dart:io';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/legacy.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../models/body_metrics.dart';
import '../providers/body_progress_advice_provider.dart';
import '../providers/energy_profile_provider.dart';
import '../providers/progress_provider.dart';
import '../providers/home_fab_provider.dart';
import '../theme/app_tokens.dart';
import '../theme/bewell_colors.dart';
import '../widgets/ai_error_text.dart';
import '../widgets/bewell_empty_state.dart';
import '../widgets/register_home_fab.dart';
import '../theme/chart_metric_colors.dart';
import 'photo_compare_screen.dart';

// 0 = 日別, 1 = 週別, 2 = 月別
final _aggregationProvider = StateProvider<int>((ref) => 0);

/// 体型の推移をパーソナルトレーナーが講評するカード。
class _BodyCoachCard extends ConsumerWidget {
  const _BodyCoachCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final advice = ref.watch(bodyProgressAdviceProvider);
    final notifier = ref.read(bodyProgressAdviceProvider.notifier);

    Widget body;
    if (advice.isLoading) {
      body = Row(
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Text('体型の変化を読み取っています…',
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
        ],
      );
    } else if (advice.error != null) {
      body = AiErrorText(advice.error!);
    } else if (advice.advice != null && advice.advice!.isNotEmpty) {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(advice.advice!, style: const TextStyle(fontSize: 14, height: 1.55)),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => notifier.generate(),
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('更新'),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                foregroundColor: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      );
    } else {
      body = Align(
        alignment: Alignment.centerLeft,
        child: FilledButton.icon(
          onPressed: () => notifier.generate(),
          icon: const Icon(Icons.auto_awesome, size: 18),
          label: const Text('体型の変化をコーチに見てもらう'),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.xs,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.insights_rounded,
                    color: context.bewellColors.aiAccent, size: 20),
                const SizedBox(width: 8),
                Text(
                  '体型のコーチング',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ],
            ),
            const SizedBox(height: 12),
            body,
          ],
        ),
      ),
    );
  }
}

class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(progressProvider);
    final notifier = ref.read(progressProvider.notifier);
    final epState = ref.watch(energyProfileProvider);

    void openAddDialog() => _showMetricsDialog(
          context: context,
          ref: ref,
          notifier: notifier,
          heightCm: epState.heightCm,
        );

    final Widget body;
    if (state.isLoading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (state.metrics.isEmpty) {
      body = Center(
        child: BeWellEmptyState(
          icon: Icons.show_chart_outlined,
          title: 'まだ記録がありません',
          subtitle: '体重・体脂肪率・写真を記録して変化を追いましょう',
          action: FilledButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('最初の記録を追加'),
            onPressed: openAddDialog,
          ),
        ),
      );
    } else {
      body = _buildBody(context, ref, state, notifier, epState);
    }

    return RegisterHomeFab(
      tabIndex: 3,
      config: HomeFabConfig(
        tooltip: '記録を追加',
        onPressed: openAddDialog,
      ),
      child: body,
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

        // ── AI coach comment on body change ──────────────────────────────
        const SliverToBoxAdapter(
          child: _BodyCoachCard(),
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
              final pastMetrics =
                  reversed.where((m) => m.id != item.id).toList();

              return _MetricsCard(
                item: item,
                heightCm: epState.heightCm,
                targetWeightKg: epState.targetWeightKg,
                pastMetrics: pastMetrics,
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

        const SliverToBoxAdapter(
            child: SizedBox(height: AppSpacing.bottomNavClearance)),
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

    // 向きごとのパス
    String? frontPath = existing?.imageFrontPath;
    String? sidePath = existing?.imageSidePath;
    String? backPath = existing?.imageBackPath;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          final scheme = Theme.of(ctx).colorScheme;
          final semantic = ctx.bewellColors;
          final w = double.tryParse(weightCtrl.text) ?? 0;
          final bmiVal = heightCm > 0 ? BodyMetrics.bmi(w, heightCm) : 0.0;

          // 向きごとのピッカーUI
          Widget photoRow(
            String label,
            String? path,
            void Function(String?) onChanged,
          ) {
            final scheme = Theme.of(ctx).colorScheme;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(ctx).textTheme.labelMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: path != null
                            ? () => onChanged(null)
                            : null,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: path != null && !kIsWeb
                              ? Stack(
                                  children: [
                                    Image.file(File(path),
                                        width: 60,
                                        height: 72,
                                        fit: BoxFit.cover),
                                    Positioned(
                                      top: 2,
                                      right: 2,
                                      child: Icon(Icons.cancel,
                                          size: 16, color: scheme.onPrimary),
                                    ),
                                  ],
                                )
                              : Container(
                                  width: 60,
                                  height: 72,
                                  color: scheme.surfaceContainerHighest,
                                  child: Icon(Icons.add_photo_alternate,
                                      color: scheme.onSurfaceVariant),
                                ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      if (!kIsWeb)
                        Expanded(
                          child: Column(
                            children: [
                              OutlinedButton.icon(
                                icon:
                                    const Icon(Icons.camera_alt, size: 16),
                                label: const Text('カメラ'),
                                style: OutlinedButton.styleFrom(
                                    visualDensity: VisualDensity.compact),
                                onPressed: () async {
                                  final p = await _pickImage(
                                      ctx, ImageSource.camera);
                                  if (p != null) setState(() => onChanged(p));
                                },
                              ),
                              const SizedBox(height: 4),
                              OutlinedButton.icon(
                                icon: const Icon(Icons.photo_library,
                                    size: 16),
                                label: const Text('ギャラリー'),
                                style: OutlinedButton.styleFrom(
                                    visualDensity: VisualDensity.compact),
                                onPressed: () async {
                                  final p = await _pickImage(
                                      ctx, ImageSource.gallery);
                                  if (p != null) setState(() => onChanged(p));
                                },
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            );
          }

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
                                ? semantic.warning
                                : semantic.success),
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
                    decoration:
                        const InputDecoration(labelText: '体脂肪率 (%)'),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '体型写真（任意）',
                    style: Theme.of(ctx).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '各向きは省略できます。同じ向きの写真が揃ったときにオーバーレイ比較が使えます。',
                    style: Theme.of(ctx).textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 12),
                  photoRow('正面', frontPath,
                      (p) => frontPath = p),
                  photoRow('側面', sidePath,
                      (p) => sidePath = p),
                  photoRow('背面', backPath,
                      (p) => backPath = p),
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
                      waist:
                          double.tryParse(waistCtrl.text) ?? existing.waist,
                      bodyFatPercentage:
                          double.tryParse(fatCtrl.text) ??
                              existing.bodyFatPercentage,
                      imageFrontPath: frontPath,
                      clearFront: frontPath == null,
                      imageSidePath: sidePath,
                      clearSide: sidePath == null,
                      imageBackPath: backPath,
                      clearBack: backPath == null,
                    ));
                  } else {
                    notifier.addMetrics(
                      weight: w,
                      waist: double.tryParse(waistCtrl.text) ?? 0,
                      bodyFatPercentage:
                          double.tryParse(fatCtrl.text) ?? 0,
                      imageFrontPath: frontPath,
                      imageSidePath: sidePath,
                      imageBackPath: backPath,
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
    final scheme = Theme.of(context).colorScheme;
    final semantic = context.bewellColors;
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
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.xs,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.monitor_weight_outlined,
                    color: scheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  '最新: ${DateFormat('yyyy/M/d').format(latest.date)}',
                  style: Theme.of(context).textTheme.titleSmall,
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
                _summaryCol(context, '体重', '${latest.weight.toStringAsFixed(1)} kg'),
                if (latest.bodyFatPercentage > 0)
                  _summaryCol(context, '体脂肪率',
                      '${latest.bodyFatPercentage.toStringAsFixed(1)} %'),
                if (latest.waist > 0)
                  _summaryCol(context,
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
                      context,
                      'BMI',
                      '${bmiVal.toStringAsFixed(1)} (${BodyMetrics.bmiLabel(bmiVal)})',
                      bmiVal >= 18.5 && bmiVal < 25
                          ? semantic.success
                          : semantic.warning,
                    ),
                  if (latest.bodyFatPercentage > 0) ...[
                    _derivedChip(
                      context,
                      '除脂肪体重',
                      '${lbm.toStringAsFixed(1)} kg',
                      scheme.primary,
                    ),
                    _derivedChip(
                      context,
                      '体脂肪量',
                      '${fatMass.toStringAsFixed(1)} kg',
                      scheme.tertiary,
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
                      ? semantic.success.withValues(alpha: 0.12)
                      : scheme.primaryContainer.withValues(alpha: 0.5),
                  borderRadius: AppRadius.smAll,
                ),
                child: Row(
                  children: [
                    Icon(
                      toTarget.abs() < 0.5
                          ? Icons.check_circle
                          : Icons.flag_outlined,
                      size: 16,
                      color: toTarget.abs() < 0.5
                          ? semantic.success
                          : scheme.primary,
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
                            ? semantic.success
                            : scheme.primary,
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

  Widget _summaryCol(BuildContext context, String label, String value) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }

  Widget _derivedChip(
    BuildContext context,
    String label,
    String value,
    Color color,
  ) =>
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            '$label: $value',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
          ),
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
    final scheme = Theme.of(context).colorScheme;
    final semantic = context.bewellColors;
    final isGain = delta > 0;
    final color = isGain ? scheme.error : semantic.success;
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
      return SizedBox(
        height: 80,
        child: Center(
          child: Text(
            'グラフを表示するには2件以上の記録が必要です',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
      );
    }

    final aggIndex = ref.watch(_aggregationProvider);

    return Card(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xs,
        AppSpacing.lg,
        AppSpacing.xs,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
        child: Column(
          children: [
            // Aggregation toggle
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Text(
                    '集計単位',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
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
    final scheme = Theme.of(context).colorScheme;
    final color = ChartMetricColors.forMetric(metricIndex, scheme);
    final units = ['kg', '%', 'cm'];
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
      return Center(
        child: Text(
          'データがありません',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
        ),
      );
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
                  Theme.of(context).textTheme.labelMedium!.copyWith(
                        color: scheme.onPrimary,
                      ),
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
                    color: scheme.error.withValues(alpha: 0.55),
                    strokeWidth: 1.5,
                    dashArray: [6, 4],
                    label: HorizontalLineLabel(
                      show: true,
                      labelResolver: (_) =>
                          '目標 ${targetLine.toStringAsFixed(1)} kg',
                      style: Theme.of(context).textTheme.labelSmall!.copyWith(
                            color: scheme.error,
                          ),
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
            getDrawingHorizontalLine: (_) => FlLine(
              color: scheme.outlineVariant.withValues(alpha: 0.35),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border(
              bottom: BorderSide(color: scheme.outlineVariant),
              left: BorderSide(color: scheme.outlineVariant),
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
  final List<BodyMetrics> pastMetrics;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _MetricsCard({
    required this.item,
    required this.heightCm,
    required this.targetWeightKg,
    required this.pastMetrics,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final semantic = context.bewellColors;
    final bmiVal =
        heightCm > 0 ? BodyMetrics.bmi(item.weight, heightCm) : 0.0;

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: 5,
      ),
      child: InkWell(
        borderRadius: AppRadius.lgAll,
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (item.hasAnyPhoto && !kIsWeb)
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PhotoCompareScreen(
                        current: item,
                        pastMetrics: pastMetrics,
                      ),
                    ),
                  ),
                  child: Hero(
                    tag: 'photo_${item.id}',
                    child: ClipRRect(
                      borderRadius: AppRadius.smAll,
                      child: Image.file(
                        File(item.firstPhotoPath!),
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
                    color: scheme.surfaceContainerHighest,
                    borderRadius: AppRadius.smAll,
                  ),
                  child: Icon(Icons.person_outline,
                      color: scheme.onSurfaceVariant),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('yyyy/MM/dd (E)', 'ja').format(item.date),
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 12,
                      runSpacing: 2,
                      children: [
                        _metricText(context, '体重', '${item.weight} kg'),
                        if (item.bodyFatPercentage > 0)
                          _metricText(
                              context, '体脂肪率', '${item.bodyFatPercentage} %'),
                        if (item.waist > 0)
                          _metricText(context, '腹囲', '${item.waist} cm'),
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
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: bmiVal >= 18.5 && bmiVal < 25
                                        ? semantic.success
                                        : semantic.warning,
                                  ),
                            ),
                          if (item.bodyFatPercentage > 0)
                            Text(
                              '除脂肪: ${item.leanBodyMass.toStringAsFixed(1)} kg',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(color: scheme.primary),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 20),
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 18),
                        SizedBox(width: 8),
                        Text('編集'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline,
                            size: 18, color: scheme.error),
                        const SizedBox(width: 8),
                        Text('削除', style: TextStyle(color: scheme.error)),
                      ],
                    ),
                  ),
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

  Widget _metricText(BuildContext context, String label, String value) {
    return RichText(
      text: TextSpan(
        style: Theme.of(context).textTheme.bodyMedium,
        children: [
          TextSpan(
            text: '$label: ',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          TextSpan(
            text: value,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
