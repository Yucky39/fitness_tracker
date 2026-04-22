import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/exercise_animation.dart';
import '../models/training_log.dart';
import '../providers/settings_provider.dart';
import 'database_service.dart';

/// 種目ごとのスティックフィギュアアニメーションを
/// AI で生成しDB にキャッシュするサービス。
class ExerciseAnimationService {
  static const _maxTokens = 4096;

  // ── キャッシュキー ─────────────────────────────────────────────────────────

  static String normalizeKey(String exerciseName) =>
      exerciseName.toLowerCase().replaceAll(RegExp(r'[\s\u3000]+'), '_').trim();

  // ── DB アクセス ────────────────────────────────────────────────────────────

  Future<ExerciseAnimationData?> _fetchFromDb(String key) async {
    final db = await DatabaseService().database;
    final rows = await db.query(
      'exercise_animations',
      where: 'exercise_key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    try {
      return ExerciseAnimationData.fromDbRow(rows.first);
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveToDb(ExerciseAnimationData data) async {
    final db = await DatabaseService().database;
    await db.delete(
      'exercise_animations',
      where: 'exercise_key = ?',
      whereArgs: [data.exerciseKey],
    );
    await db.insert('exercise_animations', {
      'exercise_key': data.exerciseKey,
      'animation_json': data.toJson(),
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  // ── 公開 API ───────────────────────────────────────────────────────────────

  /// キャッシュがあれば返し、なければ AI で生成してキャッシュする。
  /// API キーが空の場合は `null` を返す（呼び出し元がフォールバック表示）。
  Future<ExerciseAnimationData?> getAnimation({
    required String exerciseName,
    required ExerciseType exerciseType,
    required String apiKey,
    required AiProviderType provider,
    String? model,
  }) async {
    if (apiKey.isEmpty) return null;

    final key = normalizeKey(exerciseName);

    // キャッシュ確認
    final cached = await _fetchFromDb(key);
    if (cached != null && cached.keyframes.isNotEmpty) return cached;

    // AI 生成
    final generated = await _generateAnimation(
      exerciseName: exerciseName,
      exerciseType: exerciseType,
      apiKey: apiKey,
      provider: provider,
      model: model ?? provider.defaultModel,
      cacheKey: key,
    );
    if (generated != null) await _saveToDb(generated);
    return generated;
  }

  // ── AI 生成 ────────────────────────────────────────────────────────────────

  static const _systemPrompt = '''
あなたはフィットネスアニメーション専門家です。
指定されたトレーニング種目の実際の動作を表す棒人間（スティックフィギュア）アニメーションのキーフレームを生成してください。

## 座標系
- キャンバスは 1.0×1.0 の正方形（左上が [0,0]、右下が [1,1]）
- x: 0.0=左端, 0.5=中心, 1.0=右端
- y: 0.0=上端, 1.0=下端
- 「左」「右」は人物視点（画面の左が人物の左）

## 関節（13個）
head, l_shoulder, r_shoulder, l_elbow, r_elbow, l_hand, r_hand, l_hip, r_hip, l_knee, r_knee, l_foot, r_foot

## 直立姿勢の参考座標
"head":[0.50,0.09], "l_shoulder":[0.38,0.22], "r_shoulder":[0.62,0.22],
"l_elbow":[0.34,0.37], "r_elbow":[0.66,0.37],
"l_hand":[0.35,0.51], "r_hand":[0.65,0.51],
"l_hip":[0.44,0.55], "r_hip":[0.56,0.55],
"l_knee":[0.43,0.73], "r_knee":[0.57,0.73],
"l_foot":[0.41,0.92], "r_foot":[0.59,0.92]

## 出力形式（重要）
- **JSONのみを返す。マークダウン・コードブロック・説明文・改行・インデント一切不要**
- 必ず1行のコンパクトJSON形式で出力する
- 例: {"duration_ms":2000,"keyframes":[{"t":0.0,"head":[0.50,0.09],...},{"t":0.5,...},{"t":1.0,...}]}

## 要件
- キーフレームは必ず3〜4個（t=0.0 〜 t=1.0）
- t=1.0 のフレームは t=0.0 と同じ姿勢（自然にループ）
- 各フレームで全13関節を必ず出力
- 種目の実際の動き（スクワット=上下動、ベンチプレス=腕の押し出し、ランニング=脚の交互動作など）を正確に表現
- 解剖学的に正確な関節の動き（肘>手、膝>足の順）
- 筋トレ種目は足を地面（y≈0.92）に固定
- 手の座標は常に指定された動作に合わせる（胸の前で組む・バーを持つ・腕を伸ばす等）
''';

  Future<ExerciseAnimationData?> _generateAnimation({
    required String exerciseName,
    required ExerciseType exerciseType,
    required String apiKey,
    required AiProviderType provider,
    required String model,
    required String cacheKey,
  }) async {
    final userMsg =
        '種目: $exerciseName（${exerciseType.label}）\nこの種目の動作キーフレームJSONを生成してください。';

    try {
      final raw = switch (provider) {
        AiProviderType.anthropic =>
          await _callAnthropic(apiKey, model, userMsg),
        AiProviderType.openai => await _callOpenAi(apiKey, model, userMsg),
        AiProviderType.gemini => await _callGemini(apiKey, model, userMsg),
      };

      debugPrint('[ExerciseAnim] raw response (${raw.length} chars): '
          '${raw.substring(0, raw.length.clamp(0, 300))}');

      final jsonStr = _extractJson(raw);
      debugPrint('[ExerciseAnim] extracted JSON: '
          '${jsonStr.substring(0, jsonStr.length.clamp(0, 300))}');

      return ExerciseAnimationData.fromJson(cacheKey, jsonStr);
    } catch (e, st) {
      debugPrint('[ExerciseAnim] generation failed: $e\n$st');
      // フォールバック：ハードコードアニメーション
      return _fallbackAnimation(cacheKey, exerciseName);
    }
  }

  /// AI生成に失敗した場合のフォールバックアニメーション。
  /// 種目名にキーワードが含まれれば専用ポーズを返し、
  /// それ以外は汎用の直立→軽い屈伸ループを返す。
  static ExerciseAnimationData? _fallbackAnimation(
      String key, String exerciseName) {
    final n = exerciseName.toLowerCase();

    // スクワット系：膝を曲げて上下動
    if (n.contains('スクワット') || n.contains('squat')) {
      return ExerciseAnimationData(
        exerciseKey: key,
        durationMs: 2000,
        keyframes: [
          ExerciseAnimationKeyframe(t: 0.0, joints: _standingJoints()),
          ExerciseAnimationKeyframe(t: 0.5, joints: _squatJoints()),
          ExerciseAnimationKeyframe(t: 1.0, joints: _standingJoints()),
        ],
      );
    }

    // ベンチプレス / プレス系：腕を押し出す
    if (n.contains('ベンチ') || n.contains('bench') || n.contains('プレス') || n.contains('press')) {
      return ExerciseAnimationData(
        exerciseKey: key,
        durationMs: 2000,
        keyframes: [
          ExerciseAnimationKeyframe(t: 0.0, joints: _pressBottomJoints()),
          ExerciseAnimationKeyframe(t: 0.5, joints: _pressTopJoints()),
          ExerciseAnimationKeyframe(t: 1.0, joints: _pressBottomJoints()),
        ],
      );
    }

    // デッドリフト系：前傾→直立
    if (n.contains('デッドリフト') || n.contains('deadlift') || n.contains('rdl')) {
      return ExerciseAnimationData(
        exerciseKey: key,
        durationMs: 2200,
        keyframes: [
          ExerciseAnimationKeyframe(t: 0.0, joints: _deadliftBottomJoints()),
          ExerciseAnimationKeyframe(t: 0.5, joints: _standingJoints()),
          ExerciseAnimationKeyframe(t: 1.0, joints: _deadliftBottomJoints()),
        ],
      );
    }

    // カール系：肘を曲げる
    if (n.contains('カール') || n.contains('curl')) {
      return ExerciseAnimationData(
        exerciseKey: key,
        durationMs: 1800,
        keyframes: [
          ExerciseAnimationKeyframe(t: 0.0, joints: _curlBottomJoints()),
          ExerciseAnimationKeyframe(t: 0.5, joints: _curlTopJoints()),
          ExerciseAnimationKeyframe(t: 1.0, joints: _curlBottomJoints()),
        ],
      );
    }

    // ラットプルダウン / 懸垂系：腕を引き下ろす
    if (n.contains('ラットプル') || n.contains('lat pull') || n.contains('懸垂') || n.contains('チンアップ')) {
      return ExerciseAnimationData(
        exerciseKey: key,
        durationMs: 2000,
        keyframes: [
          ExerciseAnimationKeyframe(t: 0.0, joints: _pullUpTopJoints()),
          ExerciseAnimationKeyframe(t: 0.5, joints: _pullUpBottomJoints()),
          ExerciseAnimationKeyframe(t: 1.0, joints: _pullUpTopJoints()),
        ],
      );
    }

    // ショルダープレス系：腕を頭上に上げる
    if (n.contains('ショルダー') || n.contains('shoulder') || n.contains('オーバーヘッド') || n.contains('overhead')) {
      return ExerciseAnimationData(
        exerciseKey: key,
        durationMs: 2000,
        keyframes: [
          ExerciseAnimationKeyframe(t: 0.0, joints: _ohpBottomJoints()),
          ExerciseAnimationKeyframe(t: 0.5, joints: _ohpTopJoints()),
          ExerciseAnimationKeyframe(t: 1.0, joints: _ohpBottomJoints()),
        ],
      );
    }

    // ランジ系：片足前出し上下動（スクワットとは別に定義）
    if (n.contains('ランジ') || n.contains('lunge') || n.contains('ブルガリアン')) {
      return ExerciseAnimationData(
        exerciseKey: key,
        durationMs: 2000,
        keyframes: [
          ExerciseAnimationKeyframe(t: 0.0, joints: _lungeTopJoints()),
          ExerciseAnimationKeyframe(t: 0.5, joints: _lungeBottomJoints()),
          ExerciseAnimationKeyframe(t: 1.0, joints: _lungeTopJoints()),
        ],
      );
    }

    // ランニング / カーディオ系：脚を交互に動かす
    if (n.contains('ランニング') || n.contains('running') || n.contains('ジョグ') || n.contains('トレッドミル')) {
      return ExerciseAnimationData(
        exerciseKey: key,
        durationMs: 800,
        keyframes: [
          ExerciseAnimationKeyframe(t: 0.0, joints: _runPhase0()),
          ExerciseAnimationKeyframe(t: 0.5, joints: _runPhase1()),
          ExerciseAnimationKeyframe(t: 1.0, joints: _runPhase0()),
        ],
      );
    }

    // ヒップリフト / グルートブリッジ / ヒップスラスト（仰向け・横向き表示）
    if (n.contains('ヒップリフト') || n.contains('ヒップスラスト') ||
        n.contains('グルートブリッジ') || n.contains('hip thrust') ||
        n.contains('hip lift') || n.contains('glute bridge') ||
        n.contains('ブリッジ')) {
      return ExerciseAnimationData(
        exerciseKey: key,
        durationMs: 2000,
        keyframes: [
          ExerciseAnimationKeyframe(t: 0.0, joints: _hipLiftBottomJoints()),
          ExerciseAnimationKeyframe(t: 0.5, joints: _hipLiftTopJoints()),
          ExerciseAnimationKeyframe(t: 1.0, joints: _hipLiftBottomJoints()),
        ],
      );
    }

    // マウンテンクライマー（プランク姿勢で膝を交互に引く）
    if (n.contains('マウンテン') || n.contains('mountain') ||
        n.contains('クライマー') || n.contains('climber')) {
      return ExerciseAnimationData(
        exerciseKey: key,
        durationMs: 900,
        keyframes: [
          ExerciseAnimationKeyframe(t: 0.0, joints: _mountainClimberPhase0()),
          ExerciseAnimationKeyframe(t: 0.5, joints: _mountainClimberPhase1()),
          ExerciseAnimationKeyframe(t: 1.0, joints: _mountainClimberPhase0()),
        ],
      );
    }

    // プランク（体幹安定・微小な呼吸動作）
    if (n.contains('プランク') || n.contains('plank')) {
      return ExerciseAnimationData(
        exerciseKey: key,
        durationMs: 2400,
        keyframes: [
          ExerciseAnimationKeyframe(t: 0.0, joints: _plankJoints(inhale: false)),
          ExerciseAnimationKeyframe(t: 0.5, joints: _plankJoints(inhale: true)),
          ExerciseAnimationKeyframe(t: 1.0, joints: _plankJoints(inhale: false)),
        ],
      );
    }

    // プッシュアップ / 腕立て伏せ（プランク姿勢から腕を曲げ伸ばし）
    if (n.contains('プッシュアップ') || n.contains('push') ||
        n.contains('腕立て') || n.contains('プッシュ')) {
      return ExerciseAnimationData(
        exerciseKey: key,
        durationMs: 1800,
        keyframes: [
          ExerciseAnimationKeyframe(t: 0.0, joints: _pushUpTopJoints()),
          ExerciseAnimationKeyframe(t: 0.5, joints: _pushUpBottomJoints()),
          ExerciseAnimationKeyframe(t: 1.0, joints: _pushUpTopJoints()),
        ],
      );
    }

    // ベントオーバーロウ / ロウイング系（前傾して腕を引く）
    if (n.contains('ロウ') || n.contains('row') || n.contains('ベントオーバー') ||
        n.contains('bent over') || n.contains('ローイング')) {
      return ExerciseAnimationData(
        exerciseKey: key,
        durationMs: 2000,
        keyframes: [
          ExerciseAnimationKeyframe(t: 0.0, joints: _bentRowBottomJoints()),
          ExerciseAnimationKeyframe(t: 0.5, joints: _bentRowTopJoints()),
          ExerciseAnimationKeyframe(t: 1.0, joints: _bentRowBottomJoints()),
        ],
      );
    }

    // ラテラルレイズ / サイドレイズ（腕を横に上げる）
    if (n.contains('ラテラル') || n.contains('lateral') ||
        n.contains('サイドレイズ') || n.contains('リアデルト') ||
        n.contains('フライ') || n.contains('fly')) {
      return ExerciseAnimationData(
        exerciseKey: key,
        durationMs: 2000,
        keyframes: [
          ExerciseAnimationKeyframe(t: 0.0, joints: _lateralRaiseBottomJoints()),
          ExerciseAnimationKeyframe(t: 0.5, joints: _lateralRaiseTopJoints()),
          ExerciseAnimationKeyframe(t: 1.0, joints: _lateralRaiseBottomJoints()),
        ],
      );
    }

    // カーフレイズ（つま先立ち）
    if (n.contains('カーフ') || n.contains('calf') || n.contains('つま先')) {
      return ExerciseAnimationData(
        exerciseKey: key,
        durationMs: 1600,
        keyframes: [
          ExerciseAnimationKeyframe(t: 0.0, joints: _standingJoints()),
          ExerciseAnimationKeyframe(t: 0.5, joints: _calfRaiseTopJoints()),
          ExerciseAnimationKeyframe(t: 1.0, joints: _standingJoints()),
        ],
      );
    }

    // クランチ / 腹筋（上体起こし）
    if (n.contains('クランチ') || n.contains('crunch') ||
        n.contains('腹筋') || n.contains('シットアップ') || n.contains('sit up')) {
      return ExerciseAnimationData(
        exerciseKey: key,
        durationMs: 2000,
        keyframes: [
          ExerciseAnimationKeyframe(t: 0.0, joints: _crunchBottomJoints()),
          ExerciseAnimationKeyframe(t: 0.5, joints: _crunchTopJoints()),
          ExerciseAnimationKeyframe(t: 1.0, joints: _crunchBottomJoints()),
        ],
      );
    }

    // 汎用フォールバック：軽い屈伸ループ
    return ExerciseAnimationData(
      exerciseKey: key,
      durationMs: 2000,
      keyframes: [
        ExerciseAnimationKeyframe(t: 0.0, joints: _standingJoints()),
        ExerciseAnimationKeyframe(t: 0.5, joints: _gentleBendJoints()),
        ExerciseAnimationKeyframe(t: 1.0, joints: _standingJoints()),
      ],
    );
  }

  // ── 静的ポーズ定義 ────────────────────────────────────────────────────────

  static Map<String, List<double>> _standingJoints() => {
        'head': [0.50, 0.09],
        'l_shoulder': [0.38, 0.22], 'r_shoulder': [0.62, 0.22],
        'l_elbow': [0.34, 0.37], 'r_elbow': [0.66, 0.37],
        'l_hand': [0.35, 0.51], 'r_hand': [0.65, 0.51],
        'l_hip': [0.44, 0.55], 'r_hip': [0.56, 0.55],
        'l_knee': [0.43, 0.73], 'r_knee': [0.57, 0.73],
        'l_foot': [0.41, 0.92], 'r_foot': [0.59, 0.92],
      };

  static Map<String, List<double>> _squatJoints() => {
        'head': [0.50, 0.30],
        'l_shoulder': [0.38, 0.42], 'r_shoulder': [0.62, 0.42],
        'l_elbow': [0.34, 0.52], 'r_elbow': [0.66, 0.52],
        'l_hand': [0.42, 0.52], 'r_hand': [0.58, 0.52],
        'l_hip': [0.42, 0.62], 'r_hip': [0.58, 0.62],
        'l_knee': [0.36, 0.78], 'r_knee': [0.64, 0.78],
        'l_foot': [0.33, 0.92], 'r_foot': [0.67, 0.92],
      };

  static Map<String, List<double>> _gentleBendJoints() => {
        'head': [0.50, 0.13],
        'l_shoulder': [0.38, 0.26], 'r_shoulder': [0.62, 0.26],
        'l_elbow': [0.34, 0.40], 'r_elbow': [0.66, 0.40],
        'l_hand': [0.35, 0.54], 'r_hand': [0.65, 0.54],
        'l_hip': [0.44, 0.58], 'r_hip': [0.56, 0.58],
        'l_knee': [0.42, 0.76], 'r_knee': [0.58, 0.76],
        'l_foot': [0.41, 0.92], 'r_foot': [0.59, 0.92],
      };

  static Map<String, List<double>> _pressBottomJoints() => {
        'head': [0.50, 0.09],
        'l_shoulder': [0.38, 0.22], 'r_shoulder': [0.62, 0.22],
        'l_elbow': [0.28, 0.30], 'r_elbow': [0.72, 0.30],
        'l_hand': [0.30, 0.25], 'r_hand': [0.70, 0.25],
        'l_hip': [0.44, 0.55], 'r_hip': [0.56, 0.55],
        'l_knee': [0.43, 0.73], 'r_knee': [0.57, 0.73],
        'l_foot': [0.41, 0.92], 'r_foot': [0.59, 0.92],
      };

  static Map<String, List<double>> _pressTopJoints() => {
        'head': [0.50, 0.09],
        'l_shoulder': [0.38, 0.22], 'r_shoulder': [0.62, 0.22],
        'l_elbow': [0.32, 0.28], 'r_elbow': [0.68, 0.28],
        'l_hand': [0.40, 0.22], 'r_hand': [0.60, 0.22],
        'l_hip': [0.44, 0.55], 'r_hip': [0.56, 0.55],
        'l_knee': [0.43, 0.73], 'r_knee': [0.57, 0.73],
        'l_foot': [0.41, 0.92], 'r_foot': [0.59, 0.92],
      };

  static Map<String, List<double>> _deadliftBottomJoints() => {
        'head': [0.42, 0.28],
        'l_shoulder': [0.32, 0.38], 'r_shoulder': [0.56, 0.35],
        'l_elbow': [0.30, 0.52], 'r_elbow': [0.60, 0.50],
        'l_hand': [0.38, 0.65], 'r_hand': [0.62, 0.65],
        'l_hip': [0.41, 0.52], 'r_hip': [0.55, 0.52],
        'l_knee': [0.40, 0.72], 'r_knee': [0.58, 0.72],
        'l_foot': [0.38, 0.92], 'r_foot': [0.62, 0.92],
      };

  static Map<String, List<double>> _curlBottomJoints() => {
        'head': [0.50, 0.09],
        'l_shoulder': [0.38, 0.22], 'r_shoulder': [0.62, 0.22],
        'l_elbow': [0.36, 0.38], 'r_elbow': [0.64, 0.38],
        'l_hand': [0.35, 0.55], 'r_hand': [0.65, 0.55],
        'l_hip': [0.44, 0.55], 'r_hip': [0.56, 0.55],
        'l_knee': [0.43, 0.73], 'r_knee': [0.57, 0.73],
        'l_foot': [0.41, 0.92], 'r_foot': [0.59, 0.92],
      };

  static Map<String, List<double>> _curlTopJoints() => {
        'head': [0.50, 0.09],
        'l_shoulder': [0.38, 0.22], 'r_shoulder': [0.62, 0.22],
        'l_elbow': [0.36, 0.38], 'r_elbow': [0.64, 0.38],
        'l_hand': [0.36, 0.26], 'r_hand': [0.64, 0.26],
        'l_hip': [0.44, 0.55], 'r_hip': [0.56, 0.55],
        'l_knee': [0.43, 0.73], 'r_knee': [0.57, 0.73],
        'l_foot': [0.41, 0.92], 'r_foot': [0.59, 0.92],
      };

  static Map<String, List<double>> _pullUpTopJoints() => {
        'head': [0.50, 0.09],
        'l_shoulder': [0.38, 0.22], 'r_shoulder': [0.62, 0.22],
        'l_elbow': [0.32, 0.08], 'r_elbow': [0.68, 0.08],
        'l_hand': [0.30, 0.02], 'r_hand': [0.70, 0.02],
        'l_hip': [0.44, 0.55], 'r_hip': [0.56, 0.55],
        'l_knee': [0.43, 0.73], 'r_knee': [0.57, 0.73],
        'l_foot': [0.41, 0.92], 'r_foot': [0.59, 0.92],
      };

  static Map<String, List<double>> _pullUpBottomJoints() => {
        'head': [0.50, 0.16],
        'l_shoulder': [0.38, 0.28], 'r_shoulder': [0.62, 0.28],
        'l_elbow': [0.30, 0.20], 'r_elbow': [0.70, 0.20],
        'l_hand': [0.30, 0.10], 'r_hand': [0.70, 0.10],
        'l_hip': [0.44, 0.60], 'r_hip': [0.56, 0.60],
        'l_knee': [0.43, 0.78], 'r_knee': [0.57, 0.78],
        'l_foot': [0.41, 0.95], 'r_foot': [0.59, 0.95],
      };

  static Map<String, List<double>> _ohpBottomJoints() => {
        'head': [0.50, 0.09],
        'l_shoulder': [0.38, 0.22], 'r_shoulder': [0.62, 0.22],
        'l_elbow': [0.28, 0.28], 'r_elbow': [0.72, 0.28],
        'l_hand': [0.30, 0.22], 'r_hand': [0.70, 0.22],
        'l_hip': [0.44, 0.55], 'r_hip': [0.56, 0.55],
        'l_knee': [0.43, 0.73], 'r_knee': [0.57, 0.73],
        'l_foot': [0.41, 0.92], 'r_foot': [0.59, 0.92],
      };

  static Map<String, List<double>> _ohpTopJoints() => {
        'head': [0.50, 0.14],
        'l_shoulder': [0.38, 0.24], 'r_shoulder': [0.62, 0.24],
        'l_elbow': [0.34, 0.12], 'r_elbow': [0.66, 0.12],
        'l_hand': [0.38, 0.02], 'r_hand': [0.62, 0.02],
        'l_hip': [0.44, 0.55], 'r_hip': [0.56, 0.55],
        'l_knee': [0.43, 0.73], 'r_knee': [0.57, 0.73],
        'l_foot': [0.41, 0.92], 'r_foot': [0.59, 0.92],
      };

  static Map<String, List<double>> _runPhase0() => {
        'head': [0.50, 0.09],
        'l_shoulder': [0.38, 0.22], 'r_shoulder': [0.62, 0.22],
        'l_elbow': [0.30, 0.32], 'r_elbow': [0.68, 0.30],
        'l_hand': [0.32, 0.45], 'r_hand': [0.66, 0.18],
        'l_hip': [0.44, 0.55], 'r_hip': [0.56, 0.55],
        'l_knee': [0.38, 0.65], 'r_knee': [0.60, 0.78],
        'l_foot': [0.36, 0.78], 'r_foot': [0.62, 0.92],
      };

  static Map<String, List<double>> _runPhase1() => {
        'head': [0.50, 0.09],
        'l_shoulder': [0.38, 0.22], 'r_shoulder': [0.62, 0.22],
        'l_elbow': [0.32, 0.30], 'r_elbow': [0.70, 0.32],
        'l_hand': [0.34, 0.18], 'r_hand': [0.68, 0.45],
        'l_hip': [0.44, 0.55], 'r_hip': [0.56, 0.55],
        'l_knee': [0.40, 0.78], 'r_knee': [0.62, 0.65],
        'l_foot': [0.38, 0.92], 'r_foot': [0.60, 0.78],
      };

  // ── ランジ ────────────────────────────────────────────────────────────────

  static Map<String, List<double>> _lungeTopJoints() => {
        'head': [0.50, 0.10],
        'l_shoulder': [0.40, 0.23], 'r_shoulder': [0.60, 0.23],
        'l_elbow': [0.36, 0.38], 'r_elbow': [0.64, 0.38],
        'l_hand': [0.37, 0.52], 'r_hand': [0.63, 0.52],
        'l_hip': [0.46, 0.55], 'r_hip': [0.54, 0.55],
        'l_knee': [0.40, 0.72], 'r_knee': [0.60, 0.72],
        'l_foot': [0.34, 0.92], 'r_foot': [0.66, 0.92],
      };

  static Map<String, List<double>> _lungeBottomJoints() => {
        'head': [0.42, 0.18],
        'l_shoulder': [0.34, 0.30], 'r_shoulder': [0.56, 0.30],
        'l_elbow': [0.30, 0.44], 'r_elbow': [0.60, 0.44],
        'l_hand': [0.31, 0.58], 'r_hand': [0.61, 0.58],
        'l_hip': [0.38, 0.52], 'r_hip': [0.54, 0.52],
        'l_knee': [0.28, 0.72], 'r_knee': [0.60, 0.65],
        'l_foot': [0.20, 0.92], 'r_foot': [0.66, 0.82],
      };

  // ── ヒップリフト（仰向け・横向き表示） ──────────────────────────────────────

  /// 仰向けに寝た姿勢。画面上で体が横向きになるよう配置。
  /// head=右端、feet=左端で、ヒップが上下に動く。
  static Map<String, List<double>> _hipLiftBottomJoints() => {
        'head': [0.85, 0.52],
        'l_shoulder': [0.72, 0.46], 'r_shoulder': [0.72, 0.58],
        'l_elbow': [0.60, 0.44], 'r_elbow': [0.60, 0.60],
        'l_hand': [0.48, 0.44], 'r_hand': [0.48, 0.62],
        'l_hip': [0.46, 0.47], 'r_hip': [0.46, 0.57],
        'l_knee': [0.32, 0.40], 'r_knee': [0.32, 0.64],
        'l_foot': [0.18, 0.50], 'r_foot': [0.18, 0.58],
      };

  static Map<String, List<double>> _hipLiftTopJoints() => {
        'head': [0.85, 0.54],
        'l_shoulder': [0.72, 0.48], 'r_shoulder': [0.72, 0.60],
        'l_elbow': [0.60, 0.46], 'r_elbow': [0.60, 0.62],
        'l_hand': [0.48, 0.46], 'r_hand': [0.48, 0.64],
        'l_hip': [0.44, 0.34], 'r_hip': [0.44, 0.44],   // ヒップ上昇
        'l_knee': [0.30, 0.38], 'r_knee': [0.30, 0.62],
        'l_foot': [0.18, 0.52], 'r_foot': [0.18, 0.60],
      };

  // ── マウンテンクライマー（プランク姿勢・横向き表示） ────────────────────────

  static Map<String, List<double>> _mountainClimberPhase0() => {
        'head': [0.80, 0.26],
        'l_shoulder': [0.66, 0.24], 'r_shoulder': [0.66, 0.34],
        'l_elbow': [0.52, 0.36], 'r_elbow': [0.52, 0.46],
        'l_hand': [0.40, 0.36], 'r_hand': [0.40, 0.46],
        'l_hip': [0.42, 0.20], 'r_hip': [0.42, 0.28],
        'l_knee': [0.54, 0.28], 'r_knee': [0.26, 0.40], // 左膝を引き込む
        'l_foot': [0.55, 0.24], 'r_foot': [0.12, 0.50],
      };

  static Map<String, List<double>> _mountainClimberPhase1() => {
        'head': [0.80, 0.26],
        'l_shoulder': [0.66, 0.24], 'r_shoulder': [0.66, 0.34],
        'l_elbow': [0.52, 0.36], 'r_elbow': [0.52, 0.46],
        'l_hand': [0.40, 0.36], 'r_hand': [0.40, 0.46],
        'l_hip': [0.42, 0.20], 'r_hip': [0.42, 0.28],
        'l_knee': [0.26, 0.36], 'r_knee': [0.54, 0.36], // 右膝を引き込む
        'l_foot': [0.12, 0.48], 'r_foot': [0.55, 0.32],
      };

  // ── プランク（体幹キープ・呼吸モーション） ─────────────────────────────────

  static Map<String, List<double>> _plankJoints({required bool inhale}) {
    final dy = inhale ? 0.01 : 0.0;
    return {
      'head': [0.80, 0.26 - dy],
      'l_shoulder': [0.66, 0.24 - dy], 'r_shoulder': [0.66, 0.34 - dy],
      'l_elbow': [0.52, 0.36], 'r_elbow': [0.52, 0.46],
      'l_hand': [0.40, 0.36], 'r_hand': [0.40, 0.46],
      'l_hip': [0.42, 0.20 - dy], 'r_hip': [0.42, 0.28 - dy],
      'l_knee': [0.26, 0.40], 'r_knee': [0.26, 0.50],
      'l_foot': [0.12, 0.48], 'r_foot': [0.12, 0.58],
    };
  }

  // ── プッシュアップ（腕立て伏せ） ──────────────────────────────────────────

  static Map<String, List<double>> _pushUpTopJoints() => {
        'head': [0.80, 0.24],
        'l_shoulder': [0.66, 0.22], 'r_shoulder': [0.66, 0.32],
        'l_elbow': [0.52, 0.28], 'r_elbow': [0.52, 0.38],
        'l_hand': [0.40, 0.34], 'r_hand': [0.40, 0.44],
        'l_hip': [0.40, 0.20], 'r_hip': [0.40, 0.28],
        'l_knee': [0.24, 0.38], 'r_knee': [0.24, 0.48],
        'l_foot': [0.10, 0.46], 'r_foot': [0.10, 0.56],
      };

  static Map<String, List<double>> _pushUpBottomJoints() => {
        'head': [0.80, 0.34],
        'l_shoulder': [0.66, 0.30], 'r_shoulder': [0.66, 0.40],
        'l_elbow': [0.56, 0.40], 'r_elbow': [0.56, 0.50],
        'l_hand': [0.40, 0.40], 'r_hand': [0.40, 0.50],
        'l_hip': [0.40, 0.22], 'r_hip': [0.40, 0.30],
        'l_knee': [0.24, 0.40], 'r_knee': [0.24, 0.50],
        'l_foot': [0.10, 0.48], 'r_foot': [0.10, 0.58],
      };

  // ── ベントオーバーロウ ────────────────────────────────────────────────────

  static Map<String, List<double>> _bentRowBottomJoints() => {
        'head': [0.42, 0.26],
        'l_shoulder': [0.32, 0.36], 'r_shoulder': [0.56, 0.34],
        'l_elbow': [0.34, 0.52], 'r_elbow': [0.58, 0.50],
        'l_hand': [0.36, 0.68], 'r_hand': [0.60, 0.66],
        'l_hip': [0.40, 0.50], 'r_hip': [0.54, 0.50],
        'l_knee': [0.40, 0.70], 'r_knee': [0.58, 0.70],
        'l_foot': [0.38, 0.92], 'r_foot': [0.62, 0.92],
      };

  static Map<String, List<double>> _bentRowTopJoints() => {
        'head': [0.42, 0.26],
        'l_shoulder': [0.32, 0.36], 'r_shoulder': [0.56, 0.34],
        'l_elbow': [0.26, 0.42], 'r_elbow': [0.52, 0.40],
        'l_hand': [0.36, 0.52], 'r_hand': [0.60, 0.50],
        'l_hip': [0.40, 0.50], 'r_hip': [0.54, 0.50],
        'l_knee': [0.40, 0.70], 'r_knee': [0.58, 0.70],
        'l_foot': [0.38, 0.92], 'r_foot': [0.62, 0.92],
      };

  // ── ラテラルレイズ ────────────────────────────────────────────────────────

  static Map<String, List<double>> _lateralRaiseBottomJoints() => {
        'head': [0.50, 0.09],
        'l_shoulder': [0.38, 0.22], 'r_shoulder': [0.62, 0.22],
        'l_elbow': [0.34, 0.36], 'r_elbow': [0.66, 0.36],
        'l_hand': [0.33, 0.50], 'r_hand': [0.67, 0.50],
        'l_hip': [0.44, 0.55], 'r_hip': [0.56, 0.55],
        'l_knee': [0.43, 0.73], 'r_knee': [0.57, 0.73],
        'l_foot': [0.41, 0.92], 'r_foot': [0.59, 0.92],
      };

  static Map<String, List<double>> _lateralRaiseTopJoints() => {
        'head': [0.50, 0.09],
        'l_shoulder': [0.38, 0.22], 'r_shoulder': [0.62, 0.22],
        'l_elbow': [0.22, 0.26], 'r_elbow': [0.78, 0.26],
        'l_hand': [0.16, 0.28], 'r_hand': [0.84, 0.28],
        'l_hip': [0.44, 0.55], 'r_hip': [0.56, 0.55],
        'l_knee': [0.43, 0.73], 'r_knee': [0.57, 0.73],
        'l_foot': [0.41, 0.92], 'r_foot': [0.59, 0.92],
      };

  // ── カーフレイズ ──────────────────────────────────────────────────────────

  static Map<String, List<double>> _calfRaiseTopJoints() => {
        'head': [0.50, 0.07],
        'l_shoulder': [0.38, 0.20], 'r_shoulder': [0.62, 0.20],
        'l_elbow': [0.34, 0.35], 'r_elbow': [0.66, 0.35],
        'l_hand': [0.35, 0.49], 'r_hand': [0.65, 0.49],
        'l_hip': [0.44, 0.53], 'r_hip': [0.56, 0.53],
        'l_knee': [0.43, 0.71], 'r_knee': [0.57, 0.71],
        'l_foot': [0.42, 0.86], 'r_foot': [0.58, 0.86],
      };

  // ── クランチ（仰向け・上体起こし） ──────────────────────────────────────────

  static Map<String, List<double>> _crunchBottomJoints() => {
        'head': [0.84, 0.55],
        'l_shoulder': [0.72, 0.50], 'r_shoulder': [0.72, 0.58],
        'l_elbow': [0.64, 0.44], 'r_elbow': [0.64, 0.62],
        'l_hand': [0.55, 0.42], 'r_hand': [0.55, 0.64],
        'l_hip': [0.44, 0.48], 'r_hip': [0.44, 0.56],
        'l_knee': [0.28, 0.40], 'r_knee': [0.28, 0.64],
        'l_foot': [0.16, 0.50], 'r_foot': [0.16, 0.58],
      };

  static Map<String, List<double>> _crunchTopJoints() => {
        'head': [0.72, 0.40],
        'l_shoulder': [0.62, 0.44], 'r_shoulder': [0.62, 0.54],
        'l_elbow': [0.58, 0.38], 'r_elbow': [0.58, 0.58],
        'l_hand': [0.52, 0.36], 'r_hand': [0.52, 0.60],
        'l_hip': [0.44, 0.50], 'r_hip': [0.44, 0.58],
        'l_knee': [0.28, 0.40], 'r_knee': [0.28, 0.64],
        'l_foot': [0.16, 0.50], 'r_foot': [0.16, 0.58],
      };

  /// マークダウンブロックを除去し、最初の JSON オブジェクトを抽出する。
  static String _extractJson(String text) {
    var s = text
        .replaceAll(RegExp(r'```json\s*', multiLine: true), '')
        .replaceAll(RegExp(r'```\s*', multiLine: true), '')
        .trim();
    final start = s.indexOf('{');
    final end = s.lastIndexOf('}');
    if (start >= 0 && end > start) s = s.substring(start, end + 1);
    return s;
  }

  // ── API 呼び出し ───────────────────────────────────────────────────────────

  Future<String> _callAnthropic(
      String apiKey, String model, String user) async {
    final res = await http.post(
      Uri.parse('https://api.anthropic.com/v1/messages'),
      headers: {
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
        'content-type': 'application/json',
      },
      body: jsonEncode({
        'model': model,
        'max_tokens': _maxTokens,
        'system': _systemPrompt,
        'messages': [
          {'role': 'user', 'content': user},
        ],
      }),
    );
    if (res.statusCode != 200) throw Exception('Anthropic API error');
    final data = jsonDecode(utf8.decode(res.bodyBytes));
    return data['content'][0]['text'] as String;
  }

  Future<String> _callOpenAi(
      String apiKey, String model, String user) async {
    final res = await http.post(
      Uri.parse('https://api.openai.com/v1/chat/completions'),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'content-type': 'application/json',
      },
      body: jsonEncode({
        'model': model,
        'max_tokens': _maxTokens,
        'messages': [
          {'role': 'system', 'content': _systemPrompt},
          {'role': 'user', 'content': user},
        ],
      }),
    );
    if (res.statusCode != 200) throw Exception('OpenAI API error');
    final data = jsonDecode(utf8.decode(res.bodyBytes));
    return data['choices'][0]['message']['content'] as String;
  }

  Future<String> _callGemini(
      String apiKey, String model, String user) async {
    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey',
    );
    final res = await http.post(
      uri,
      headers: {'content-type': 'application/json'},
      body: jsonEncode({
        'system_instruction': {
          'parts': [
            {'text': _systemPrompt},
          ],
        },
        'contents': [
          {
            'parts': [
              {'text': user},
            ],
          },
        ],
        'generationConfig': {'maxOutputTokens': _maxTokens},
      }),
    );
    if (res.statusCode != 200) throw Exception('Gemini API error');
    final data = jsonDecode(utf8.decode(res.bodyBytes));
    return data['candidates'][0]['content']['parts'][0]['text'] as String;
  }
}
