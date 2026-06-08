import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class SocialShareService {
  static const _hashtag = '#BeWell';

  static Future<void> shareToX(String message) async {
    final encoded = Uri.encodeComponent('$message $_hashtag');
    final appUri = Uri.parse('twitter://post?message=$encoded');
    final webUri = Uri.parse('https://x.com/intent/post?text=$encoded');
    if (await canLaunchUrl(appUri)) {
      await launchUrl(appUri);
    } else {
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    }
  }

  /// 画像をシステムシェアシート経由で共有（ユーザーが Instagram を選択できる）
  static Future<void> shareImageToInstagram(Uint8List imageBytes) async {
    final file = await _saveTempImage(imageBytes);
    await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path, mimeType: 'image/png', name: 'bewell_share.png')],
      text: _hashtag,
    ));
  }

  static Future<void> shareImageGeneral(
      Uint8List imageBytes, String message) async {
    final file = await _saveTempImage(imageBytes);
    await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path, mimeType: 'image/png', name: 'bewell_share.png')],
      text: '$message $_hashtag',
    ));
  }

  static Future<File> _saveTempImage(Uint8List bytes) async {
    final dir = await getTemporaryDirectory();
    final file = File(
        '${dir.path}/bewell_share_${DateTime.now().millisecondsSinceEpoch}.png');
    await file.writeAsBytes(bytes);
    return file;
  }

  /// RepaintBoundary のキーからウィジェットを PNG としてキャプチャする
  static Future<Uint8List?> captureCard(GlobalKey cardKey) async {
    try {
      final boundary =
          cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }
}
