class TrainingRoutine {
  final String id;
  final String name;
  final List<int> weekdays; // 1=Mon, 2=Tue, ..., 7=Sun (DateTime.weekday)
  final String note;

  TrainingRoutine({
    required this.id,
    required this.name,
    required this.weekdays,
    required this.note,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'weekdays': weekdays.join(','),
        'note': note,
      };

  factory TrainingRoutine.fromMap(Map<String, dynamic> map) => TrainingRoutine(
        id: map['id'],
        name: map['name'],
        weekdays: (map['weekdays'] as String).isEmpty
            ? []
            : (map['weekdays'] as String).split(',').map(int.parse).toList(),
        note: map['note'] ?? '',
      );

  static const weekdayNames = ['月', '火', '水', '木', '金', '土', '日'];

  String get weekdayLabel => weekdays.isEmpty
      ? 'なし'
      : weekdays.map((d) => weekdayNames[d - 1]).join('・');

  TrainingRoutine copyWith({
    String? id,
    String? name,
    List<int>? weekdays,
    String? note,
  }) =>
      TrainingRoutine(
        id: id ?? this.id,
        name: name ?? this.name,
        weekdays: weekdays ?? this.weekdays,
        note: note ?? this.note,
      );
}
