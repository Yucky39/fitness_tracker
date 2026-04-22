import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/exercise_motion_guides.dart';
import '../../models/exercise_animation.dart';
import '../../models/training_log.dart';
import '../../providers/settings_provider.dart';
import '../../services/exercise_animation_service.dart';
import 'stick_figure_animation_widget.dart';

/// 種目のフォーム解説とAI生成スティックフィギュアアニメーションを表示するボトムシート。
Future<void> showExerciseMotionDemoSheet(
  BuildContext context, {
  required String exerciseName,
  required ExerciseType exerciseType,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => _ExerciseMotionDemoContent(
      exerciseName: exerciseName,
      exerciseType: exerciseType,
    ),
  );
}

// ────────────────────────────────────────────────────────────────────────────

enum _AnimState { loading, loaded, noApiKey, error }

class _ExerciseMotionDemoContent extends ConsumerStatefulWidget {
  final String exerciseName;
  final ExerciseType exerciseType;

  const _ExerciseMotionDemoContent({
    required this.exerciseName,
    required this.exerciseType,
  });

  @override
  ConsumerState<_ExerciseMotionDemoContent> createState() =>
      _ExerciseMotionDemoContentState();
}

class _ExerciseMotionDemoContentState
    extends ConsumerState<_ExerciseMotionDemoContent> {
  _AnimState _state = _AnimState.loading;
  ExerciseAnimationData? _animationData;

  @override
  void initState() {
    super.initState();
    // ウィジェット構築後に非同期でアニメーションを取得する。
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAnimation());
  }

  Future<void> _loadAnimation() async {
    final settings = ref.read(settingsProvider);
    if (settings.currentApiKey.isEmpty) {
      if (mounted) setState(() => _state = _AnimState.noApiKey);
      return;
    }

    try {
      final data = await ExerciseAnimationService().getAnimation(
        exerciseName: widget.exerciseName,
        exerciseType: widget.exerciseType,
        apiKey: settings.currentApiKey,
        provider: settings.selectedProvider,
        model: settings.currentModel,
      );
      if (!mounted) return;
      setState(() {
        _animationData = data;
        _state = data != null ? _AnimState.loaded : _AnimState.error;
      });
    } catch (_) {
      if (mounted) setState(() => _state = _AnimState.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final guide =
        lookupExerciseMotionGuide(widget.exerciseName, widget.exerciseType);
    final bottom = MediaQuery.paddingOf(context).bottom;
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 16 + bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── タイトル ──
            Text(
              widget.exerciseName,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 6),
            Chip(
              label: Text(widget.exerciseType.label),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
            ),
            const SizedBox(height: 16),

            // ── アニメーションエリア ──
            Container(
              height: 280,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(16),
              ),
              child: _buildAnimationArea(scheme),
            ),
            const SizedBox(height: 20),

            // ── フォームのポイント ──
            Text(
              'フォームのポイント',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            ...guide.tips.map(
              (t) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Icon(
                        Icons.check_circle_outline_rounded,
                        size: 18,
                        color: scheme.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(t, style: const TextStyle(height: 1.45))),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimationArea(ColorScheme scheme) {
    switch (_state) {
      case _AnimState.loading:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'AIがアニメーションを生成中…',
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        );

      case _AnimState.loaded:
        return Padding(
          padding: const EdgeInsets.all(12),
          child: StickFigureAnimationWidget(data: _animationData!),
        );

      case _AnimState.noApiKey:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.fitness_center_rounded,
                  size: 56, color: scheme.primary.withValues(alpha: 0.5)),
              const SizedBox(height: 10),
              Text(
                'アニメーションにはAPIキーの設定が必要です',
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );

      case _AnimState.error:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.fitness_center_rounded,
                size: 56,
                color: scheme.primary.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 10),
              Text(
                'アニメーションの生成に失敗しました',
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () {
                  setState(() => _state = _AnimState.loading);
                  _loadAnimation();
                },
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('再試行', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        );
    }
  }
}
