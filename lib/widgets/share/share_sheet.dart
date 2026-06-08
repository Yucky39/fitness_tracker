import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../services/social_share_service.dart';

/// シェアカードを見せてX/Instagram/その他のボタンを提供するボトムシート。
///
/// [cardKey] は RepaintBoundary でラップされたカードの GlobalKey。
/// タップ時にキャプチャして各 SNS に渡す。
Future<void> showShareSheet(
  BuildContext context, {
  required GlobalKey cardKey,
  required Widget card,
  required String xText,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ShareSheet(cardKey: cardKey, card: card, xText: xText),
  );
}

class _ShareSheet extends StatefulWidget {
  const _ShareSheet({
    required this.cardKey,
    required this.card,
    required this.xText,
  });

  final GlobalKey cardKey;
  final Widget card;
  final String xText;

  @override
  State<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends State<_ShareSheet> {
  bool _isCapturing = false;

  Future<Uint8List?> _capture() async {
    if (_isCapturing) return null;
    setState(() => _isCapturing = true);
    // フレームが描画されるまで待つ
    await Future.microtask(() {});
    final bytes = await SocialShareService.captureCard(widget.cardKey);
    if (mounted) setState(() => _isCapturing = false);
    return bytes;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ドラッグハンドル
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: scheme.onSurface.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Text(
            'シェアして仲間に伝えよう',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 20),
          // シェアカードプレビュー
          RepaintBoundary(
            key: widget.cardKey,
            child: widget.card,
          ),
          const SizedBox(height: 24),
          // シェアボタン行
          Row(
            children: [
              Expanded(
                child: _ShareButton(
                  label: 'X (Twitter)',
                  backgroundColor: Colors.black,
                  icon: const Text(
                    '𝕏',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                  ),
                  onTap: () async {
                    Navigator.of(context).pop();
                    await SocialShareService.shareToX(widget.xText);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ShareButton(
                  label: 'Instagram',
                  backgroundColor: const Color(0xFFE1306C),
                  icon: const Icon(Icons.camera_alt_outlined,
                      color: Colors.white, size: 20),
                  isLoading: _isCapturing,
                  onTap: () async {
                    final bytes = await _capture();
                    if (bytes == null || !context.mounted) return;
                    Navigator.of(context).pop();
                    await SocialShareService.shareImageToInstagram(bytes);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ShareButton(
                  label: 'その他',
                  backgroundColor: scheme.surfaceContainerHighest,
                  textColor: scheme.onSurface,
                  icon: Icon(Icons.share_outlined,
                      color: scheme.onSurface, size: 20),
                  isLoading: _isCapturing,
                  onTap: () async {
                    final bytes = await _capture();
                    if (bytes == null || !context.mounted) return;
                    Navigator.of(context).pop();
                    await SocialShareService.shareImageGeneral(
                        bytes, widget.xText);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('スキップ',
                style: TextStyle(color: scheme.onSurfaceVariant)),
          ),
        ],
      ),
    );
  }
}

class _ShareButton extends StatelessWidget {
  const _ShareButton({
    required this.label,
    required this.backgroundColor,
    required this.icon,
    required this.onTap,
    this.textColor = Colors.white,
    this.isLoading = false,
  });

  final String label;
  final Color backgroundColor;
  final Widget icon;
  final VoidCallback onTap;
  final Color textColor;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: isLoading
            ? Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: textColor,
                  ),
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(width: 24, height: 24, child: icon),
                  const SizedBox(height: 6),
                  Text(
                    label,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
