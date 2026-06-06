import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/sleep_provider.dart';
import '../../providers/steps_provider.dart';
import '../../providers/water_provider.dart';
import '../../services/health_service.dart';
import '../../theme/app_tokens.dart';
import '../../theme/bewell_colors.dart';

/// 睡眠・歩数・水分を1行にまとめたコンパクトサマリー + 水分クイック追加。
class WellnessSummarySection extends ConsumerWidget {
  const WellnessSummarySection({
    super.key,
    this.onSleepDetail,
  });

  final VoidCallback? onSleepDetail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!HealthService.isSupported) {
      return _WaterOnlySection(onSleepDetail: onSleepDetail);
    }

    final sleepState = ref.watch(sleepProvider);
    final stepsState = ref.watch(stepsProvider);
    final waterState = ref.watch(waterProvider);
    final scheme = Theme.of(context).colorScheme;
    final semantic = context.bewellColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _WellnessTile(
                icon: Icons.bedtime_rounded,
                label: '睡眠',
                value: _sleepValue(sleepState),
                sublabel: _sleepSublabel(sleepState),
                color: scheme.tertiary,
                isLoading: sleepState.isLoading,
                actionLabel:
                    !sleepState.permissionGranted ? '連携' : null,
                onAction: !sleepState.permissionGranted
                    ? () => _requestSleep(context, ref)
                    : null,
                onTap: sleepState.permissionGranted &&
                        sleepState.sleepMinutes != null
                    ? onSleepDetail
                    : null,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _WellnessTile(
                icon: Icons.directions_walk_rounded,
                label: '歩数',
                value: _stepsValue(stepsState),
                sublabel: stepsState.burnedKcal > 0
                    ? '${stepsState.burnedKcal} kcal'
                    : null,
                color: scheme.secondary,
                isLoading: stepsState.isLoading,
                actionLabel:
                    !stepsState.permissionGranted ? '連携' : null,
                onAction: !stepsState.permissionGranted
                    ? () => _requestSteps(context, ref)
                    : null,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _WellnessTile(
                icon: Icons.water_drop_rounded,
                label: '水分',
                value: '${waterState.totalMl}ml',
                sublabel: '/ ${waterState.dailyGoalMl}ml',
                color: semantic.water,
                progress: waterState.progressFraction,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _WaterQuickAddRow(waterState: waterState, ref: ref),
      ],
    );
  }

  static String _sleepValue(SleepState s) {
    if (s.isLoading) return '…';
    if (!s.permissionGranted) return '—';
    if (s.sleepMinutes == null) return '—';
    return '${s.hours}h${s.minutes > 0 ? '${s.minutes}m' : ''}';
  }

  static String? _sleepSublabel(SleepState s) {
    if (!s.permissionGranted || s.sleepMinutes == null) return null;
    return '${s.quality.emoji} ${s.quality.label}';
  }

  static String _stepsValue(StepsState s) {
    if (s.isLoading) return '…';
    if (!s.permissionGranted) return '—';
    if (s.steps >= 10000) {
      return '${(s.steps / 1000).toStringAsFixed(1)}k';
    }
    return '${s.steps}';
  }

  static Future<void> _requestSleep(BuildContext context, WidgetRef ref) async {
    final ok = await ref.read(sleepProvider.notifier).requestAndFetch();
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '睡眠データを取得できませんでした。\n'
            '設定 > プライバシー > ヘルスケア からアクセスを許可してください。',
          ),
          duration: Duration(seconds: 5),
        ),
      );
    }
  }

  static Future<void> _requestSteps(BuildContext context, WidgetRef ref) async {
    final ok = await ref.read(stepsProvider.notifier).requestAndFetch();
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('歩数へのアクセスが許可されていません')),
      );
    }
  }
}

class _WaterOnlySection extends ConsumerWidget {
  const _WaterOnlySection({this.onSleepDetail});

  final VoidCallback? onSleepDetail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final waterState = ref.watch(waterProvider);
    final semantic = context.bewellColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _WellnessTile(
          icon: Icons.water_drop_rounded,
          label: '水分',
          value: '${waterState.totalMl}ml',
          sublabel: '/ ${waterState.dailyGoalMl}ml',
          color: semantic.water,
          progress: waterState.progressFraction,
          fullWidth: true,
        ),
        const SizedBox(height: AppSpacing.md),
        _WaterQuickAddRow(waterState: waterState, ref: ref),
      ],
    );
  }
}

class _WellnessTile extends StatelessWidget {
  const _WellnessTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.sublabel,
    this.progress,
    this.isLoading = false,
    this.actionLabel,
    this.onAction,
    this.onTap,
    this.fullWidth = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? sublabel;
  final Color color;
  final double? progress;
  final bool isLoading;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback? onTap;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final content = Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (isLoading)
            SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: color,
              ),
            )
          else
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
            ),
          if (sublabel != null) ...[
            const SizedBox(height: 2),
            Text(
              sublabel!,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (progress != null) ...[
            const SizedBox(height: AppSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: progress!.clamp(0.0, 1.0),
                minHeight: 4,
                backgroundColor: color.withValues(alpha: 0.15),
                color: color,
              ),
            ),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              height: 32,
              width: double.infinity,
              child: FilledButton.tonal(
                style: FilledButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 32),
                  textStyle: const TextStyle(fontSize: 11),
                ),
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ),
          ],
        ],
      ),
    );

    return Material(
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.lgAll,
        side: BorderSide(
          color: scheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: onTap != null
          ? InkWell(onTap: onTap, child: content)
          : content,
    );
  }
}

class _WaterQuickAddRow extends StatelessWidget {
  const _WaterQuickAddRow({required this.waterState, required this.ref});

  final WaterState waterState;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final semantic = context.bewellColors;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '水分を追加',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                for (final ml in [150, 200, 250, 500])
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: FilledButton.tonal(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 40),
                          padding: EdgeInsets.zero,
                          backgroundColor: semantic.waterContainer,
                          foregroundColor: semantic.water,
                        ),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          ref.read(waterProvider.notifier).addLog(ml);
                        },
                        child: Text('${ml}ml', style: const TextStyle(fontSize: 11)),
                      ),
                    ),
                  ),
              ],
            ),
            if (waterState.todayLogs.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: waterState.todayLogs.map((log) {
                  return Chip(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    label: Text('${log.amountMl}ml',
                        style: const TextStyle(fontSize: 11)),
                    deleteIcon: const Icon(Icons.close_rounded, size: 14),
                    onDeleted: () =>
                        ref.read(waterProvider.notifier).removeLog(log.id),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
