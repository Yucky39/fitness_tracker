/// 体型写真の撮影方向
enum PhotoDirection {
  front('front', '正面'),
  side('side', '側面'),
  back('back', '背面');

  const PhotoDirection(this.key, this.label);
  final String key;
  final String label;

  static PhotoDirection fromKey(String? key) => PhotoDirection.values.firstWhere(
        (d) => d.key == key,
        orElse: () => PhotoDirection.front,
      );
}

class BodyMetrics {
  final String id;
  final double weight;
  final double waist;
  final double bodyFatPercentage;

  /// 正面写真のローカルパス
  final String? imageFrontPath;

  /// 側面写真のローカルパス
  final String? imageSidePath;

  /// 背面写真のローカルパス
  final String? imageBackPath;

  final DateTime date;

  BodyMetrics({
    required this.id,
    required this.weight,
    required this.waist,
    required this.bodyFatPercentage,
    this.imageFrontPath,
    this.imageSidePath,
    this.imageBackPath,
    required this.date,
  });

  /// 向きに対応するパスを返す
  String? pathForDirection(PhotoDirection direction) {
    switch (direction) {
      case PhotoDirection.front:
        return imageFrontPath;
      case PhotoDirection.side:
        return imageSidePath;
      case PhotoDirection.back:
        return imageBackPath;
    }
  }

  /// いずれかの向きに写真があるか
  bool get hasAnyPhoto =>
      imageFrontPath != null || imageSidePath != null || imageBackPath != null;

  /// サムネイル表示用に最初に見つかったパスを返す（正面→側面→背面の優先順）
  String? get firstPhotoPath =>
      imageFrontPath ?? imageSidePath ?? imageBackPath;

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
    String? imageFrontPath,
    bool clearFront = false,
    String? imageSidePath,
    bool clearSide = false,
    String? imageBackPath,
    bool clearBack = false,
    DateTime? date,
  }) =>
      BodyMetrics(
        id: id ?? this.id,
        weight: weight ?? this.weight,
        waist: waist ?? this.waist,
        bodyFatPercentage: bodyFatPercentage ?? this.bodyFatPercentage,
        imageFrontPath:
            clearFront ? null : (imageFrontPath ?? this.imageFrontPath),
        imageSidePath:
            clearSide ? null : (imageSidePath ?? this.imageSidePath),
        imageBackPath:
            clearBack ? null : (imageBackPath ?? this.imageBackPath),
        date: date ?? this.date,
      );

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'weight': weight,
      'waist': waist,
      'bodyFatPercentage': bodyFatPercentage,
      'image_front_path': imageFrontPath,
      'image_side_path': imageSidePath,
      'image_back_path': imageBackPath,
      'date': date.toIso8601String(),
    };
  }

  factory BodyMetrics.fromMap(Map<String, dynamic> map) {
    // 旧スキーマの `imagePath` は正面写真として移行する
    final legacyPath = map['imagePath'] as String?;
    return BodyMetrics(
      id: map['id'] as String,
      weight: (map['weight'] as num).toDouble(),
      waist: (map['waist'] as num).toDouble(),
      bodyFatPercentage: (map['bodyFatPercentage'] as num).toDouble(),
      imageFrontPath:
          (map['image_front_path'] as String?) ?? legacyPath,
      imageSidePath: map['image_side_path'] as String?,
      imageBackPath: map['image_back_path'] as String?,
      date: DateTime.parse(map['date'] as String),
    );
  }
}
