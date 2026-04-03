class BodyMetrics {
  final String id;
  final double weight;
  final double waist;
  final double bodyFatPercentage;
  final String? imagePath;
  final DateTime date;

  BodyMetrics({
    required this.id,
    required this.weight,
    required this.waist,
    required this.bodyFatPercentage,
    this.imagePath,
    required this.date,
  });

  /// 除脂肪体重 (kg)
  double get leanBodyMass => weight * (1 - bodyFatPercentage / 100);

  /// 体脂肪量 (kg)
  double get fatMass => weight * bodyFatPercentage / 100;

  /// BMI（身長が必要なため外部から渡す）
  static double bmi(double weightKg, double heightCm) {
    if (heightCm <= 0) return 0;
    final h = heightCm / 100;
    return weightKg / (h * h);
  }

  static String bmiLabel(double bmiValue) {
    if (bmiValue <= 0) return '—';
    if (bmiValue < 18.5) return '低体重';
    if (bmiValue < 25.0) return '普通体重';
    if (bmiValue < 30.0) return '肥満(1度)';
    if (bmiValue < 35.0) return '肥満(2度)';
    return '肥満(3度以上)';
  }

  BodyMetrics copyWith({
    String? id,
    double? weight,
    double? waist,
    double? bodyFatPercentage,
    String? imagePath,
    bool clearImage = false,
    DateTime? date,
  }) =>
      BodyMetrics(
        id: id ?? this.id,
        weight: weight ?? this.weight,
        waist: waist ?? this.waist,
        bodyFatPercentage: bodyFatPercentage ?? this.bodyFatPercentage,
        imagePath: clearImage ? null : (imagePath ?? this.imagePath),
        date: date ?? this.date,
      );

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'weight': weight,
      'waist': waist,
      'bodyFatPercentage': bodyFatPercentage,
      'imagePath': imagePath,
      'date': date.toIso8601String(),
    };
  }

  factory BodyMetrics.fromMap(Map<String, dynamic> map) {
    return BodyMetrics(
      id: map['id'] as String,
      weight: (map['weight'] as num).toDouble(),
      waist: (map['waist'] as num).toDouble(),
      bodyFatPercentage: (map['bodyFatPercentage'] as num).toDouble(),
      imagePath: map['imagePath'] as String?,
      date: DateTime.parse(map['date'] as String),
    );
  }
}
