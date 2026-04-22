import '../models/training_log.dart';

/// 種目ごとのフォーム解説（テキストのみ）。
/// アニメーションは AI 生成のスティックフィギュアを利用するため、
/// Lottie アセットフィールドは廃止。
class ExerciseMotionGuide {
  final List<String> tips;

  const ExerciseMotionGuide({required this.tips});
}

String _norm(String name) =>
    name.toLowerCase().replaceAll('\u3000', ' ').trim();

final List<MapEntry<String, ExerciseMotionGuide>> _keywordGuidesSorted = () {
  final m = <String, ExerciseMotionGuide>{
    'インクライン dumbbell press': ExerciseMotionGuide(tips: [
      'ベンチ角度は30〜45度。肩がすくまない高さでダンベルを支える。',
      '肘はやや斜め下。胸上部にストレッチを感じながら下ろす。',
      '手首は中立（ダンベルが前後に倒れないように）。',
    ]),
    'インクライン・ダンベルプレス': ExerciseMotionGuide(tips: [
      '背中をパッドにつけ、足で床をしっかり踏む。',
      'ダンベルを肩幅よりやや外で下ろし、胸の上部に効かせる。',
    ]),
    'インクライン': ExerciseMotionGuide(tips: [
      '胸骨を少し持ち上げ、肩甲骨は寄せたまま固定する。',
      'バー／ダンベルは胸骨〜胸上部のラインで下ろす。',
    ]),
    'デクライン': ExerciseMotionGuide(tips: [
      '下半身の固定を確認。下ろす位置は下胸〜腹部付近のライン。',
      '腰の反り過ぎに注意し、コアで安定させる。',
    ]),
    'ベンチプレス': ExerciseMotionGuide(tips: [
      '肩甲骨を寄せて胸を張り、足は床にしっかり置く。',
      'バーは乳首ライン付近に下ろし、肘は45〜75度程度の角度で。',
      '手首は中立を保ち、肩に負担が集中しないよう意識する。',
    ]),
    'ダンベルプレス': ExerciseMotionGuide(tips: [
      'ベンチでは肩甲骨を固定。ダンベルは胸のラインで下ろす。',
      '上げきったときにダンベル同士をぶつけすぎない。',
    ]),
    'チェストプレス': ExerciseMotionGuide(tips: [
      'シート高さでハンドルが胸の中央付近に来るよう調整。',
      '肩が前に出ないよう、背中をパッドにつける。',
      '肘のロックアウトは強く突かず、収縮で止める。',
    ]),
    'デッドリフト': ExerciseMotionGuide(tips: [
      'バーは足に近づけ、肩はバーの直上よりやや前でも可。',
      '背中はニュートラル（丸めない）。膝と股関節で立ち上がる。',
      'バーは体に沿って上下させ、腰だけで引き上げない。',
    ]),
    'ルーマニアン・デッドリフト': ExerciseMotionGuide(tips: [
      '膝はほぼ固定し、骨盤をヒンジ（折りたたむ）ように動かす。',
      'ハムストリングに伸びを感じたら止める。背中はフラット。',
    ]),
    'スクワット': ExerciseMotionGuide(tips: [
      'つま先と膝の向きをそろえ、かかとを浮かさない。',
      '胸は見える位置をキープし、背中は丸めない。',
      '大腿が床と平行になるか、可動域いっぱいまで。',
    ]),
    'レッグプレス': ExerciseMotionGuide(tips: [
      '腰がパッドから浮かない幅で可動域を決める。',
      '膝は内側に入れず、つま先と同じ向きに。',
      'ロックアウトで膝を完全に伸ばし切らないことも。',
    ]),
    'レッグエクステンション': ExerciseMotionGuide(tips: [
      '腰をシートに密着。上げきった位置で1秒キープも有効。',
      '下ろすときはコントロールして膝に負担を溜めない。',
    ]),
    'レッグカール': ExerciseMotionGuide(tips: [
      '腰を反らさない。パッドの位置で太ももが固定されているか確認。',
      'かかとでパッドを引き、ゆっくり下ろす。',
    ]),
    'ランジ': ExerciseMotionGuide(tips: [
      '前膝がつま先より大きく前に出ないよう注意。体はまっすぐ。後ろ脚は補助として使う。',
    ]),
    'ブルガリアンスクワット': ExerciseMotionGuide(tips: [
      '前脚の膝とつま先の向きをそろえる。ベンチの高さは膝くらいが目安。',
      '前脚のかかとで立ち上がるイメージ。',
    ]),
    'カーフレイズ': ExerciseMotionGuide(tips: [
      'つま先立ちの最高点で1秒止め、かかとを床まで下ろす。',
      '膝はわずかに曲げた固定でもストレートでも可（種目による）。',
    ]),
    'ラットプルダウン': ExerciseMotionGuide(tips: [
      '胸を張り、肩甲骨を下げた状態からバーを引く。',
      '肘は体側に沿わせ、胸の高さまで（あごまで）引く。',
      '体を大きく反らして引かない。',
    ]),
    'セートロー': ExerciseMotionGuide(tips: [
      '胸をパッドにつけ、腰を反らしすぎない。',
      '肘は斜め後ろに引き、背中の中央〜広背筋に効かせる。',
    ]),
    'ベントオーバーロー': ExerciseMotionGuide(tips: [
      '股関節を折り、背中はフラット。膝はわずかに曲げる。',
      'バーは膝〜下腹部に沿って引き、肘は体側へ。',
    ]),
    '懸垂': ExerciseMotionGuide(tips: [
      '肩甲骨を下げてから引き始める（デッドハングからのスカプラ）。',
      '体を大きく反らさず、胸をバーに近づけるイメージで。',
    ]),
    'チンアップ': ExerciseMotionGuide(tips: [
      '逆手は肩幅程度。肩のけが予防のため無理な幅は避ける。',
      '体を反らしすぎず、肘を体側に寄せて引く。',
    ]),
    'フェイスプル': ExerciseMotionGuide(tips: [
      'ロープを顔の高さ付近に引き、肘は高めに外へ開く。',
      '後頭部にロープが触れるイメージで肩甲骨を寄せる。',
    ]),
    'ショルダープレス': ExerciseMotionGuide(tips: [
      'コアを締め、腰の反りに注意。',
      'バー／ダンベルは鼻〜あごの高さまで下ろし、肘はやや前。',
    ]),
    'ラテラルレイズ': ExerciseMotionGuide(tips: [
      '肘はわずかに曲げたまま、リーディングエッジ（小指側）を上に。',
      '肩がすくまない高さで止める（耳と肩の距離を保つ）。',
    ]),
    'リアデルトフライ': ExerciseMotionGuide(tips: [
      '胸をパッドにつけ、肘は微曲げで一定の角度を保つ。',
      '後肩に効くスピードで開き、振らない。',
    ]),
    'アームカール': ExerciseMotionGuide(tips: [
      '肘は体の横で固定。肩で振らず前腕で曲げる。',
      '下ろすときも2〜3秒かけてコントロール。',
    ]),
    'トライセプス': ExerciseMotionGuide(tips: [
      '肘は体に固定（またはパッドに）。前腕だけが動くように。',
      '頭上系では肘が外開しないよう意識。',
    ]),
    'プッシュアップ': ExerciseMotionGuide(tips: [
      '体は一直線（頭〜かかと）。肘は斜め後ろ45度付近。',
      '肩甲骨は安定させ、胸を床に近づける。',
    ]),
    'プランク': ExerciseMotionGuide(tips: [
      '骨盤が落ちない・おっぱが上がりすぎない中立を保つ。',
      '肘は肩の真下を意識。呼吸は浅くても可。',
    ]),
    'クランチ': ExerciseMotionGuide(tips: [
      '腰で丸めない。肋骨と骨盤を近づけるイメージで上体を起こす。',
      '首は手で引っ張らず、あごはわずか引く。',
    ]),
    'ローテーション': ExerciseMotionGuide(tips: [
      '体幹でねじり、肩と骨盤が一緒に動かないよう分離。',
      '腰の痛みが出たら可動域を縮める。',
    ]),
    'ケーブル': ExerciseMotionGuide(tips: [
      'ケーブルの向きに体が引っ張られないよう、足幅と姿勢を安定させる。',
      '関節の可動域内で、テンションを一定に。',
    ]),
    'トレッドミル': ExerciseMotionGuide(tips: [
      '体は真上、ステップは足の真下に。いきなり最高速度にしない。',
      '腕は前後に振り、無理な歩幅は避ける。',
    ]),
    'ランニング': ExerciseMotionGuide(tips: [
      'かかとではなく中足〜つま先寄りで着地するイメージ。',
      '体はまっすぐ、視線は前方。呼吸は規則的に。',
    ]),
    'バイク': ExerciseMotionGuide(tips: [
      'サドル高で膝がほぼ伸びきる位置を目安に。',
      'ペダルは足の骨幅、無理な膝の内股・外股を避ける。',
    ]),
    'エリプティカル': ExerciseMotionGuide(tips: [
      'かかとを浮かさず、全足で踏む。体を前後に大きく振らない。',
      'ハンドルに体重を頼りすぎない。',
    ]),
    'ローイング': ExerciseMotionGuide(tips: [
      '脚〜体幹〜腕の順で引き、背中で終える。',
      '肩がすくまないよう、肩甲骨を寄せてから手を引く。',
    ]),
    'bench press': ExerciseMotionGuide(tips: [
      'Retract shoulder blades, feet flat. Bar to lower chest.',
      'Wrists neutral; avoid flaring elbows excessively.',
    ]),
    'squat': ExerciseMotionGuide(tips: [
      'Knees track over toes; chest up, neutral spine.',
      'Break at hips and knees together; full controlled range.',
    ]),
    'deadlift': ExerciseMotionGuide(tips: [
      'Bar close to shins; brace core; hinge and extend hips.',
      'Do not round the lower back at the start.',
    ]),
    'rdl': ExerciseMotionGuide(tips: [
      'Soft knee bend; push hips back; bar slides along legs.',
      'Feel hamstrings; keep spine neutral.',
    ]),
    'lat pulldown': ExerciseMotionGuide(tips: [
      'Depress scapulae first; pull to upper chest with elbows down.',
      'Avoid leaning back excessively.',
    ]),
    'leg press': ExerciseMotionGuide(tips: [
      'Keep low back on pad; feet shoulder-width; control depth.',
      'Do not lock knees harshly at top.',
    ]),
  };
  final list = m.entries.toList()
    ..sort((a, b) => b.key.length.compareTo(a.key.length));
  return list;
}();

