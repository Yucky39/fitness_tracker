class Achievement {
  final String badgeKey;
  final DateTime? unlockedAt;
  final int progress;

  const Achievement({
    required this.badgeKey,
    this.unlockedAt,
    this.progress = 0,
  });

  bool get isUnlocked => unlockedAt != null;

  Map<String, dynamic> toMap() => {
        'id': badgeKey,
        'badge_key': badgeKey,
        'unlocked_at': unlockedAt?.toIso8601String(),
        'progress': progress,
      };

  factory Achievement.fromMap(Map<String, dynamic> map) => Achievement(
        badgeKey: map['badge_key'] as String,
        unlockedAt: map['unlocked_at'] != null
            ? DateTime.parse(map['unlocked_at'] as String)
            : null,
        progress: map['progress'] as int? ?? 0,
      );

  Achievement copyWith({DateTime? unlockedAt, int? progress}) => Achievement(
        badgeKey: badgeKey,
        unlockedAt: unlockedAt ?? this.unlockedAt,
        progress: progress ?? this.progress,
      );
}
