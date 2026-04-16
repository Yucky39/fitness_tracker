import '../models/training_log.dart';

/// 種目ごとのフォーム解説と Lottie（任意）。
class ExerciseMotionGuide {
  final List<String> tips;
  final String? lottieAsset;

  const ExerciseMotionGuide({
    required this.tips,
    this.lottieAsset,
  });
}

const String kDefaultExerciseMotionLottie =
    'assets/lottie/exercises/motion_loop.json';

String _norm(String name) =>
    name.toLowerCase().replaceAll('\u3000', ' ').trim();

final List<MapEntry<String, ExerciseMotionGuide>> _keywordGuidesSorted = () {
  final m = <String, ExerciseMotionGuide>{
    'インクライン dumbbell press': ExerciseMotionGuide(
      tips: [
        'ベンチ角度は30〜45度。肩がすくまない高さでダンベルを支える。',
        '肘はやや斜め下。胸上部にストレッチを感じながら下ろす。',
        '手首は中立（ダンベルが前後に倒れないように）。',
      ],
      lottieAsset: kDefaultExerciseMotionLottie,
    ),
    'インクライン・ダンベルプレス': ExerciseMotionGuide(
      tips: [
        '背中をパッドにつけ、足で床をしっかり踏む。',
        'ダンベルを肩幅よりやや外で下ろし、胸の上部に効かせる。',
      ],
      lottieAsset: kDefaultExerciseMotionLottie,
    ),
    'インクライン': ExerciseMotionGuide(
      tips: [
        '胸骨を少し持ち上げ、肩甲骨は寄せたまま固定する。',
        'バー／ダンベルは胸骨〜胸上部のラインで下ろす。',
      ],
      lottieAsset: kDefaultExerciseMotionLottie,
    ),
    'デクライン': ExerciseMotionGuide(
      tips: [
        '下半身の固定を確認。下ろす位置は下胸〜腹部付近のライン。',
        '腰の反り過ぎに注意し、コアで安定させる。',
      ],
      lottieAsset: kDefaultExerciseMotionLottie,
    ),
    'ベンチプレス': ExerciseMotionGuide(
      tips: [
        '肩甲骨を寄せて胸を張り、足は床にしっかり置く。',
        'バーは乳首ライン付近に下ろし、肘は45〜75度程度の角度で。',
        '手首は中立を保ち、肩に負担が集中しないよう意識する。',
      ],
      lottieAsset: kDefaultExerciseMotionLottie,
    ),
    'ダンベルプレス': ExerciseMotionGuide(
      tips: [
        'ベンチでは肩甲骨を固定。ダンベルは胸のラインで下ろす。',
        '上げきったときにダンベル同士をぶつけすぎない。',
      ],
      lottieAsset: kDefaultExerciseMotionLottie,
    ),
    'チェストプレス': ExerciseMotionGuide(
      tips: [
        'シート高さでハンドルが胸の中央付近に来るよう調整。',
        '肩が前に出ないよう、背中をパッドにつける。',
        '肘のロックアウトは強く突かず、収縮で止める。',
      ],
      lottieAsset: kDefaultExerciseMotionLottie,
    ),
    'デッドリフト': ExerciseMotionGuide(
      tips: [
        'バーは足に近づけ、肩はバーの直上よりやや前でも可。',
        '背中はニュートラル（丸めない）。膝と股関節で立ち上がる。',
        'バーは体に沿って上下させ、腰だけで引き上げない。',
      ],
      lottieAsset: kDefaultExerciseMotionLottie,
    ),
    'ルーマニアン・デッドリフト': ExerciseMotionGuide(
      tips: [
        '膝はほぼ固定し、骨盤をヒンジ（折りたたむ）ように動かす。',
        'ハムストリングに伸びを感じたら止める。背中はフラット。',
      ],
      lottieAsset: kDefaultExerciseMotionLottie,
    ),
    'スクワット': ExerciseMotionGuide(
      tips: [
        'つま先と膝の向きをそろえ、かかとを浮かさない。',
        '胸は見える位置をキープし、背中は丸めない。',
        '大腿が床と平行になるか、可動域いっぱいまで。',
      ],
      lottieAsset: kDefaultExerciseMotionLottie,
    ),
    'レッグプレス': ExerciseMotionGuide(
      tips: [
        '腰がパッドから浮かない幅で可動域を決める。',
        '膝は内側に入れず、つま先と同じ向きに。',
        'ロックアウトで膝を完全に伸ばし切らないことも。',
      ],
      lottieAsset: kDefaultExerciseMotionLottie,
    ),
    'レッグエクステンション': ExerciseMotionGuide(
      tips: [
        '腰をシートに密着。上げきった位置で1秒キープも有効。',
        '下ろすときはコントロールして膝に負担を溜めない。',
      ],
      lottieAsset: kDefaultExerciseMotionLottie,
    ),
    'レッグカール': ExerciseMotionGuide(
      tips: [
        '腰を反らさない。パッドの位置で太ももが固定されているか確認。',
        'かかとでパッドを引き、ゆっくり下ろす。',
      ],
      lottieAsset: kDefaultExerciseMotionLottie,
    ),
    'ランジ': ExerciseMotionGuide(
      tips: [
        '前膝がつま先より大きく前に出ないよう注意。体はまっすぐ。後ろ脚は補助として使う。',
      ],
      lottieAsset: kDefaultExerciseMotionLottie,
    ),
    'ブルガリアンスクワット': ExerciseMotionGuide(
      tips: [
        '前脚の膝とつま先の向きをそろえる。ベンチの高さは膝くらいが目安。',
        '前脚のかかとで立ち上がるイメージ。',
      ],
      lottieAsset: kDefaultExerciseMotionLottie,
    ),
    'カーフレイズ': ExerciseMotionGuide(
      tips: [
        'つま先立ちの最高点で1秒止め、かかとを床まで下ろす。',
        '膝はわずかに曲げた固定でもストレートでも可（種目による）。',
      ],
      lottieAsset: kDefaultExerciseMotionLottie,
    ),
    'ラットプルダウン': ExerciseMotionGuide(
      tips: [
        '胸を張り、肩甲骨を下げた状態からバーを引く。',
        '肘は体側に沿わせ、胸の高さまで（あごまで）引く。',
        '体を大きく反らして引かない。',
      ],
      lottieAsset: kDefaultExerciseMotionLottie,
    ),
    'セートロー': ExerciseMotionGuide(
      tips: [
        '胸をパッドにつけ、腰を反らしすぎない。',
        '肘は斜め後ろに引き、背中の中央〜広背筋に効かせる。',
      ],
      lottieAsset: kDefaultExerciseMotionLottie,
    ),
    'ベントオーバーロー': ExerciseMotionGuide(
      tips: [
        '股関節を折り、背中はフラット。膝はわずかに曲げる。',
        'バーは膝〜下腹部に沿って引き、肘は体側へ。',
      ],
      lottieAsset: kDefaultExerciseMotionLottie,
    ),
    '懸垂': ExerciseMotionGuide(
      tips: [
        '肩甲骨を下げてから引き始める（デッドハングからのスカプラ）。',
        '体を大きく反らさず、胸をバーに近づけるイメージで。',
      ],
      lottieAsset: kDefaultExerciseMotionLottie,
    ),
    'チンアップ': ExerciseMotionGuide(
      tips: [
        '逆手は肩幅程度。肩のけが予防のため無理な幅は避ける。',
        '体を反らしすぎず、肘を体側に寄せて引く。',
      ],
      lottieAsset: kDefaultExerciseMotionLottie,
    ),
    'フェイスプル': ExerciseMotionGuide(
      tips: [
        'ロープを顔の高さ付近に引き、肘は高めに外へ開く。',
        '後頭部にロープが触れるイメージで肩甲骨を寄せる。',
      ],
      lottieAsset: kDefaultExerciseMotionLottie,
    ),
    'ショルダープレス': ExerciseMotionGuide(
      tips: [
        'コアを締め、腰の反りに注意。',
        'バー／ダンベルは鼻〜あごの高さまで下ろし、肘はやや前。',
      ],
      lottieAsset: kDefaultExerciseMotionLottie,
    ),
    'ラテラルレイズ': ExerciseMotionGuide(
      tips: [
        '肘はわずかに曲げたまま、リーディングエッジ（小指側）を上に。',
        '肩がすくまない高さで止める（耳と肩の距離を保つ）。',
      ],
      lottieAsset: kDefaultExerciseMotionLottie,
    ),
    'リアデルトフライ': ExerciseMotionGuide(
      tips: [
        '胸をパッドにつけ、肘は微曲げで一定の角度を保つ。',
        '後肩に効くスピードで開き、振らない。',
      ],
      lottieAsset: kDefaultExerciseMotionLottie,
    ),
    'アームカール': ExerciseMotionGuide(
      tips: [
        '肘は体の横で固定。肩で振らず前腕で曲げる。',
        '下ろすときも2〜3秒かけてコントロール。',
      ],
      lottieAsset: kDefaultExerciseMotionLottie,
    ),
    'トライセプス': ExerciseMotionGuide(
      tips: [
        '肘は体に固定（またはパッドに）。前腕だけが動くように。',
        '頭上系では肘が外開しないよう意識。',
      ],
      lottieAsset: kDefaultExerciseMotionLottie,
    ),
    'プッシュアップ': ExerciseMotionGuide(
      tips: [
        '体は一直線（頭〜かかと）。肘は斜め後ろ45度付近。',
        '肩甲骨は安定させ、胸を床に近づける。',
      ],
      lottieAsset: kDefaultExerciseMotionLottie,
    ),
    'プランク': ExerciseMotionGuide(
      tips: [
        '骨盤が落ちない・おっぱが上がりすぎない中立を保つ。',
        '肘は肩の真下を意識。呼吸は浅くても可。',
      ],
      lottieAsset: kDefaultExerciseMotionLottie,
    ),
    'クランチ': ExerciseMotionGuide(
      tips: [
        '腰で丸めない。肋骨と骨盤を近づけるイメージで上体を起こす。',
        '首は手で引っ張らず、あごはわずか引く。',
      ],
      lottieAsset: kDefaultExerciseMotionLottie,
    ),
    'ローテーション': ExerciseMotionGuide(
      tips: [
        '体幹でねじり、肩と骨盤が一緒に動かないよう分離。',
        '腰の痛みが出たら可動域を縮める。',
      ],
      lottieAsset: kDefaultExerciseMotionLottie,
    ),
    'ケーブル': ExerciseMotionGuide(
      tips: [
        'ケーブルの向きに体が引っ張られないよう、足幅と姿勢を安定させる。',
        '関節の可動域内で、テンションを一定に。',
      ],
      lottieAsset: kDefaultExerciseMotionLottie,
    ),
    'トレッドミル': ExerciseMotionGuide(
      tips: [
        '体は真上、ステップは足の真下に。いきなり最高速度にしない。',
        '腕は前後に振り、無理な歩幅は避ける。',
      ],
      lottieAsset: kDefaultExerciseMotionLottie,
    ),
    'ランニング': ExerciseMotionGuide(
      tips: [
        'かかとではなく中足〜つま先寄りで着地するイメージ。',
        '体はまっすぐ、視線は前方。呼吸は規則的に。',
      ],
      lottieAsset: kDefaultExerciseMotionLottie,
    ),
    'バイク': ExerciseMotionGuide(
      tips: [
        'サドル高で膝がほぼ伸びきる位置を目安に。',
        'ペダルは足の骨幅、無理な膝の内股・外股を避ける。',
      ],
      lottieAsset: kDefaultExerciseMotionLottie,
    ),
    'エリプティカル': ExerciseMotionGuide(
      tips: [
        'かかとを浮かさず、全足で踏む。体を前後に大きく振らない。',
        'ハンドルに体重を頼りすぎない。',
      ],
      lottieAsset: kDefaultExerciseMotionLottie,
    ),
    'ローイング': ExerciseMotionGuide(
      tips: [
        '脚〜体幹〜腕の順で引き、背中で終える。',
        '肩がすくまないよう、肩甲骨を寄せてから手を引く。',
      ],
      lottieAsset: kDefaultExerciseMotionLottie,
    ),
    'bench press': ExerciseMotionGuide(
      tips: [
        'Retract shoulder blades, feet flat. Bar to lower chest.',
        'Wrists neutral; avoid flaring elbows excessively.',
      ],
      lottieAsset: kDefaultExerciseMotionLottie,
    ),
    'squat': ExerciseMotionGuide(
      tips: [
        'Knees track over toes; chest up, neutral spine.',
        'Break at hips and knees together; full controlled range.',
      ],
      lottieAsset: kDefaultExerciseMotionLottie,
    ),
    'deadlift': ExerciseMotionGuide(
      tips: [
        'Bar close to shins; brace core; hinge and extend hips.',
        'Do not round the lower back at the start.',
      ],
      lottieAsset: kDefaultExerciseMotionLottie,
    ),
    'rdl': ExerciseMotionGuide(
      tips: [
        'Soft knee bend; push hips back; bar slides along legs.',
        'Feel hamstrings; keep spine neutral.',
      ],
      lottieAsset: kDefaultExerciseMotionLottie,
    ),
    'lat pulldown': ExerciseMotionGuide(
      tips: [
        'Depress scapulae first; pull to upper chest with elbows down.',
        'Avoid leaning back excessively.',
      ],
      lottieAsset: kDefaultExerciseMotionLottie,
    ),
    'leg press': ExerciseMotionGuide(
      tips: [
        'Keep low back on pad; feet shoulder-width; control depth.',
        'Do not lock knees harshly at top.',
      ],
      lottieAsset: kDefaultExerciseMotionLottie,
    ),
  };
  final list = m.entries.toList()
    ..sort((a, b) => b.key.length.compareTo(a.key.length));
  return list;
}();

