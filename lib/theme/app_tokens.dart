import 'package:flutter/material.dart';

/// BeWell デザインシステム — スペーシング・角丸・ブランド定数。
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;

  /// ボトムナビ + FAB 用のスクロール末尾余白。
  static const double bottomNavClearance = 88;
}

abstract final class AppRadius {
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;

  static BorderRadius get smAll => BorderRadius.circular(sm);
  static BorderRadius get mdAll => BorderRadius.circular(md);
  static BorderRadius get lgAll => BorderRadius.circular(lg);
  static BorderRadius get xlAll => BorderRadius.circular(xl);
}

/// ブランドカラー（ColorScheme 生成のシード）。
abstract final class BeWellBrand {
  /// エメラルド系 — 健康・ウェルネスを想起させる独自トーン。
  static const Color seed = Color(0xFF0F766E);
  static const Color seedLight = Color(0xFF14B8A6);
  static const Color aiAccent = Color(0xFF6366F1);
}
