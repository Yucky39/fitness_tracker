import 'dart:io';

import 'package:flutter/material.dart';

import '../models/app_release.dart';
import '../services/app_update_service.dart';

Future<void> showAppUpdateDialog(BuildContext context) async {
  if (!Platform.isAndroid) return;

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => const _AppUpdateDialog(),
  );
}

class _AppUpdateDialog extends StatefulWidget {
  const _AppUpdateDialog();

  @override
  State<_AppUpdateDialog> createState() => _AppUpdateDialogState();
}

class _AppUpdateDialogState extends State<_AppUpdateDialog> {
  var _checking = true;
  var _downloading = false;
  var _progress = 0.0;
  String? _error;
  AppUpdateCheckResult? _result;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    setState(() {
      _checking = true;
      _error = null;
    });

    try {
      final result = await AppUpdateService().checkForUpdate();
      if (!mounted) return;
      setState(() {
        _result = result;
        _checking = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _checking = false;
      });
    }
  }

  Future<void> _install(AppRelease release) async {
    setState(() {
      _downloading = true;
      _progress = 0;
      _error = null;
    });

    try {
      await AppUpdateService().downloadAndInstall(
        release,
        onProgress: (p) {
          if (!mounted) return;
          setState(() => _progress = p);
        },
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _downloading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;

    return AlertDialog(
      title: const Text('アプリ更新'),
      content: SizedBox(
        width: double.maxFinite,
        child: _buildContent(result),
      ),
      actions: _buildActions(result),
    );
  }

  Widget _buildContent(AppUpdateCheckResult? result) {
    if (_checking) {
      return const Row(
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 16),
          Expanded(child: Text('更新を確認しています…')),
        ],
      );
    }

    if (_error != null) {
      return Text(_error!,
          style: TextStyle(color: Theme.of(context).colorScheme.error));
    }

    if (_downloading) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('APK をダウンロードしています…'),
          const SizedBox(height: 12),
          LinearProgressIndicator(value: _progress > 0 ? _progress : null),
          const SizedBox(height: 8),
          Text('${(_progress * 100).toStringAsFixed(0)}%'),
        ],
      );
    }

    if (result == null) {
      return const Text('更新情報を取得できませんでした。');
    }

    if (!result.hasUpdate) {
      return Text(
        '最新版です（ビルド ${result.currentVersionCode}）。',
      );
    }

    final release = result.release!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('新しいバージョンがあります: ${release.versionName} (${release.versionCode})'),
        const SizedBox(height: 8),
        Text('現在: ビルド ${result.currentVersionCode}'),
        if (release.releaseNotes.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text('更新内容:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(release.releaseNotes),
        ],
        const SizedBox(height: 12),
        Text(
          'ダウンロード後、システムのインストール画面が開きます。',
          style: TextStyle(
              fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }

  List<Widget> _buildActions(AppUpdateCheckResult? result) {
    if (_checking || _downloading) {
      return [
        TextButton(
          onPressed: _downloading ? null : () => Navigator.of(context).pop(),
          child: const Text('閉じる'),
        ),
      ];
    }

    if (_error != null) {
      return [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('閉じる'),
        ),
        FilledButton(
          onPressed: _check,
          child: const Text('再試行'),
        ),
      ];
    }

    if (result?.hasUpdate == true) {
      return [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('あとで'),
        ),
        FilledButton(
          onPressed: () => _install(result!.release!),
          child: const Text('ダウンロードしてインストール'),
        ),
      ];
    }

    return [
      FilledButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('OK'),
      ),
    ];
  }
}
