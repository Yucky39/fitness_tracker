import 'package:flutter/material.dart';

import '../screens/faq_screen.dart';

class SourceReferenceLink extends StatelessWidget {
  const SourceReferenceLink({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        style: TextButton.styleFrom(
          padding: compact
              ? const EdgeInsets.symmetric(horizontal: 4)
              : const EdgeInsets.symmetric(horizontal: 8),
          visualDensity: compact ? VisualDensity.compact : null,
        ),
        icon: const Icon(Icons.menu_book_outlined, size: 16),
        label: const Text('情報源・参考資料を見る'),
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const FaqScreen()),
          );
        },
      ),
    );
  }
}
