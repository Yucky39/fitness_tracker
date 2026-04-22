import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/exercise_animation.dart';

/// 横スワイプで360度回転・性別切り替え対応の3D人体アニメーションウィジェット。
class StickFigureAnimationWidget extends StatefulWidget {
  final ExerciseAnimationData data;

  const StickFigureAnimationWidget({super.key, required this.data});

  @override
  State<StickFigureAnimationWidget> createState() =>
      _StickFigureAnimationWidgetState();
}

class _StickFigureAnimationWidgetState
    extends State<StickFigureAnimationWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  double _rotY = 0.0;
  bool _isFemale = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: widget.data.durationMs),
    )..repeat();
  }

  @override
  void didUpdateWidget(StickFigureAnimationWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data.durationMs != widget.data.durationMs) {
      _controller.duration = Duration(milliseconds: widget.data.durationMs);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        // ── 性別切り替え ──
        _GenderBar(
          isFemale: _isFemale,
          scheme: scheme,
          onToggle: (f) => setState(() => _isFemale = f),
        ),
        const SizedBox(height: 4),
        // ── 3Dアニメーションエリア ──
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragUpdate: (d) =>
                setState(() => _rotY += d.delta.dx * 0.013),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (_, __) {
                final joints = widget.data.interpolate(_controller.value);
                return CustomPaint(
                  painter: _Body3DPainter(
                    joints: joints,
                    rotY: _rotY,
                    isFemale: _isFemale,
                    color: scheme.primary,
                  ),
                  child: const SizedBox.expand(),
                );
              },
            ),
          ),
        ),
        // ── 操作ヒント ──
        Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.swap_horiz_rounded,
                  size: 12,
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.4)),
              const SizedBox(width: 3),
              Text(
                'スワイプで360°回転',
                style: TextStyle(
                  fontSize: 10,
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── 性別バー ──────────────────────────────────────────────────────────────────

class _GenderBar extends StatelessWidget {
  final bool isFemale;
  final ColorScheme scheme;
  final ValueChanged<bool> onToggle;

  const _GenderBar({
    required this.isFemale,
    required this.scheme,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _chip('♂', !isFemale, () => onToggle(false)),
        const SizedBox(width: 6),
        _chip('♀', isFemale, () => onToggle(true)),
      ],
    );
  }

  Widget _chip(String label, bool sel, VoidCallback tap) {
    return GestureDetector(
      onTap: tap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        decoration: BoxDecoration(
          color: sel ? scheme.primary.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: sel ? scheme.primary : scheme.outline.withValues(alpha: 0.4),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: sel ? scheme.primary : scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

// ── 3D人体ペインター ──────────────────────────────────────────────────────────

/// ボーン定義: (fromJoint, toJoint, radiusRatio)
/// radiusRatio は min(width, height) に対する比率
const _kBones = [
  ('l_shoulder', 'l_elbow', 0.040),
  ('l_elbow', 'l_hand', 0.030),
  ('r_shoulder', 'r_elbow', 0.040),
  ('r_elbow', 'r_hand', 0.030),
  ('l_hip', 'l_knee', 0.052),
  ('l_knee', 'l_foot', 0.038),
  ('r_hip', 'r_knee', 0.052),
  ('r_knee', 'r_foot', 0.038),
];

class _Body3DPainter extends CustomPainter {
  final Map<String, List<double>> joints;
  final double rotY;
  final bool isFemale;
  final Color color;

  const _Body3DPainter({
    required this.joints,
    required this.rotY,
    required this.isFemale,
    required this.color,
  });

  // Y軸回転を適用して2Dに投影する
  Offset _proj(List<double> j, double sc, double ox, double oy) {
    final x = j[0] - 0.5;
    final y = j[1];
    final z = j.length > 2 ? j[2] : 0.0;
    final cosA = math.cos(rotY);
    final sinA = math.sin(rotY);
    final xr = x * cosA + z * sinA;
    final zr = -x * sinA + z * cosA;
    final persp = 1.0 / (1.0 + zr * 0.28);
    return Offset(ox + (xr * persp + 0.5) * sc, oy + y * sc);
  }

  // 回転後のZ深度（描画順ソート用）
  double _dep(List<double> j) {
    final x = j[0] - 0.5;
    final z = j.length > 2 ? j[2] : 0.0;
    return -x * math.sin(rotY) + z * math.cos(rotY);
  }

  Paint _mkPaint(double dep, double alpha) {
    final bright = (1.0 - dep.clamp(-0.4, 0.4) * 0.40).clamp(0.55, 1.0);
    return Paint()
      ..color = color.withValues(alpha: (alpha * bright).clamp(0.0, 1.0))
      ..style = PaintingStyle.fill;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (joints.isEmpty) return;

    final sc = math.min(size.width, size.height);
    final ox = (size.width - sc) / 2;
    final oy = (size.height - sc) / 2;

    Offset p(String k) {
      final j = joints[k];
      if (j == null) return Offset(ox + sc * 0.5, oy + sc * 0.5);
      return _proj(j, sc, ox, oy);
    }

    double d(String k) {
      final j = joints[k];
      return j == null ? 0.0 : _dep(j);
    }

    // ── 体幹（台形）──
    final lSh = p('l_shoulder');
    final rSh = p('r_shoulder');
    final lHp = p('l_hip');
    final rHp = p('r_hip');
    final sMid = Offset((lSh.dx + rSh.dx) / 2, (lSh.dy + rSh.dy) / 2);
    final hMid = Offset((lHp.dx + rHp.dx) / 2, (lHp.dy + rHp.dy) / 2);

    // 女性: 肩幅やや狭く・腰幅やや広く
    final sVec = (rSh - lSh) * (isFemale ? 0.46 : 0.52);
    final hVec = (rHp - lHp) * (isFemale ? 0.56 : 0.50);

    final torsoDepth = (d('l_shoulder') + d('r_shoulder') + d('l_hip') + d('r_hip')) / 4;
    canvas.drawPath(
      Path()
        ..moveTo(sMid.dx - sVec.dx, sMid.dy - sVec.dy)
        ..lineTo(sMid.dx + sVec.dx, sMid.dy + sVec.dy)
        ..lineTo(hMid.dx + hVec.dx, hMid.dy + hVec.dy)
        ..lineTo(hMid.dx - hVec.dx, hMid.dy - hVec.dy)
        ..close(),
      _mkPaint(torsoDepth, 0.90),
    );

    // ── 首 ──
    final headJ = joints['head'];
    if (headJ != null) {
      final headP = _proj(headJ, sc, ox, oy);
      final headR = sc * 0.068;
      final neckPaint = Paint()
        ..color = color.withValues(alpha: 0.85 * (1.0 - _dep(headJ).clamp(-0.4, 0.4) * 0.4).clamp(0.5, 1.0))
        ..strokeWidth = sc * 0.034
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      canvas.drawLine(Offset(headP.dx, headP.dy + headR), sMid, neckPaint);
    }

    // ── ボーン（深度ソートして奥→手前の順に描画）──
    final boneList = <({Offset p1, Offset p2, double r, double dep})>[];
    for (final b in _kBones) {
      final j1 = joints[b.$1];
      final j2 = joints[b.$2];
      if (j1 == null || j2 == null) continue;
      boneList.add((
        p1: _proj(j1, sc, ox, oy),
        p2: _proj(j2, sc, ox, oy),
        r: b.$3 * sc,
        dep: (_dep(j1) + _dep(j2)) / 2,
      ));
    }
    boneList.sort((a, b) => b.dep.compareTo(a.dep));

    for (final b in boneList) {
      _capsule(canvas, b.p1, b.p2, b.r, _mkPaint(b.dep, 1.0));
    }

    // ── 頭 ──
    if (headJ != null) {
      final headP = _proj(headJ, sc, ox, oy);
      final headR = sc * 0.068;
      final hDep = _dep(headJ);
      canvas.drawCircle(headP, headR, _mkPaint(hDep, 1.0));

      // 鼻（回転に合わせて位置が変わる方向インジケータ）
      canvas.drawCircle(
        Offset(
          headP.dx + headR * 0.50 * math.sin(rotY),
          headP.dy + headR * 0.28,
        ),
        headR * 0.20,
        Paint()
          ..color = color.withValues(alpha: 0.28)
          ..style = PaintingStyle.fill,
      );
    }

    // ── 関節ドット（肘・膝）──
    final dotPaint = Paint()
      ..color = color.withValues(alpha: 0.55)
      ..style = PaintingStyle.fill;
    for (final k in ['l_elbow', 'r_elbow', 'l_knee', 'r_knee']) {
      final j = joints[k];
      if (j != null) {
        canvas.drawCircle(_proj(j, sc, ox, oy), sc * 0.022, dotPaint);
      }
    }
  }

  void _capsule(Canvas canvas, Offset p1, Offset p2, double r, Paint paint) {
    final dir = p2 - p1;
    final len = dir.distance;
    if (len < 0.5) {
      canvas.drawCircle(p1, r.clamp(1.0, 60.0), paint);
      return;
    }
    final n = dir / len;
    final perp = Offset(-n.dy, n.dx);
    canvas.drawPath(
      Path()
        ..moveTo(p1.dx + perp.dx * r, p1.dy + perp.dy * r)
        ..lineTo(p2.dx + perp.dx * r, p2.dy + perp.dy * r)
        ..arcToPoint(
          Offset(p2.dx - perp.dx * r, p2.dy - perp.dy * r),
          radius: Radius.circular(r),
          clockwise: true,
        )
        ..lineTo(p1.dx - perp.dx * r, p1.dy - perp.dy * r)
        ..arcToPoint(
          Offset(p1.dx + perp.dx * r, p1.dy + perp.dy * r),
          radius: Radius.circular(r),
          clockwise: true,
        )
        ..close(),
      paint,
    );
  }

  @override
  bool shouldRepaint(_Body3DPainter old) =>
      old.joints != joints || old.rotY != rotY || old.isFemale != isFemale;
}
