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

  /// 必須アミノ酸 (mg)
  final double eaaHistidineMg;
  final double eaaIsoleucineMg;
  final double eaaLeucineMg;
  final double eaaLysineMg;
  final double eaaMethionineMg;
  final double eaaPhenylalanineMg;
  final double eaaThreonineMg;
  final double eaaTryptophanMg;
  final double eaaValineMg;

  /// その他アミノ酸 (mg)
  final double aaArginineMg;
  final double aaTyrosineMg;
  final double aaCysteineMg;
  final double aaGlycineMg;
  final double aaProlineMg;
  final double aaSerineMg;
  final double aaGlutamineMg;
  final double aaAlanineMg;
  final double aaTaurineMg;
  final double aaAsparticAcidMg;
  final double aaGlutamicAcidMg;

  const DetailedNutrients({
    this.mctG = 0,
    this.omega3TotalG = 0,
    this.omega6G = 0,
    this.epaMg = 0,
    this.dhaMg = 0,
    this.alaMg = 0,
    this.eaaHistidineMg = 0,
    this.eaaIsoleucineMg = 0,
    this.eaaLeucineMg = 0,
    this.eaaLysineMg = 0,
    this.eaaMethionineMg = 0,
    this.eaaPhenylalanineMg = 0,
    this.eaaThreonineMg = 0,
    this.eaaTryptophanMg = 0,
    this.eaaValineMg = 0,
    this.aaArginineMg = 0,
    this.aaTyrosineMg = 0,
    this.aaCysteineMg = 0,
    this.aaGlycineMg = 0,
    this.aaProlineMg = 0,
    this.aaSerineMg = 0,
    this.aaGlutamineMg = 0,
    this.aaAlanineMg = 0,
    this.aaTaurineMg = 0,
    this.aaAsparticAcidMg = 0,
    this.aaGlutamicAcidMg = 0,
  });

  static const zero = DetailedNutrients();

  DetailedNutrients operator +(DetailedNutrients o) => DetailedNutrients(
        mctG: mctG + o.mctG,
        omega3TotalG: omega3TotalG + o.omega3TotalG,
        omega6G: omega6G + o.omega6G,
        epaMg: epaMg + o.epaMg,
        dhaMg: dhaMg + o.dhaMg,
        alaMg: alaMg + o.alaMg,
        eaaHistidineMg: eaaHistidineMg + o.eaaHistidineMg,
        eaaIsoleucineMg: eaaIsoleucineMg + o.eaaIsoleucineMg,
        eaaLeucineMg: eaaLeucineMg + o.eaaLeucineMg,
        eaaLysineMg: eaaLysineMg + o.eaaLysineMg,
        eaaMethionineMg: eaaMethionineMg + o.eaaMethionineMg,
        eaaPhenylalanineMg: eaaPhenylalanineMg + o.eaaPhenylalanineMg,
        eaaThreonineMg: eaaThreonineMg + o.eaaThreonineMg,
        eaaTryptophanMg: eaaTryptophanMg + o.eaaTryptophanMg,
        eaaValineMg: eaaValineMg + o.eaaValineMg,
        aaArginineMg: aaArginineMg + o.aaArginineMg,
        aaTyrosineMg: aaTyrosineMg + o.aaTyrosineMg,
        aaCysteineMg: aaCysteineMg + o.aaCysteineMg,
        aaGlycineMg: aaGlycineMg + o.aaGlycineMg,
        aaProlineMg: aaProlineMg + o.aaProlineMg,
        aaSerineMg: aaSerineMg + o.aaSerineMg,
        aaGlutamineMg: aaGlutamineMg + o.aaGlutamineMg,
        aaAlanineMg: aaAlanineMg + o.aaAlanineMg,
        aaTaurineMg: aaTaurineMg + o.aaTaurineMg,
        aaAsparticAcidMg: aaAsparticAcidMg + o.aaAsparticAcidMg,
        aaGlutamicAcidMg: aaGlutamicAcidMg + o.aaGlutamicAcidMg,
      );

  Map<String, dynamic> toMap() => {
        'mct_g': mctG,
        'omega3_total_g': omega3TotalG,
        'omega6_g': omega6G,
        'epa_mg': epaMg,
        'dha_mg': dhaMg,
        'ala_mg': alaMg,
        'eaa_histidine_mg': eaaHistidineMg,
        'eaa_isoleucine_mg': eaaIsoleucineMg,
        'eaa_leucine_mg': eaaLeucineMg,
        'eaa_lysine_mg': eaaLysineMg,
        'eaa_methionine_mg': eaaMethionineMg,
        'eaa_phenylalanine_mg': eaaPhenylalanineMg,
        'eaa_threonine_mg': eaaThreonineMg,
        'eaa_tryptophan_mg': eaaTryptophanMg,
        'eaa_valine_mg': eaaValineMg,
        'aa_arginine_mg': aaArginineMg,
        'aa_tyrosine_mg': aaTyrosineMg,
        'aa_cysteine_mg': aaCysteineMg,
        'aa_glycine_mg': aaGlycineMg,
        'aa_proline_mg': aaProlineMg,
        'aa_serine_mg': aaSerineMg,
        'aa_glutamine_mg': aaGlutamineMg,
        'aa_alanine_mg': aaAlanineMg,
        'aa_taurine_mg': aaTaurineMg,
        'aa_aspartic_acid_mg': aaAsparticAcidMg,
        'aa_glutamic_acid_mg': aaGlutamicAcidMg,
      };

  factory DetailedNutrients.fromMap(Map<String, dynamic> m) {
    double g(String k) => (m[k] as num?)?.toDouble() ?? 0;
    // アミノ酸はmg単位へ移行。旧データ（g単位の `*_g` キー）は1000倍してmgに換算する。
    double aa(String mgKey, String gKey) {
      final v = m[mgKey];
      if (v != null) return (v as num).toDouble();
      final gv = m[gKey];
      if (gv != null) return (gv as num).toDouble() * 1000;
      return 0;
    }

    return DetailedNutrients(
      mctG: g('mct_g'),
      omega3TotalG: g('omega3_total_g'),
      omega6G: g('omega6_g'),
      epaMg: g('epa_mg'),
      dhaMg: g('dha_mg'),
      alaMg: g('ala_mg'),
      eaaHistidineMg: aa('eaa_histidine_mg', 'eaa_histidine_g'),
      eaaIsoleucineMg: aa('eaa_isoleucine_mg', 'eaa_isoleucine_g'),
      eaaLeucineMg: aa('eaa_leucine_mg', 'eaa_leucine_g'),
      eaaLysineMg: aa('eaa_lysine_mg', 'eaa_lysine_g'),
      eaaMethionineMg: aa('eaa_methionine_mg', 'eaa_methionine_g'),
      eaaPhenylalanineMg: aa('eaa_phenylalanine_mg', 'eaa_phenylalanine_g'),
      eaaThreonineMg: aa('eaa_threonine_mg', 'eaa_threonine_g'),
      eaaTryptophanMg: aa('eaa_tryptophan_mg', 'eaa_tryptophan_g'),
      eaaValineMg: aa('eaa_valine_mg', 'eaa_valine_g'),
      aaArginineMg: aa('aa_arginine_mg', 'aa_arginine_g'),
      aaTyrosineMg: aa('aa_tyrosine_mg', 'aa_tyrosine_g'),
      aaCysteineMg: aa('aa_cysteine_mg', 'aa_cysteine_g'),
      aaGlycineMg: aa('aa_glycine_mg', 'aa_glycine_g'),
      aaProlineMg: aa('aa_proline_mg', 'aa_proline_g'),
      aaSerineMg: aa('aa_serine_mg', 'aa_serine_g'),
      aaGlutamineMg: aa('aa_glutamine_mg', 'aa_glutamine_g'),
      aaAlanineMg: aa('aa_alanine_mg', 'aa_alanine_g'),
      aaTaurineMg: aa('aa_taurine_mg', 'aa_taurine_g'),
      aaAsparticAcidMg: aa('aa_aspartic_acid_mg', 'aa_aspartic_acid_g'),
      aaGlutamicAcidMg: aa('aa_glutamic_acid_mg', 'aa_glutamic_acid_g'),
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
        eaaHistidineMg > 0 ||
        eaaIsoleucineMg > 0 ||
        eaaLeucineMg > 0 ||
        eaaLysineMg > 0 ||
        eaaMethionineMg > 0 ||
        eaaPhenylalanineMg > 0 ||
        eaaThreonineMg > 0 ||
        eaaTryptophanMg > 0 ||
        eaaValineMg > 0 ||
        aaArginineMg > 0 ||
        aaTyrosineMg > 0 ||
        aaCysteineMg > 0 ||
        aaGlycineMg > 0 ||
        aaProlineMg > 0 ||
        aaSerineMg > 0 ||
        aaGlutamineMg > 0 ||
        aaAlanineMg > 0 ||
        aaTaurineMg > 0 ||
        aaAsparticAcidMg > 0 ||
        aaGlutamicAcidMg > 0;
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
    (key: 'eaa_histidine_mg', label: 'ヒスチジン', unit: 'mg'),
    (key: 'eaa_isoleucine_mg', label: 'イソロイシン', unit: 'mg'),
    (key: 'eaa_leucine_mg', label: 'ロイシン', unit: 'mg'),
    (key: 'eaa_lysine_mg', label: 'リシン', unit: 'mg'),
    (key: 'eaa_methionine_mg', label: 'メチオニン', unit: 'mg'),
    (key: 'eaa_phenylalanine_mg', label: 'フェニルアラニン', unit: 'mg'),
    (key: 'eaa_threonine_mg', label: 'トレオニン', unit: 'mg'),
    (key: 'eaa_tryptophan_mg', label: 'トリプトファン', unit: 'mg'),
    (key: 'eaa_valine_mg', label: 'バリン', unit: 'mg'),
  ];

  static const List<({String key, String label, String unit})> editorFieldsOtherAa = [
    (key: 'aa_arginine_mg', label: 'アルギニン', unit: 'mg'),
    (key: 'aa_tyrosine_mg', label: 'チロシン', unit: 'mg'),
    (key: 'aa_cysteine_mg', label: 'システイン', unit: 'mg'),
    (key: 'aa_glycine_mg', label: 'グリシン', unit: 'mg'),
    (key: 'aa_proline_mg', label: 'プロリン', unit: 'mg'),
    (key: 'aa_serine_mg', label: 'セリン', unit: 'mg'),
    (key: 'aa_glutamine_mg', label: 'グルタミン', unit: 'mg'),
    (key: 'aa_alanine_mg', label: 'アラニン', unit: 'mg'),
    (key: 'aa_taurine_mg', label: 'タウリン', unit: 'mg'),
    (key: 'aa_aspartic_acid_mg', label: 'アスパラギン酸', unit: 'mg'),
    (key: 'aa_glutamic_acid_mg', label: 'グルタミン酸', unit: 'mg'),
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
