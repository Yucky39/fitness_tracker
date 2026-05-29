import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/body_metrics.dart';

/// 体型写真のスプリット比較画面。
///
/// - 向き（正面/側面/背面）タブで切り替え
/// - 縦バーを左右にドラッグして現在写真の表示幅を調整
/// - 右端の縦スライダーで現在写真の透過率を10%単位で変更
/// - 同じ向きの写真が過去・現在の両方に存在しない場合は比較不可
class PhotoCompareScreen extends StatefulWidget {
  /// 現在（最新）の記録
  final BodyMetrics current;

  /// 比較候補となる過去の記録一覧（current を除いたもの、日付降順）
  final List<BodyMetrics> pastMetrics;

  /// 画面を開いたときに選択する向き（省略時は最初に写真がある向き）
  final PhotoDirection? initialDirection;

  const PhotoCompareScreen({
    super.key,
    required this.current,
    required this.pastMetrics,
    this.initialDirection,
  });

  @override
  State<PhotoCompareScreen> createState() => _PhotoCompareScreenState();
}

class _PhotoCompareScreenState extends State<PhotoCompareScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // 分割バーの位置（0.0 = 左端, 1.0 = 右端）
  double _splitFraction = 0.5;

  // 現在写真の透過率（0.0 = 完全透明, 1.0 = 不透明）
  double _opacity = 1.0;

  // 各タブで選択中の過去記録インデックス
  final Map<PhotoDirection, int> _selectedPastIndex = {};

  static const List<PhotoDirection> _directions = PhotoDirection.values;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _directions.length, vsync: this);

    // 初期タブ: 引数の向き or 比較可能な最初の向き
    final initial = widget.initialDirection ??
        _directions.firstWhere(
          (d) => _comparablePastMetrics(d).isNotEmpty,
          orElse: () => PhotoDirection.front,
        );
    _tabController.index = _directions.indexOf(initial);

    // 各向きのデフォルト選択（最新の過去記録）
    for (final d in _directions) {
      _selectedPastIndex[d] = 0;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// [direction] で比較可能な過去記録（その向きの写真がある）
  List<BodyMetrics> _comparablePastMetrics(PhotoDirection direction) {
    return widget.pastMetrics
        .where((m) => m.pathForDirection(direction) != null)
        .toList();
  }

  PhotoDirection get _currentDirection => _directions[_tabController.index];

  BodyMetrics? get _selectedPast {
    final list = _comparablePastMetrics(_currentDirection);
    if (list.isEmpty) return null;
    final idx = _selectedPastIndex[_currentDirection] ?? 0;
    return list[idx.clamp(0, list.length - 1)];
  }

  String? get _currentPath =>
      widget.current.pathForDirection(_currentDirection);

  String? get _pastPath => _selectedPast?.pathForDirection(_currentDirection);

  bool get _canCompare => _currentPath != null && _pastPath != null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('体型比較'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          indicatorColor: Theme.of(context).colorScheme.primary,
          onTap: (_) => setState(() {}),
          tabs: _directions.map((d) {
            final canCompare = _comparablePastMetrics(d).isNotEmpty &&
                widget.current.pathForDirection(d) != null;
            return Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(d.label),
                  if (!canCompare) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.block, size: 12, color: Colors.white38),
                  ],
                ],
              ),
            );
          }).toList(),
        ),
      ),
      body: Column(
        children: [
          // ── 比較エリア ────────────────────────────────────────────────
          Expanded(
            child: _canCompare
                ? _buildCompareArea()
                : _buildNoCompareMessage(),
          ),

          // ── 過去記録セレクター ─────────────────────────────────────────
          if (_canCompare || _comparablePastMetrics(_currentDirection).isNotEmpty)
            _buildPastSelector(),
        ],
      ),
    );
  }

  // ── 比較エリア（スプリット + 透過率スライダー）────────────────────────

  Widget _buildCompareArea() {
    return Row(
      children: [
        // スプリット比較本体
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final totalWidth = constraints.maxWidth;
              final splitX = totalWidth * _splitFraction;

              return GestureDetector(
                onHorizontalDragUpdate: (details) {
                  setState(() {
                    _splitFraction = (_splitFraction +
                            details.delta.dx / totalWidth)
                        .clamp(0.02, 0.98);
                  });
                },
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // 過去写真（左全体）
                    Image.file(
                      File(_pastPath!),
                      fit: BoxFit.contain,
                      width: double.infinity,
                      height: double.infinity,
                    ),

                    // 現在写真（右側にクリップ）
                    ClipRect(
                      child: Align(
                        alignment: Alignment.centerRight,
                        widthFactor: 1 - _splitFraction,
                        child: Opacity(
                          opacity: _opacity,
                          child: Image.file(
                            File(_currentPath!),
                            fit: BoxFit.contain,
                            width: double.infinity,
                            height: double.infinity,
                          ),
                        ),
                      ),
                    ),

                    // 分割ライン
                    Positioned(
                      left: splitX - 1,
                      top: 0,
                      bottom: 0,
                      width: 2,
                      child: Container(color: Colors.white),
                    ),

                    // ドラッグハンドル
                    Positioned(
                      left: splitX - 16,
                      top: 0,
                      bottom: 0,
                      width: 32,
                      child: Center(
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.4),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.swap_horiz,
                            size: 18,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ),

                    // ラベル（左=過去、右=現在）
                    Positioned(
                      left: 8,
                      top: 8,
                      child: _photoLabel('過去', _selectedPast?.date),
                    ),
                    Positioned(
                      right: 8,
                      top: 8,
                      child: _photoLabel('現在', widget.current.date),
                    ),
                  ],
                ),
              );
            },
          ),
        ),

        // 透過率スライダー（縦方向）
        _buildOpacitySlider(),
      ],
    );
  }

  Widget _photoLabel(String text, DateTime? date) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold)),
          if (date != null)
            Text(DateFormat('MM/dd').format(date),
                style:
                    const TextStyle(color: Colors.white70, fontSize: 10)),
        ],
      ),
    );
  }

  // ── 縦スライダー（透過率） ────────────────────────────────────────────

  Widget _buildOpacitySlider() {
    final pct = (_opacity * 100).round();
    return Container(
      width: 48,
      color: Colors.black87,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          Text(
            '$pct%',
            style: const TextStyle(
                color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: RotatedBox(
              quarterTurns: 3, // 縦方向（上=100%, 下=0%）
              child: Slider(
                value: _opacity,
                min: 0.0,
                max: 1.0,
                divisions: 10, // 10%刻み
                onChanged: (v) {
                  setState(() {
                    _opacity = (v * 10).round() / 10;
                  });
                },
              ),
            ),
          ),
          const SizedBox(height: 4),
          const Text('透過',
              style: TextStyle(color: Colors.white54, fontSize: 9)),
        ],
      ),
    );
  }

  // ── 比較不可メッセージ ─────────────────────────────────────────────────

  Widget _buildNoCompareMessage() {
    final dir = _currentDirection;
    final hasCurrent = _currentPath != null;
    final hasPast = _comparablePastMetrics(dir).isNotEmpty;

    String message;
    if (!hasCurrent && !hasPast) {
      message = '現在と過去の記録どちらにも\n${dir.label}の写真がありません';
    } else if (!hasCurrent) {
      message = '最新の記録に${dir.label}の写真がありません\n記録を編集して写真を追加してください';
    } else {
      message = '比較できる過去の${dir.label}写真がありません\n過去の記録に${dir.label}の写真を追加してください';
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white54, fontSize: 14),
        ),
      ),
    );
  }

  // ── 過去記録セレクター ─────────────────────────────────────────────────

  Widget _buildPastSelector() {
    final dir = _currentDirection;
    final list = _comparablePastMetrics(dir);

    return Container(
      color: Colors.grey.shade900,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
            child: Text(
              '比較する過去の写真（${dir.label}）',
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w600),
            ),
          ),
          if (list.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Text('過去の記録がありません',
                  style: TextStyle(color: Colors.white38, fontSize: 12)),
            )
          else
            SizedBox(
              height: 92,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: list.length,
                itemBuilder: (context, i) {
                  final m = list[i];
                  final isSelected =
                      (_selectedPastIndex[dir] ?? 0) == i;
                  final path = m.pathForDirection(dir)!;

                  return GestureDetector(
                    onTap: () =>
                        setState(() => _selectedPastIndex[dir] = i),
                    child: Container(
                      width: 64,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Colors.white24,
                          width: isSelected ? 2.5 : 1,
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Column(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(5),
                              ),
                              child: Image.file(
                                File(path),
                                fit: BoxFit.cover,
                                width: double.infinity,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(3),
                            child: Text(
                              DateFormat('MM/dd').format(m.date),
                              style: TextStyle(
                                fontSize: 9,
                                color: isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.white70,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
