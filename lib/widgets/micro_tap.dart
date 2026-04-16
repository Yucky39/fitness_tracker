import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// タップ時にスケールバウンスアニメーションとHapticFeedbackを提供するラッパー。
///
/// ```dart
/// MicroTap(
///   onTap: () { ... },
///   child: Card(...),
/// )
/// ```
class MicroTap extends StatefulWidget {
  const MicroTap({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = 0.95,
    this.haptic = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// 押下時のスケール倍率（デフォルト 0.95）。
  final double scale;

  /// タップ確定時に HapticFeedback.lightImpact を発火するか。
  final bool haptic;

  @override
  State<MicroTap> createState() => _MicroTapState();
}

class _MicroTapState extends State<MicroTap>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
      reverseDuration: const Duration(milliseconds: 200),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: widget.scale).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: Curves.easeIn,
        reverseCurve: Curves.elasticOut,
      ),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) => _ctrl.forward();

  void _onTapUp(TapUpDetails _) {
    _ctrl.reverse();
    if (widget.haptic) HapticFeedback.lightImpact();
    widget.onTap?.call();
  }

  void _onTapCancel() => _ctrl.reverse();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.onTap != null ? _onTapDown : null,
      onTapUp: widget.onTap != null ? _onTapUp : null,
      onTapCancel: widget.onTap != null ? _onTapCancel : null,
      onLongPress: widget.onLongPress,
      behavior: HitTestBehavior.opaque,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: widget.child,
      ),
    );
  }
}
