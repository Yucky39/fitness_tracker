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
      id: map['id'],
      weight: map['weight'],
      waist: map['waist'],
      bodyFatPercentage: map['bodyFatPercentage'],
      imagePath: map['imagePath'],
      date: DateTime.parse(map['date']),
    );
  }
}