ExerciseMotionGuide _defaultByType(ExerciseType type) {
  switch (type) {
    case ExerciseType.machine:
      return ExerciseMotionGuide(
        tips: [
          '\u30de\u30b7\u30f3\u306e\u8aac\u660e\u306b\u5f93\u3044\u3001\u30b7\u30fc\u30c8\u30fb\u30ec\u30d0\u30fc\u3092\u8eab\u9577\u306b\u5408\u308f\u305b\u8abf\u6574\u3059\u308b\u3002',
          '\u53ef\u52d5\u57df\u306f\u7121\u7406\u306b\u5e83\u3052\u305a\u3001\u7570\u548c\u611f\u304c\u3042\u308c\u3070\u4e2d\u6b62\u3059\u308b\u3002',
          '\u30c6\u30f3\u30b7\u30e7\u30f3\u306f\u4e0a\u30521\u79d2\u30fb\u4e0b\u308d\u30572\u301c3\u79d2\u3092\u76ee\u5b89\u306b\u30b3\u30f3\u30c8\u30ed\u30fc\u30eb\u3059\u308b\u3002',
        ],
        lottieAsset: kDefaultExerciseMotionLottie,
      );
    case ExerciseType.bodyweight:
      return ExerciseMotionGuide(
        tips: [
          '\u4f53\u5e79\u3092\u5b89\u5b9a\u3055\u305b\u3001\u80a9\u30fb\u80a1\u95a2\u7bc0\u30fb\u819d\u304c\u4e00\u76f4\u7dda\u306b\u306a\u308b\u3088\u3046\u610f\u8b58\u3059\u308b\u3002',
          '\u53ef\u52d5\u57df\u306f\u54c1\u8cea\u512a\u5148\u3002\u56de\u6570\u3088\u308a\u30d5\u30a9\u30fc\u30e0\u3092\u512a\u5148\u3059\u308b\u3002',
          '\u75db\u307f\u304c\u3042\u308b\u90e8\u4f4d\u306b\u8ca0\u62c5\u304c\u96c6\u4e2d\u3057\u306a\u3044\u3088\u3046\u3001\u89d2\u5ea6\u3092\u5909\u3048\u3066\u8a66\u3059\u3002',
        ],
        lottieAsset: kDefaultExerciseMotionLottie,
      );
    case ExerciseType.cardio:
      return ExerciseMotionGuide(
        tips: [
          '\u30a6\u30a9\u30fc\u30e0\u30a2\u30c3\u30d7\u3067\u5fc3\u62cd\u3068\u4f53\u6e29\u3092\u5c11\u3057\u305a\u3064\u4e0a\u3052\u308b\u3002',
          '\u304d\u3064\u3059\u304e\u3066\u7d9a\u3051\u3089\u308c\u306a\u3044\u5f37\u5ea6\u306f\u907f\u3051\u3001\u4f1a\u8a71\u304c\u3084\u3084\u82e6\u3057\u3044\u7a0b\u5ea6\u304b\u3089\u3002',
          '\u30af\u30fc\u30eb\u30c0\u30a6\u30f3\u3067\u5fc3\u62cd\u3092\u843d\u3068\u3057\u3001\u30b9\u30c8\u30ec\u30c3\u30c1\u3067\u7d42\u3048\u308b\u3002',
        ],
        lottieAsset: kDefaultExerciseMotionLottie,
      );
    case ExerciseType.freeWeight:
      return ExerciseMotionGuide(
        tips: [
          '\u30d0\u30fc\u30fb\u30c0\u30f3\u30d9\u30eb\u306f\u30d0\u30e9\u30f3\u30b9\u3092\u53d6\u308a\u306a\u304c\u3089\u3001\u95a2\u7bc0\u4e2d\u7acb\u3092\u4fdd\u3064\u3002',
          '\u91cd\u91cf\u3088\u308a\u3082\u53ef\u52d5\u57df\u3068\u30b3\u30f3\u30c8\u30ed\u30fc\u30eb\u3092\u512a\u5148\u3059\u308b\u3002',
          '\u30b9\u30dd\u30c3\u30bf\u30fc\u304c\u3044\u306a\u3044\u3068\u304d\u306f\u5931\u6557\u3057\u305d\u3046\u306a\u91cd\u91cf\u306f\u907f\u3051\u308b\u3002',
        ],
        lottieAsset: kDefaultExerciseMotionLottie,
      );
  }
}

ExerciseMotionGuide lookupExerciseMotionGuide(
  String exerciseName,
  ExerciseType type,
) {
  final n = _norm(exerciseName);
  for (final e in _keywordGuidesSorted) {
    if (n.contains(_norm(e.key))) {
      return e.value;
    }
  }
  return _defaultByType(type);
}
