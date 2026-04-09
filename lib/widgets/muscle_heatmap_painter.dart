import 'package:flutter/material.dart';
import '../data/exercise_muscle_map.dart';

/// 筋肉部位ヒートマップウィジェット
/// 前面・背面の簡略化された人体シルエットに色を重ねて表示する
class MuscleHeatmapWidget extends StatelessWidget {
  const MuscleHeatmapWidget({
    super.key,
    required this.heatmap,
  });

  final Map<MuscleGroup, double> heatmap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasActivity = heatmap.values.any((v) => v > 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _BodyView(
                label: '前面',
                heatmap: heatmap,
                isFront: true,
                scheme: scheme,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _BodyView(
                label: '背面',
                heatmap: heatmap,
                isFront: false,
                scheme: scheme,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (hasActivity)
          _buildLegend(context, scheme)
        else
          Center(
            child: Text(
              '過去7日間のトレーニングデータがありません',
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildLegend(BuildContext context, ColorScheme scheme) {
    final sorted = heatmap.entries
        .where((e) => e.value > 0)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: sorted.take(6).map((entry) {
        final color = _heatColor(entry.value);
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              entry.key.label,
              style: TextStyle(
                fontSize: 11,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}

class _BodyView extends StatelessWidget {
  const _BodyView({
    required this.label,
    required this.heatmap,
    required this.isFront,
    required this.scheme,
  });

  final String label;
  final Map<MuscleGroup, double> heatmap;
  final bool isFront;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        AspectRatio(
          aspectRatio: 0.55,
          child: CustomPaint(
            painter: _BodySilhouettePainter(
              heatmap: heatmap,
              isFront: isFront,
              baseColor: scheme.surfaceContainerHighest,
              outlineColor: scheme.outlineVariant,
            ),
          ),
        ),
      ],
    );
  }
}

Color _heatColor(double intensity) {
  if (intensity <= 0) return Colors.transparent;
  if (intensity < 0.3) return Colors.blue.shade200;
  if (intensity < 0.6) return Colors.orange.shade300;
  return Colors.red.shade400;
}

class _BodySilhouettePainter extends CustomPainter {
  _BodySilhouettePainter({
    required this.heatmap,
    required this.isFront,
    required this.baseColor,
    required this.outlineColor,
  });

  final Map<MuscleGroup, double> heatmap;
  final bool isFront;
  final Color baseColor;
  final Color outlineColor;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final basePaint = Paint()
      ..color = baseColor
      ..style = PaintingStyle.fill;

    final outlinePaint = Paint()
      ..color = outlineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // 胴体（頭〜足）をベースとして描画
    _drawBase(canvas, w, h, basePaint, outlinePaint);

    // 各筋肉部位を描画
    if (isFront) {
      _drawFrontMuscles(canvas, w, h);
    } else {
      _drawBackMuscles(canvas, w, h);
    }
  }

  void _drawBase(Canvas canvas, double w, double h, Paint fill, Paint stroke) {
    // 頭
    final headCenter = Offset(w * 0.5, h * 0.055);
    final headRadius = w * 0.11;
    canvas.drawCircle(headCenter, headRadius, fill);
    canvas.drawCircle(headCenter, headRadius, stroke);

    // 首
    final neckRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.115),
        width: w * 0.14,
        height: h * 0.04,
      ),
      const Radius.circular(4),
    );
    canvas.drawRRect(neckRect, fill);
    canvas.drawRRect(neckRect, stroke);

    // 胴体
    final torsoPath = Path()
      ..moveTo(w * 0.2, h * 0.13)
      ..lineTo(w * 0.8, h * 0.13)
      ..lineTo(w * 0.75, h * 0.42)
      ..lineTo(w * 0.7, h * 0.48)
      ..lineTo(w * 0.3, h * 0.48)
      ..lineTo(w * 0.25, h * 0.42)
      ..close();
    canvas.drawPath(torsoPath, fill);
    canvas.drawPath(torsoPath, stroke);

    // 腰・骨盤
    final hipPath = Path()
      ..moveTo(w * 0.28, h * 0.47)
      ..lineTo(w * 0.72, h * 0.47)
      ..lineTo(w * 0.68, h * 0.57)
      ..lineTo(w * 0.32, h * 0.57)
      ..close();
    canvas.drawPath(hipPath, fill);
    canvas.drawPath(hipPath, stroke);

    // 左上腕
    _drawRoundRect(canvas, w * 0.08, h * 0.14, w * 0.1, h * 0.15, fill, stroke);
    // 右上腕
    _drawRoundRect(canvas, w * 0.82, h * 0.14, w * 0.1, h * 0.15, fill, stroke);

    // 左前腕
    _drawRoundRect(canvas, w * 0.09, h * 0.3, w * 0.09, h * 0.14, fill, stroke);
    // 右前腕
    _drawRoundRect(canvas, w * 0.82, h * 0.3, w * 0.09, h * 0.14, fill, stroke);

    // 左大腿
    _drawRoundRect(canvas, w * 0.3, h * 0.57, w * 0.17, h * 0.2, fill, stroke);
    // 右大腿
    _drawRoundRect(canvas, w * 0.53, h * 0.57, w * 0.17, h * 0.2, fill, stroke);

    // 左下腿
    _drawRoundRect(canvas, w * 0.31, h * 0.78, w * 0.14, h * 0.18, fill, stroke);
    // 右下腿
    _drawRoundRect(canvas, w * 0.55, h * 0.78, w * 0.14, h * 0.18, fill, stroke);
  }

  void _drawFrontMuscles(Canvas canvas, double w, double h) {
    // 胸
    _drawHeat(canvas, MuscleGroup.chest, () {
      final path = Path()
        ..moveTo(w * 0.25, h * 0.15)
        ..lineTo(w * 0.5, h * 0.18)
        ..lineTo(w * 0.5, h * 0.3)
        ..lineTo(w * 0.26, h * 0.32)
        ..close();
      return path;
    });
    _drawHeat(canvas, MuscleGroup.chest, () {
      final path = Path()
        ..moveTo(w * 0.75, h * 0.15)
        ..lineTo(w * 0.5, h * 0.18)
        ..lineTo(w * 0.5, h * 0.3)
        ..lineTo(w * 0.74, h * 0.32)
        ..close();
      return path;
    });

    // 肩
    _drawHeatOval(canvas, MuscleGroup.shoulders, w * 0.18, h * 0.145, w * 0.1, h * 0.07);
    _drawHeatOval(canvas, MuscleGroup.shoulders, w * 0.82, h * 0.145, w * 0.1, h * 0.07);

    // 上腕二頭筋
    _drawHeatRect(canvas, MuscleGroup.biceps, w * 0.09, h * 0.165, w * 0.09, h * 0.13);
    _drawHeatRect(canvas, MuscleGroup.biceps, w * 0.82, h * 0.165, w * 0.09, h * 0.13);

    // 前腕
    _drawHeatRect(canvas, MuscleGroup.forearms, w * 0.1, h * 0.31, w * 0.08, h * 0.12);
    _drawHeatRect(canvas, MuscleGroup.forearms, w * 0.82, h * 0.31, w * 0.08, h * 0.12);

    // 腹筋
    final absPath = Path()
      ..moveTo(w * 0.37, h * 0.32)
      ..lineTo(w * 0.63, h * 0.32)
      ..lineTo(w * 0.62, h * 0.46)
      ..lineTo(w * 0.38, h * 0.46)
      ..close();
    _drawHeatPath(canvas, MuscleGroup.abs, absPath);

    // 大腿四頭筋
    _drawHeatRect(canvas, MuscleGroup.quads, w * 0.3, h * 0.58, w * 0.16, h * 0.18);
    _drawHeatRect(canvas, MuscleGroup.quads, w * 0.54, h * 0.58, w * 0.16, h * 0.18);

    // ふくらはぎ（前面）
    _drawHeatRect(canvas, MuscleGroup.calves, w * 0.32, h * 0.79, w * 0.12, h * 0.15);
    _drawHeatRect(canvas, MuscleGroup.calves, w * 0.56, h * 0.79, w * 0.12, h * 0.15);
  }

  void _drawBackMuscles(Canvas canvas, double w, double h) {
    // 広背筋（背中）
    _drawHeat(canvas, MuscleGroup.back, () {
      final path = Path()
        ..moveTo(w * 0.25, h * 0.15)
        ..lineTo(w * 0.5, h * 0.2)
        ..lineTo(w * 0.5, h * 0.38)
        ..lineTo(w * 0.3, h * 0.42)
        ..close();
      return path;
    });
    _drawHeat(canvas, MuscleGroup.back, () {
      final path = Path()
        ..moveTo(w * 0.75, h * 0.15)
        ..lineTo(w * 0.5, h * 0.2)
        ..lineTo(w * 0.5, h * 0.38)
        ..lineTo(w * 0.7, h * 0.42)
        ..close();
      return path;
    });

    // 肩（後面）
    _drawHeatOval(canvas, MuscleGroup.shoulders, w * 0.18, h * 0.145, w * 0.1, h * 0.07);
    _drawHeatOval(canvas, MuscleGroup.shoulders, w * 0.82, h * 0.145, w * 0.1, h * 0.07);

    // 上腕三頭筋
    _drawHeatRect(canvas, MuscleGroup.triceps, w * 0.09, h * 0.165, w * 0.09, h * 0.13);
    _drawHeatRect(canvas, MuscleGroup.triceps, w * 0.82, h * 0.165, w * 0.09, h * 0.13);

    // 前腕（背面）
    _drawHeatRect(canvas, MuscleGroup.forearms, w * 0.1, h * 0.31, w * 0.08, h * 0.12);
    _drawHeatRect(canvas, MuscleGroup.forearms, w * 0.82, h * 0.31, w * 0.08, h * 0.12);

    // 臀部
    _drawHeatRect(canvas, MuscleGroup.glutes, w * 0.3, h * 0.48, w * 0.17, h * 0.1);
    _drawHeatRect(canvas, MuscleGroup.glutes, w * 0.53, h * 0.48, w * 0.17, h * 0.1);

    // ハムストリング
    _drawHeatRect(canvas, MuscleGroup.hamstrings, w * 0.3, h * 0.58, w * 0.16, h * 0.18);
    _drawHeatRect(canvas, MuscleGroup.hamstrings, w * 0.54, h * 0.58, w * 0.16, h * 0.18);

    // ふくらはぎ（後面）
    _drawHeatRect(canvas, MuscleGroup.calves, w * 0.32, h * 0.79, w * 0.12, h * 0.15);
    _drawHeatRect(canvas, MuscleGroup.calves, w * 0.56, h * 0.79, w * 0.12, h * 0.15);
  }

  void _drawHeat(Canvas canvas, MuscleGroup group, Path Function() pathBuilder) {
    final intensity = heatmap[group] ?? 0.0;
    if (intensity <= 0) return;
    final color = _heatColor(intensity).withValues(alpha: 0.75);
    canvas.drawPath(pathBuilder(), Paint()..color = color);
  }

  void _drawHeatPath(Canvas canvas, MuscleGroup group, Path path) {
    final intensity = heatmap[group] ?? 0.0;
    if (intensity <= 0) return;
    final color = _heatColor(intensity).withValues(alpha: 0.75);
    canvas.drawPath(path, Paint()..color = color);
  }

  void _drawHeatOval(
      Canvas canvas, MuscleGroup group, double cx, double cy, double rw, double rh) {
    final intensity = heatmap[group] ?? 0.0;
    if (intensity <= 0) return;
    final color = _heatColor(intensity).withValues(alpha: 0.75);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy), width: rw * 2, height: rh * 2),
      Paint()..color = color,
    );
  }

  void _drawHeatRect(
      Canvas canvas, MuscleGroup group, double x, double y, double w, double h) {
    final intensity = heatmap[group] ?? 0.0;
    if (intensity <= 0) return;
    final color = _heatColor(intensity).withValues(alpha: 0.75);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), const Radius.circular(4)),
      Paint()..color = color,
    );
  }

  void _drawRoundRect(Canvas canvas, double x, double y, double w, double h,
      Paint fill, Paint stroke) {
    final rr = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, w, h), const Radius.circular(4));
    canvas.drawRRect(rr, fill);
    canvas.drawRRect(rr, stroke);
  }

  @override
  bool shouldRepaint(_BodySilhouettePainter oldDelegate) {
    return oldDelegate.heatmap != heatmap || oldDelegate.isFront != isFront;
  }
}
