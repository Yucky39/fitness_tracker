class TrainingLog {
  final String id;
  final String exerciseName;
  final double weight;
  final int reps;
  final int sets;
  final int interval;
  final String note;
  final DateTime date;

  TrainingLog({
    required this.id,
    required this.exerciseName,
    required this.weight,
    required this.reps,
    required this.sets,
    required this.interval,
    required this.note,
    required this.date,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'exerciseName': exerciseName,
      'weight': weight,
      'reps': reps,
      'sets': sets,
      'interval': interval,
      'note': note,
      'date': date.toIso8601String(),
    };
  }

  factory TrainingLog.fromMap(Map<String, dynamic> map) {
    return TrainingLog(
      id: map['id'],
      exerciseName: map['exerciseName'],
      weight: map['weight'],
      reps: map['reps'],
      sets: map['sets'],
      interval: map['interval'],
      note: map['note'],
      date: DateTime.parse(map['date']),
    );
  }
}
