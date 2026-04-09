class WaterLog {
  final String id;
  final int amountMl;
  final DateTime date;

  WaterLog({
    required this.id,
    required this.amountMl,
    required this.date,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'amount_ml': amountMl,
        'date': date.toIso8601String(),
      };

  factory WaterLog.fromMap(Map<String, dynamic> map) => WaterLog(
        id: map['id'] as String,
        amountMl: map['amount_ml'] as int,
        date: DateTime.parse(map['date'] as String),
      );
}
