import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// ドロワー / 設定画面のセクション見出し。
class DrawerSectionHeader extends StatelessWidget {
  const DrawerSectionHeader(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.xs,
      ),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
      ),
    );
  }
}

/// 設定行の末尾 chevron。
class DrawerChevron extends StatelessWidget {
  const DrawerChevron({super.key});

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.chevron_right_rounded,
      size: 20,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
  }
}
