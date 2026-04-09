class SleepLog {
  final String id;
  final DateTime date;
  final int durationMinutes;
  final String source;

  SleepLog({
    required this.id,
    required this.date,
    required this.durationMinutes,
    this.source = 'health',
  });

  double get durationHours => durationMinutes / 60.0;

  Map<String, dynamic> toMap() => {
        'id': id,
        'date': date.toIso8601String(),
        'duration_m': durationMinutes,
        'source': source,
      };

  factory SleepLog.fromMap(Map<String, dynamic> map) => SleepLog(
        id: map['id'] as String,
        date: DateTime.parse(map['date'] as String),
        durationMinutes: map['duration_m'] as int,
        source: map['source'] as String? ?? 'health',
      );
}
