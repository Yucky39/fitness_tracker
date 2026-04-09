import 'package:cloud_firestore/cloud_firestore.dart';

class CommunityFoodEntry {
  final String id;
  final String name;
  final String nameSearch; // name.toLowerCase() — used for prefix queries
  final int calories;
  final double protein;
  final double fat;
  final double carbs;
  final double sugar;
  final double fiber;
  final double sodium;
  final String contributedBy; // userId only — no PII
  final DateTime createdAt;
  final int useCount;

  const CommunityFoodEntry({
    required this.id,
    required this.name,
    required this.nameSearch,
    required this.calories,
    required this.protein,
    required this.fat,
    required this.carbs,
    this.sugar = 0,
    this.fiber = 0,
    this.sodium = 0,
    required this.contributedBy,
    required this.createdAt,
    this.useCount = 0,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'nameSearch': nameSearch,
        'calories': calories,
        'protein': protein,
        'fat': fat,
        'carbs': carbs,
        'sugar': sugar,
        'fiber': fiber,
        'sodium': sodium,
        'contributedBy': contributedBy,
        'createdAt': Timestamp.fromDate(createdAt),
        'useCount': useCount,
      };

  factory CommunityFoodEntry.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return CommunityFoodEntry(
      id: doc.id,
      name: d['name'] as String? ?? '',
      nameSearch: d['nameSearch'] as String? ?? '',
      calories: (d['calories'] as num?)?.toInt() ?? 0,
      protein: (d['protein'] as num?)?.toDouble() ?? 0,
      fat: (d['fat'] as num?)?.toDouble() ?? 0,
      carbs: (d['carbs'] as num?)?.toDouble() ?? 0,
      sugar: (d['sugar'] as num?)?.toDouble() ?? 0,
      fiber: (d['fiber'] as num?)?.toDouble() ?? 0,
      sodium: (d['sodium'] as num?)?.toDouble() ?? 0,
      contributedBy: d['contributedBy'] as String? ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      useCount: (d['useCount'] as num?)?.toInt() ?? 0,
    );
  }
}
