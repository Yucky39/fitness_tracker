import 'dart:convert';

/// スティックフィギュアの13関節名。
const List<String> kStickFigureJoints = [
  'head',
  'l_shoulder', 'r_shoulder',
  'l_elbow', 'r_elbow',
  'l_hand', 'r_hand',
  'l_hip', 'r_hip',
  'l_knee', 'r_knee',
  'l_foot', 'r_foot',
];

/// アニメーションの1フレーム（姿勢スナップショット）。
class ExerciseAnimationKeyframe {
  /// 正規化された時刻（0.0 〜 1.0）。
  final double t;

  /// 関節名 → [x, y]（0.0〜1.0 正規化座標）。
  final Map<String, List<double>> joints;

  const ExerciseAnimationKeyframe({required this.t, required this.joints});

  factory ExerciseAnimationKeyframe.fromMap(Map<String, dynamic> map) {
    // AIが joints キーの中に入れる形式と、フラット形式の両方に対応。
    final source = map.containsKey('joints') && map['joints'] is Map
        ? map['joints'] as Map<String, dynamic>
        : map;

    final joints = <String, List<double>>{};
    for (final key in kStickFigureJoints) {
      final raw = source[key];
      if (raw is List && raw.length >= 2) {
        joints[key] = [
          (raw[0] as num).toDouble(),
          (raw[1] as num).toDouble(),
          raw.length > 2 ? (raw[2] as num).toDouble() : 0.0, // z (3D depth)
        ];
      }
    }
    return ExerciseAnimationKeyframe(
      t: (map['t'] as num).toDouble(),
      joints: joints,
    );
  }

  Map<String, dynamic> toMap() => {
        't': t,
        for (final e in joints.entries) e.key: e.value,
      };
}

/// 1種目分のアニメーション記述子。DB にキャッシュされる。
class ExerciseAnimationData {
  /// 正規化された種目キー（DBのプライマリキー）。
  final String exerciseKey;

  /// アニメーション1ループの長さ（ミリ秒）。
  final int durationMs;

  /// キーフレーム列（t 昇順でソート済み）。
  final List<ExerciseAnimationKeyframe> keyframes;

  const ExerciseAnimationData({
    required this.exerciseKey,
    required this.durationMs,
    required this.keyframes,
  });

  factory ExerciseAnimationData.fromDbRow(Map<String, dynamic> row) {
    return ExerciseAnimationData.fromJson(
      row['exercise_key'] as String,
      row['animation_json'] as String,
    );
  }

  factory ExerciseAnimationData.fromJson(String exerciseKey, String json) {
    final map = jsonDecode(json) as Map<String, dynamic>;
    final frames = (map['keyframes'] as List)
        .map((k) =>
            ExerciseAnimationKeyframe.fromMap(k as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.t.compareTo(b.t));
    return ExerciseAnimationData(
      exerciseKey: exerciseKey,
      durationMs: (map['duration_ms'] as num?)?.toInt() ?? 2000,
      keyframes: frames,
    );
  }

  String toJson() => jsonEncode({
        'duration_ms': durationMs,
        'keyframes': keyframes.map((k) => k.toMap()).toList(),
      });

  /// [progress]（0.0〜1.0）に対応した関節座標を線形補間して返す。
  Map<String, List<double>> interpolate(double progress) {
    if (keyframes.isEmpty) return {};
    if (keyframes.length == 1) return keyframes.first.joints;

    final t = progress.clamp(0.0, 1.0);

    ExerciseAnimationKeyframe prev = keyframes.last;
    ExerciseAnimationKeyframe next = keyframes.first;

    for (int i = 0; i < keyframes.length - 1; i++) {
      if (t >= keyframes[i].t && t <= keyframes[i + 1].t) {
        prev = keyframes[i];
        next = keyframes[i + 1];
        break;
      }
    }

    final span = next.t - prev.t;
    final local = span == 0 ? 0.0 : ((t - prev.t) / span).clamp(0.0, 1.0);

    final result = <String, List<double>>{};
    for (final key in kStickFigureJoints) {
      final a = prev.joints[key];
      final b = next.joints[key];
      if (a != null && b != null) {
        final az = a.length > 2 ? a[2] : 0.0;
        final bz = b.length > 2 ? b[2] : 0.0;
        result[key] = [
          a[0] + (b[0] - a[0]) * local,
          a[1] + (b[1] - a[1]) * local,
          az + (bz - az) * local, // z (3D depth)
        ];
      }
    }
    return result;
  }
}