ExerciseMotionGuide _defaultByType(ExerciseType type) {
  switch (type) {
    case ExerciseType.machine:
      return ExerciseMotionGuide(tips: [
        'マシンの説明に従い、シート・レバーを身長に合わせ調整する。',
        '可動域は無理に広げず、異和感があれば中止する。',
        'テンションは上で1秒・下ろして2〜3秒を目安にコントロールする。',
      ]);
    case ExerciseType.bodyweight:
      return ExerciseMotionGuide(tips: [
        '体幹を安定させ、肩・股関節・膝が一直線になるよう意識する。',
        '可動域は品質優先。回数よりフォームを優先する。',
        '痛みがある部位に負担が集中しないよう、角度を変えて試す。',
      ]);
    case ExerciseType.cardio:
      return ExerciseMotionGuide(tips: [
        'ウォームアップで心拍と体温を少しずつ上げる。',
        'きつすぎて続けられない強度は避け、会話がやや苦しい程度から。',
        'クールダウンで心拍を落とし、ストレッチで終える。',
      ]);
    case ExerciseType.freeWeight:
      return ExerciseMotionGuide(tips: [
        'バー・ダンベルはバランスを取りながら、関節中立を保つ。',
        '重量よりも可動域とコントロールを優先する。',
        'スポッターがいないときは失敗しそうな重量を避ける。',
      ]);
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
