import 'dart:convert';

/// 1回の摂取量あたりの詳細栄養（中鎖脂肪酸・脂肪酸・アミノ酸など）
/// サプリメント入力を主な用途とする。
class DetailedNutrients {
  /// 中鎖脂肪酸 (g)
  final double mctG;

  /// ω-3脂肪酸 合計 (g)
  final double omega3TotalG;

  /// ω-6脂肪酸 合計 (g)
  final double omega6G;

  final double epaMg;
  final double dhaMg;
  final double alaMg;

  /// 必須アミノ酸 (g)
  final double eaaHistidineG;
  final double eaaIsoleucineG;
  final double eaaLeucineG;
  final double eaaLysineG;
  final double eaaMethionineG;
  final double eaaPhenylalanineG;
  final double eaaThreonineG;
  final double eaaTryptophanG;
  final double eaaValineG;

  /// その他アミノ酸 (g)
  final double aaArginineG;
  final double aaTyrosineG;
  final double aaCysteineG;
  final double aaGlycineG;
  final double aaProlineG;
  final double aaSerineG;
  final double aaGlutamineG;
  final double aaAlanineG;
  final double aaTaurineG;
  final double aaAsparticAcidG;
  final double aaGlutamicAcidG;

  const DetailedNutrients({
    this.mctG = 0,
    this.omega3TotalG = 0,
    this.omega6G = 0,
    this.epaMg = 0,
    this.dhaMg = 0,
    this.alaMg = 0,
    this.eaaHistidineG = 0,
    this.eaaIsoleucineG = 0,
    this.eaaLeucineG = 0,
    this.eaaLysineG = 0,
    this.eaaMethionineG = 0,
    this.eaaPhenylalanineG = 0,
    this.eaaThreonineG = 0,
    this.eaaTryptophanG = 0,
    this.eaaValineG = 0,
    this.aaArginineG = 0,
    this.aaTyrosineG = 0,
    this.aaCysteineG = 0,
    this.aaGlycineG = 0,
    this.aaProlineG = 0,
    this.aaSerineG = 0,
    this.aaGlutamineG = 0,
    this.aaAlanineG = 0,
    this.aaTaurineG = 0,
    this.aaAsparticAcidG = 0,
    this.aaGlutamicAcidG = 0,
  });

  static const zero = DetailedNutrients();

  DetailedNutrients operator +(DetailedNutrients o) => DetailedNutrients(
        mctG: mctG + o.mctG,
        omega3TotalG: omega3TotalG + o.omega3TotalG,
        omega6G: omega6G + o.omega6G,
        epaMg: epaMg + o.epaMg,
        dhaMg: dhaMg + o.dhaMg,
        alaMg: alaMg + o.alaMg,
        eaaHistidineG: eaaHistidineG + o.eaaHistidineG,
        eaaIsoleucineG: eaaIsoleucineG + o.eaaIsoleucineG,
        eaaLeucineG: eaaLeucineG + o.eaaLeucineG,
        eaaLysineG: eaaLysineG + o.eaaLysineG,
        eaaMethionineG: eaaMethionineG + o.eaaMethionineG,
        eaaPhenylalanineG: eaaPhenylalanineG + o.eaaPhenylalanineG,
        eaaThreonineG: eaaThreonineG + o.eaaThreonineG,
        eaaTryptophanG: eaaTryptophanG + o.eaaTryptophanG,
        eaaValineG: eaaValineG + o.eaaValineG,
        aaArginineG: aaArginineG + o.aaArginineG,
        aaTyrosineG: aaTyrosineG + o.aaTyrosineG,
        aaCysteineG: aaCysteineG + o.aaCysteineG,
        aaGlycineG: aaGlycineG + o.aaGlycineG,
        aaProlineG: aaProlineG + o.aaProlineG,
        aaSerineG: aaSerineG + o.aaSerineG,
        aaGlutamineG: aaGlutamineG + o.aaGlutamineG,
        aaAlanineG: aaAlanineG + o.aaAlanineG,
        aaTaurineG: aaTaurineG + o.aaTaurineG,
        aaAsparticAcidG: aaAsparticAcidG + o.aaAsparticAcidG,
        aaGlutamicAcidG: aaGlutamicAcidG + o.aaGlutamicAcidG,
      );

