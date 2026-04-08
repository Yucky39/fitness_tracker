import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/body_metrics.dart';
import '../models/food_item.dart';
import '../models/training_log.dart';
import 'database_service.dart';

class ExportService {
  Future<void> exportAll() async {
    final db = await DatabaseService().database;

    final foodMaps = await db.query('food_items', orderBy: 'date ASC');
    final trainingMaps = await db.query('training_logs', orderBy: 'date ASC');
    final metricsMaps = await db.query('body_metrics', orderBy: 'date ASC');

    final foodItems = foodMaps.map(FoodItem.fromMap).toList();
    final trainingLogs = trainingMaps.map(TrainingLog.fromMap).toList();
    final metrics = metricsMaps.map(BodyMetrics.fromMap).toList();

    final dir = await getTemporaryDirectory();
    final now = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());

    final foodFile = File('${dir.path}/food_$now.csv');
    await foodFile.writeAsString(_buildFoodCsv(foodItems));

    final trainingFile = File('${dir.path}/training_$now.csv');
    await trainingFile.writeAsString(_buildTrainingCsv(trainingLogs));

    final metricsFile = File('${dir.path}/metrics_$now.csv');
    await metricsFile.writeAsString(_buildMetricsCsv(metrics));

    await Share.shareXFiles(
      [
        XFile(foodFile.path),
        XFile(trainingFile.path),
        XFile(metricsFile.path),
      ],
      subject: 'Fitness Tracker データエクスポート $now',
    );
  }

  String _buildFoodCsv(List<FoodItem> items) {
    final sb = StringBuffer();
    sb.writeln('日付,食品名,カロリー(kcal),タンパク質(g),脂質(g),炭水化物(g)');
    for (final item in items) {
      final date = DateFormat('yyyy/MM/dd HH:mm').format(item.date);
      sb.writeln(
          '$date,${item.name},${item.calories},${item.protein},${item.fat},${item.carbs}');
    }
    return sb.toString();
  }

  String _buildTrainingCsv(List<TrainingLog> logs) {
    final sb = StringBuffer();
    sb.writeln(
        '日付,種目,重量(kg),回数,セット数,インターバル(秒),RPE(1-10),メモ');
    for (final log in logs) {
      final date = DateFormat('yyyy/MM/dd HH:mm').format(log.date);
      final rpe = log.rpe?.toString() ?? '';
      sb.writeln(
          '$date,${log.exerciseName},${log.weight},${log.reps},${log.sets},${log.interval},$rpe,"${log.note}"');
    }
    return sb.toString();
  }

  String _buildMetricsCsv(List<BodyMetrics> metrics) {
    final sb = StringBuffer();
    sb.writeln('日付,体重(kg),腹囲(cm),体脂肪率(%)');
    for (final m in metrics) {
      final date = DateFormat('yyyy/MM/dd HH:mm').format(m.date);
      sb.writeln('$date,${m.weight},${m.waist},${m.bodyFatPercentage}');
    }
    return sb.toString();
  }
}
