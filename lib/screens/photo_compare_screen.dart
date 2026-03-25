import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/body_metrics.dart';

class PhotoCompareScreen extends StatefulWidget {
  final String currentImagePath;
  final List<BodyMetrics> otherMetrics;

  const PhotoCompareScreen({
    super.key,
    required this.currentImagePath,
    required this.otherMetrics,
  });

  @override
  State<PhotoCompareScreen> createState() => _PhotoCompareScreenState();
}

class _PhotoCompareScreenState extends State<PhotoCompareScreen> {
  double _opacity = 0.5;
  int _compareIndex = 0;

  String? get _compareImagePath {
    if (widget.otherMetrics.isEmpty) return null;
    return widget.otherMetrics[_compareIndex].imagePath;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('体型比較'),
        actions: [
          if (widget.otherMetrics.length > 1)
            IconButton(
              icon: const Icon(Icons.compare_arrows),
              tooltip: '比較対象を変更',
              onPressed: _showCompareSelector,
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (_compareImagePath != null)
                  Image.file(
                    File(_compareImagePath!),
                    fit: BoxFit.contain,
                  )
                else
                  const Center(child: Text('比較対象の画像がありません')),
                Opacity(
                  opacity: _opacity,
                  child: Image.file(
                    File(widget.currentImagePath),
                    fit: BoxFit.contain,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                if (_compareImagePath != null && widget.otherMetrics.isNotEmpty)
                  Text(
                    '比較対象: ${DateFormat('yyyy/MM/dd').format(widget.otherMetrics[_compareIndex].date)}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                const SizedBox(height: 4),
                const Text('透明度調整'),
                Slider(
                  value: _opacity,
                  min: 0.0,
                  max: 1.0,
                  onChanged: (value) {
                    setState(() {
                      _opacity = value;
                    });
                  },
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text('過去'),
                    Text('現在'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showCompareSelector() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              '比較する記録を選択',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: widget.otherMetrics.length,
              itemBuilder: (context, i) {
                final m = widget.otherMetrics[i];
                final isSelected = i == _compareIndex;
                return GestureDetector(
                  onTap: () {
                    setState(() => _compareIndex = i);
                    Navigator.pop(context);
                  },
                  child: Container(
                    width: 90,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey,
                        width: isSelected ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(7),
                            ),
                            child: Image.file(
                              File(m.imagePath!),
                              fit: BoxFit.cover,
                              width: double.infinity,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(4),
                          child: Text(
                            DateFormat('MM/dd').format(m.date),
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
