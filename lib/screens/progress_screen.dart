import 'dart:io';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../providers/progress_provider.dart';
import '../models/body_metrics.dart';
import 'photo_compare_screen.dart';

class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressState = ref.watch(progressProvider);
    final progressNotifier = ref.read(progressProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('進捗トラッキング'),
      ),
      body: progressState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : progressState.metrics.isEmpty
              ? const Center(child: Text('まだ記録がありません'))
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildCharts(progressState.metrics),
                      const Divider(),
                      _buildMetricsList(context, progressState.metrics, progressNotifier),
                    ],
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddMetricsDialog(context, progressNotifier),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildCharts(List<BodyMetrics> metrics) {
    if (metrics.length < 2) {
      return const SizedBox(
        height: 200,
        child: Center(child: Text('グラフを表示するには2つ以上のデータが必要です')),
      );
    }

    return Container(
      height: 300,
      padding: const EdgeInsets.all(16),
      child: LineChart(
        LineChartData(
          lineBarsData: [
            // Weight Line
            LineChartBarData(
              spots: metrics.asMap().entries.map((e) {
                return FlSpot(e.key.toDouble(), e.value.weight);
              }).toList(),
              isCurved: true,
              color: Colors.blue,
              barWidth: 3,
              dotData: const FlDotData(show: true),
            ),
            // Body Fat Line (Scaled to fit roughly same range or separate axis - keeping simple for now)
            // Ideally should use dual axis or separate charts. Let's just show Weight for now to avoid confusion.
          ],
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index >= 0 && index < metrics.length) {
                    return Text(
                      DateFormat('MM/dd').format(metrics[index].date),
                      style: const TextStyle(fontSize: 10),
                    );
                  }
                  return const Text('');
                },
                interval: 1, // Adjust based on data size
              ),
            ),
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: true, reservedSize: 40),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: const FlGridData(show: true),
          borderData: FlBorderData(show: true),
        ),
      ),
    );
  }

  Widget _buildMetricsList(BuildContext context, List<BodyMetrics> metrics, ProgressNotifier notifier) {
    // Reverse to show newest first
    final reversedMetrics = metrics.reversed.toList();

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: reversedMetrics.length,
      itemBuilder: (context, index) {
        final item = reversedMetrics[index];
        return Dismissible(
          key: Key(item.id),
          onDismissed: (_) => notifier.deleteMetrics(item.id),
          background: Container(color: Colors.red),
          child: Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              leading: item.imagePath != null
                  ? GestureDetector(
                      onTap: () {
                        // Find previous image (which is next in the reversed list, or any older one)
                        String? prevImage;
                        if (index + 1 < reversedMetrics.length) {
                          for (int i = index + 1; i < reversedMetrics.length; i++) {
                            if (reversedMetrics[i].imagePath != null) {
                              prevImage = reversedMetrics[i].imagePath;
                              break;
                            }
                          }
                        }
                        
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PhotoCompareScreen(
                              currentImagePath: item.imagePath!,
                              previousImagePath: prevImage,
                            ),
                          ),
                        );
                      },
                      child: Image.file(
                        File(item.imagePath!),
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                      ),
                    )
                  : const Icon(Icons.person),
              title: Text('${DateFormat('yyyy/MM/dd').format(item.date)}'),
              subtitle: Text(
                '体重: ${item.weight}kg\n体脂肪率: ${item.bodyFatPercentage}%\n腹囲: ${item.waist}cm',
              ),
              isThreeLine: true,
            ),
          ),
        );
      },
    );
  }

  void _showAddMetricsDialog(BuildContext context, ProgressNotifier notifier) {
    final weightController = TextEditingController();
    final waistController = TextEditingController();
    final fatController = TextEditingController();
    String? selectedImagePath;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('進捗を記録'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: weightController,
                    decoration: const InputDecoration(labelText: '体重 (kg)'),
                    keyboardType: TextInputType.number,
                  ),
                  TextField(
                    controller: waistController,
                    decoration: const InputDecoration(labelText: '腹囲 (cm)'),
                    keyboardType: TextInputType.number,
                  ),
                  TextField(
                    controller: fatController,
                    decoration: const InputDecoration(labelText: '体脂肪率 (%)'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  if (selectedImagePath != null)
                    Image.file(
                      File(selectedImagePath!),
                      height: 100,
                    ),
                  TextButton.icon(
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('写真を撮る'),
                    onPressed: () async {
                      final picker = ImagePicker();
                      final XFile? image = await picker.pickImage(source: ImageSource.camera);
                      if (image != null) {
                        // Save to app directory
                        final directory = await getApplicationDocumentsDirectory();
                        final fileName = path.basename(image.path);
                        final savedImage = await File(image.path).copy('${directory.path}/$fileName');
                        
                        setState(() {
                          selectedImagePath = savedImage.path;
                        });
                      }
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('キャンセル'),
              ),
              TextButton(
                onPressed: () {
                  if (weightController.text.isNotEmpty) {
                    notifier.addMetrics(
                      weight: double.tryParse(weightController.text) ?? 0,
                      waist: double.tryParse(waistController.text) ?? 0,
                      bodyFatPercentage: double.tryParse(fatController.text) ?? 0,
                      imagePath: selectedImagePath,
                    );
                    Navigator.pop(context);
                  }
                },
                child: const Text('保存'),
              ),
            ],
          );
        },
      ),
    );
  }
}
