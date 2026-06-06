import 'package:flutter/material.dart';

/// 進捗グラフの指標別カラー（体重 / 体脂肪 / 腹囲）。
abstract final class ChartMetricColors {
  static Color forMetric(int index, ColorScheme scheme) {
    return switch (index) {
      0 => scheme.primary,
      1 => scheme.tertiary,
      _ => scheme.secondary,
    };
  }
}
