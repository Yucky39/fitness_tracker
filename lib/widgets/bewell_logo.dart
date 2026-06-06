import 'package:flutter/material.dart';

/// BeWell ブランドロゴ — アプリアイコン画像 + 任意のテキスト。
class BeWellLogo extends StatelessWidget {
  const BeWellLogo({
    super.key,
    this.size = 28,
    this.showLabel = true,
    this.labelStyle,
  });

  final double size;
  final bool showLabel;
  final TextStyle? labelStyle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = labelStyle ??
        Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: scheme.primary,
              letterSpacing: -0.3,
            );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(size * 0.22),
          child: Image.asset(
            'assets/icons/bewell_app_icon.png',
            width: size,
            height: size,
            errorBuilder: (_, __, ___) => Icon(
              Icons.spa_rounded,
              size: size,
              color: scheme.primary,
            ),
          ),
        ),
        if (showLabel) ...[
          const SizedBox(width: 8),
          Text('BeWell', style: style),
        ],
      ],
    );
  }
}
