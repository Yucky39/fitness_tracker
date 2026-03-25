import 'dart:io';
import 'package:flutter/material.dart';

class PhotoCompareScreen extends StatefulWidget {
  final String currentImagePath;
  final String? previousImagePath;

  const PhotoCompareScreen({
    super.key,
    required this.currentImagePath,
    this.previousImagePath,
  });

  @override
  State<PhotoCompareScreen> createState() => _PhotoCompareScreenState();
}

class _PhotoCompareScreenState extends State<PhotoCompareScreen> {
  double _opacity = 0.5;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('体型比較'),
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Previous Image (Base)
                if (widget.previousImagePath != null)
                  Image.file(
                    File(widget.previousImagePath!),
                    fit: BoxFit.contain,
                  )
                else
                  const Center(child: Text('比較対象の画像がありません')),

                // Current Image (Overlay)
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
}