  Map<String, dynamic> toMap() => {
        'mct_g': mctG,
        'omega3_total_g': omega3TotalG,
        'omega6_g': omega6G,
        'epa_mg': epaMg,
        'dha_mg': dhaMg,
        'ala_mg': alaMg,
        'eaa_histidine_g': eaaHistidineG,
        'eaa_isoleucine_g': eaaIsoleucineG,
        'eaa_leucine_g': eaaLeucineG,
        'eaa_lysine_g': eaaLysineG,
        'eaa_methionine_g': eaaMethionineG,
        'eaa_phenylalanine_g': eaaPhenylalanineG,
        'eaa_threonine_g': eaaThreonineG,
        'eaa_tryptophan_g': eaaTryptophanG,
        'eaa_valine_g': eaaValineG,
        'aa_arginine_g': aaArginineG,
        'aa_tyrosine_g': aaTyrosineG,
        'aa_cysteine_g': aaCysteineG,
        'aa_glycine_g': aaGlycineG,
        'aa_proline_g': aaProlineG,
        'aa_serine_g': aaSerineG,
        'aa_glutamine_g': aaGlutamineG,
        'aa_alanine_g': aaAlanineG,
        'aa_taurine_g': aaTaurineG,
        'aa_aspartic_acid_g': aaAsparticAcidG,
        'aa_glutamic_acid_g': aaGlutamicAcidG,
      };

  factory DetailedNutrients.fromMap(Map<String, dynamic> m) {
    double g(String k) => (m[k] as num?)?.toDouble() ?? 0;
    return DetailedNutrients(
      mctG: g('mct_g'),
      omega3TotalG: g('omega3_total_g'),
      omega6G: g('omega6_g'),
      epaMg: g('epa_mg'),
      dhaMg: g('dha_mg'),
      alaMg: g('ala_mg'),
      eaaHistidineG: g('eaa_histidine_g'),
      eaaIsoleucineG: g('eaa_isoleucine_g'),
      eaaLeucineG: g('eaa_leucine_g'),
      eaaLysineG: g('eaa_lysine_g'),
      eaaMethionineG: g('eaa_methionine_g'),
      eaaPhenylalanineG: g('eaa_phenylalanine_g'),
      eaaThreonineG: g('eaa_threonine_g'),
      eaaTryptophanG: g('eaa_tryptophan_g'),
      eaaValineG: g('eaa_valine_g'),
      aaArginineG: g('aa_arginine_g'),
      aaTyrosineG: g('aa_tyrosine_g'),
      aaCysteineG: g('aa_cysteine_g'),
      aaGlycineG: g('aa_glycine_g'),
      aaProlineG: g('aa_proline_g'),
      aaSerineG: g('aa_serine_g'),
      aaGlutamineG: g('aa_glutamine_g'),
      aaAlanineG: g('aa_alanine_g'),
      aaTaurineG: g('aa_taurine_g'),
      aaAsparticAcidG: g('aa_aspartic_acid_g'),
      aaGlutamicAcidG: g('aa_glutamic_acid_g'),
    );
  }

  static DetailedNutrients? fromJsonString(String? json) {
    if (json == null || json.isEmpty) return null;
    try {
      final m = jsonDecode(json) as Map<String, dynamic>;
      return DetailedNutrients.fromMap(m);
    } catch (_) {
      return null;
    }
  }

  String toJsonString() => jsonEncode(toMap());

