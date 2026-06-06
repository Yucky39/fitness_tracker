import 'package:cloud_firestore/cloud_firestore.dart';

import 'detailed_nutrients.dart';
import 'micronutrients.dart';

/// 他ユーザーと共有するサプリメント／プロテインの登録データ。
/// マクロ栄養素に加え、ビタミン・ミネラル・脂肪酸・アミノ酸などの
/// 詳細栄養（1回分）まで保持し、呼び出し時に内容を詳細確認できるようにする。
class CommunitySupplementEntry {
  final String id;
  final String name;
  final String nameSearch; // name.toLowerCase() — used for prefix queries
  final String brand; // メーカー・ブランド（任意）
  final String servingNote; // 1回分の目安（任意。例: 付属スプーン2杯 / 30g）
  final int calories;
  final double protein;
  final double fat;
  final double carbs;
  final double sugar;
  final double fiber;
  final double sodium;
  final Micronutrients micronutrients;
  final DetailedNutrients detailedNutrients;
  final String contributedBy; // userId only — no PII
  final DateTime createdAt;
  final int useCount;

  const CommunitySupplementEntry({
    required this.id,
    required this.name,
    required this.nameSearch,
    this.brand = '',
    this.servingNote = '',
    required this.calories,
    required this.protein,
    required this.fat,
    required this.carbs,
    this.sugar = 0,
    this.fiber = 0,
    this.sodium = 0,
    this.micronutrients = Micronutrients.zero,
    this.detailedNutrients = DetailedNutrients.zero,
    required this.contributedBy,
    required this.createdAt,
    this.useCount = 0,
  });

  /// ブランドがあれば「ブランド 製品名」、なければ製品名のみ。
  String get displayName =>
      brand.trim().isEmpty ? name : '${brand.trim()} $name';

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'nameSearch': nameSearch,
        'brand': brand,
        'servingNote': servingNote,
        'calories': calories,
        'protein': protein,
        'fat': fat,
        'carbs': carbs,
        'sugar': sugar,
        'fiber': fiber,
        'sodium': sodium,
        'micronutrients': micronutrients.toMap(),
        'detailedNutrients': detailedNutrients.toMap(),
        'contributedBy': contributedBy,
        'createdAt': Timestamp.fromDate(createdAt),
        'useCount': useCount,
      };

  factory CommunitySupplementEntry.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return CommunitySupplementEntry(
      id: doc.id,
      name: d['name'] as String? ?? '',
      nameSearch: d['nameSearch'] as String? ?? '',
      brand: d['brand'] as String? ?? '',
      servingNote: d['servingNote'] as String? ?? '',
      calories: (d['calories'] as num?)?.toInt() ?? 0,
      protein: (d['protein'] as num?)?.toDouble() ?? 0,
      fat: (d['fat'] as num?)?.toDouble() ?? 0,
      carbs: (d['carbs'] as num?)?.toDouble() ?? 0,
      sugar: (d['sugar'] as num?)?.toDouble() ?? 0,
      fiber: (d['fiber'] as num?)?.toDouble() ?? 0,
      sodium: (d['sodium'] as num?)?.toDouble() ?? 0,
      micronutrients: d['micronutrients'] is Map
          ? Micronutrients.fromMap(
              Map<String, dynamic>.from(d['micronutrients'] as Map))
          : Micronutrients.zero,
      detailedNutrients: d['detailedNutrients'] is Map
          ? DetailedNutrients.fromMap(
              Map<String, dynamic>.from(d['detailedNutrients'] as Map))
          : DetailedNutrients.zero,
      contributedBy: d['contributedBy'] as String? ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      useCount: (d['useCount'] as num?)?.toInt() ?? 0,
    );
  }
}