  bool get hasAnyPositive {
    return mctG > 0 ||
        omega3TotalG > 0 ||
        omega6G > 0 ||
        epaMg > 0 ||
        dhaMg > 0 ||
        alaMg > 0 ||
        eaaHistidineG > 0 ||
        eaaIsoleucineG > 0 ||
        eaaLeucineG > 0 ||
        eaaLysineG > 0 ||
        eaaMethionineG > 0 ||
        eaaPhenylalanineG > 0 ||
        eaaThreonineG > 0 ||
        eaaTryptophanG > 0 ||
        eaaValineG > 0 ||
        aaArginineG > 0 ||
        aaTyrosineG > 0 ||
        aaCysteineG > 0 ||
        aaGlycineG > 0 ||
        aaProlineG > 0 ||
        aaSerineG > 0 ||
        aaGlutamineG > 0 ||
        aaAlanineG > 0 ||
        aaTaurineG > 0 ||
        aaAsparticAcidG > 0 ||
        aaGlutamicAcidG > 0;
  }

  /// UI・サマリー用（キーは [toMap] と一致）
  static const List<({String key, String label, String unit})> editorFieldsFatty = [
    (key: 'mct_g', label: '中鎖脂肪酸 (MCT)', unit: 'g'),
    (key: 'omega3_total_g', label: 'ω-3 合計', unit: 'g'),
    (key: 'omega6_g', label: 'ω-6 合計', unit: 'g'),
    (key: 'epa_mg', label: 'EPA', unit: 'mg'),
    (key: 'dha_mg', label: 'DHA', unit: 'mg'),
    (key: 'ala_mg', label: 'α-リノレン酸', unit: 'mg'),
  ];

  static const List<({String key, String label, String unit})> editorFieldsEaa = [
    (key: 'eaa_histidine_g', label: 'ヒスチジン', unit: 'g'),
    (key: 'eaa_isoleucine_g', label: 'イソロイシン', unit: 'g'),
    (key: 'eaa_leucine_g', label: 'ロイシン', unit: 'g'),
    (key: 'eaa_lysine_g', label: 'リシン', unit: 'g'),
    (key: 'eaa_methionine_g', label: 'メチオニン', unit: 'g'),
    (key: 'eaa_phenylalanine_g', label: 'フェニルアラニン', unit: 'g'),
    (key: 'eaa_threonine_g', label: 'トレオニン', unit: 'g'),
    (key: 'eaa_tryptophan_g', label: 'トリプトファン', unit: 'g'),
    (key: 'eaa_valine_g', label: 'バリン', unit: 'g'),
  ];

  static const List<({String key, String label, String unit})> editorFieldsOtherAa = [
    (key: 'aa_arginine_g', label: 'アルギニン', unit: 'g'),
    (key: 'aa_tyrosine_g', label: 'チロシン', unit: 'g'),
    (key: 'aa_cysteine_g', label: 'システイン', unit: 'g'),
    (key: 'aa_glycine_g', label: 'グリシン', unit: 'g'),
    (key: 'aa_proline_g', label: 'プロリン', unit: 'g'),
    (key: 'aa_serine_g', label: 'セリン', unit: 'g'),
    (key: 'aa_glutamine_g', label: 'グルタミン', unit: 'g'),
    (key: 'aa_alanine_g', label: 'アラニン', unit: 'g'),
    (key: 'aa_taurine_g', label: 'タウリン', unit: 'g'),
    (key: 'aa_aspartic_acid_g', label: 'アスパラギン酸', unit: 'g'),
    (key: 'aa_glutamic_acid_g', label: 'グルタミン酸', unit: 'g'),
  ];

  List<String> summaryLines() {
    final m = toMap();
    final out = <String>[];
    void addField(String key, String label, String unit) {
      final v = (m[key] as num?)?.toDouble() ?? 0;
      if (v <= 0) return;
      final vs = unit == 'mg'
          ? (v >= 10 ? v.toStringAsFixed(0) : v.toStringAsFixed(1))
          : (v >= 10 ? v.toStringAsFixed(1) : v.toStringAsFixed(2));
      out.add('$label $vs $unit');
    }

    for (final f in editorFieldsFatty) {
      addField(f.key, f.label, f.unit);
    }
    for (final f in editorFieldsEaa) {
      addField(f.key, f.label, f.unit);
    }
    for (final f in editorFieldsOtherAa) {
      addField(f.key, f.label, f.unit);
    }
    return out;
  }
}
