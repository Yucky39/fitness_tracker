import 'dart:convert';

/// 可食部100gあたりのビタミン・ミネラル等（日本食品標準成分表の単位に準拠）
class Micronutrients {
  /// ビタミンA レチノール当量 μg
  final double vitaminAUg;
  final double vitaminDUg;
  final double vitaminEMg;
  final double vitaminKUg;
  final double vitaminB1Mg;
  final double vitaminB2Mg;
  final double niacinMg;
  final double vitaminB6Mg;
  final double vitaminB12Ug;
  final double folateUg;
  final double vitaminCMg;
  final double calciumMg;
  final double ironMg;
  final double zincMg;
  final double magnesiumMg;
  final double phosphorusMg;
  final double potassiumMg;
  final double copperMg;
  final double manganeseMg;

  const Micronutrients({
    this.vitaminAUg = 0,
    this.vitaminDUg = 0,
    this.vitaminEMg = 0,
    this.vitaminKUg = 0,
    this.vitaminB1Mg = 0,
    this.vitaminB2Mg = 0,
    this.niacinMg = 0,
    this.vitaminB6Mg = 0,
    this.vitaminB12Ug = 0,
    this.folateUg = 0,
    this.vitaminCMg = 0,
    this.calciumMg = 0,
    this.ironMg = 0,
    this.zincMg = 0,
    this.magnesiumMg = 0,
    this.phosphorusMg = 0,
    this.potassiumMg = 0,
    this.copperMg = 0,
    this.manganeseMg = 0,
  });

  static const zero = Micronutrients();

  /// レシピ編集UI・表示用（キーは [toMap] と一致）
  static const List<({String key, String label, String unit})> editorFields = [
    (key: 'vitamin_a_ug', label: 'ビタミンA', unit: 'μg'),
    (key: 'vitamin_d_ug', label: 'ビタミンD', unit: 'μg'),
    (key: 'vitamin_e_mg', label: 'ビタミンE', unit: 'mg'),
    (key: 'vitamin_k_ug', label: 'ビタミンK', unit: 'μg'),
    (key: 'vitamin_b1_mg', label: 'ビタミンB1', unit: 'mg'),
    (key: 'vitamin_b2_mg', label: 'ビタミンB2', unit: 'mg'),
    (key: 'niacin_mg', label: 'ナイアシン', unit: 'mg'),
    (key: 'vitamin_b6_mg', label: 'ビタミンB6', unit: 'mg'),
    (key: 'vitamin_b12_ug', label: 'ビタミンB12', unit: 'μg'),
    (key: 'folate_ug', label: '葉酸', unit: 'μg'),
    (key: 'vitamin_c_mg', label: 'ビタミンC', unit: 'mg'),
    (key: 'calcium_mg', label: 'カルシウム', unit: 'mg'),
    (key: 'iron_mg', label: '鉄', unit: 'mg'),
    (key: 'zinc_mg', label: '亜鉛', unit: 'mg'),
    (key: 'magnesium_mg', label: 'マグネシウム', unit: 'mg'),
    (key: 'phosphorus_mg', label: 'リン', unit: 'mg'),
    (key: 'potassium_mg', label: 'カリウム', unit: 'mg'),
    (key: 'copper_mg', label: '銅', unit: 'mg'),
    (key: 'manganese_mg', label: 'マンガン', unit: 'mg'),
  ];

  /// 正の値のみ、短い行リスト（食事サマリー等）
  List<String> summaryLines() {
    final m = toMap();
    final out = <String>[];
    for (final f in editorFields) {
      final v = (m[f.key] as num).toDouble();
      if (v > 0) {
        final vs = v >= 100
            ? v.toStringAsFixed(0)
            : (v >= 10 ? v.toStringAsFixed(1) : v.toStringAsFixed(2));
        out.add('${f.label} $vs ${f.unit}');
      }
    }
    return out;
  }

  Micronutrients scale(double factor) => Micronutrients(
        vitaminAUg: vitaminAUg * factor,
        vitaminDUg: vitaminDUg * factor,
        vitaminEMg: vitaminEMg * factor,
        vitaminKUg: vitaminKUg * factor,
        vitaminB1Mg: vitaminB1Mg * factor,
        vitaminB2Mg: vitaminB2Mg * factor,
        niacinMg: niacinMg * factor,
        vitaminB6Mg: vitaminB6Mg * factor,
        vitaminB12Ug: vitaminB12Ug * factor,
        folateUg: folateUg * factor,
        vitaminCMg: vitaminCMg * factor,
        calciumMg: calciumMg * factor,
        ironMg: ironMg * factor,
        zincMg: zincMg * factor,
        magnesiumMg: magnesiumMg * factor,
        phosphorusMg: phosphorusMg * factor,
        potassiumMg: potassiumMg * factor,
        copperMg: copperMg * factor,
        manganeseMg: manganeseMg * factor,
      );

  Micronutrients operator +(Micronutrients o) => Micronutrients(
        vitaminAUg: vitaminAUg + o.vitaminAUg,
        vitaminDUg: vitaminDUg + o.vitaminDUg,
        vitaminEMg: vitaminEMg + o.vitaminEMg,
        vitaminKUg: vitaminKUg + o.vitaminKUg,
        vitaminB1Mg: vitaminB1Mg + o.vitaminB1Mg,
        vitaminB2Mg: vitaminB2Mg + o.vitaminB2Mg,
        niacinMg: niacinMg + o.niacinMg,
        vitaminB6Mg: vitaminB6Mg + o.vitaminB6Mg,
        vitaminB12Ug: vitaminB12Ug + o.vitaminB12Ug,
        folateUg: folateUg + o.folateUg,
        vitaminCMg: vitaminCMg + o.vitaminCMg,
        calciumMg: calciumMg + o.calciumMg,
        ironMg: ironMg + o.ironMg,
        zincMg: zincMg + o.zincMg,
        magnesiumMg: magnesiumMg + o.magnesiumMg,
        phosphorusMg: phosphorusMg + o.phosphorusMg,
        potassiumMg: potassiumMg + o.potassiumMg,
        copperMg: copperMg + o.copperMg,
        manganeseMg: manganeseMg + o.manganeseMg,
      );

  Map<String, dynamic> toMap() => {
        'vitamin_a_ug': vitaminAUg,
        'vitamin_d_ug': vitaminDUg,
        'vitamin_e_mg': vitaminEMg,
        'vitamin_k_ug': vitaminKUg,
        'vitamin_b1_mg': vitaminB1Mg,
        'vitamin_b2_mg': vitaminB2Mg,
        'niacin_mg': niacinMg,
        'vitamin_b6_mg': vitaminB6Mg,
        'vitamin_b12_ug': vitaminB12Ug,
        'folate_ug': folateUg,
        'vitamin_c_mg': vitaminCMg,
        'calcium_mg': calciumMg,
        'iron_mg': ironMg,
        'zinc_mg': zincMg,
        'magnesium_mg': magnesiumMg,
        'phosphorus_mg': phosphorusMg,
        'potassium_mg': potassiumMg,
        'copper_mg': copperMg,
        'manganese_mg': manganeseMg,
      };

  factory Micronutrients.fromMap(Map<String, dynamic> m) {
    double g(String k) => (m[k] as num?)?.toDouble() ?? 0;
    return Micronutrients(
      vitaminAUg: g('vitamin_a_ug'),
      vitaminDUg: g('vitamin_d_ug'),
      vitaminEMg: g('vitamin_e_mg'),
      vitaminKUg: g('vitamin_k_ug'),
      vitaminB1Mg: g('vitamin_b1_mg'),
      vitaminB2Mg: g('vitamin_b2_mg'),
      niacinMg: g('niacin_mg'),
      vitaminB6Mg: g('vitamin_b6_mg'),
      vitaminB12Ug: g('vitamin_b12_ug'),
      folateUg: g('folate_ug'),
      vitaminCMg: g('vitamin_c_mg'),
      calciumMg: g('calcium_mg'),
      ironMg: g('iron_mg'),
      zincMg: g('zinc_mg'),
      magnesiumMg: g('magnesium_mg'),
      phosphorusMg: g('phosphorus_mg'),
      potassiumMg: g('potassium_mg'),
      copperMg: g('copper_mg'),
      manganeseMg: g('manganese_mg'),
    );
  }

  static Micronutrients? fromJsonString(String? json) {
    if (json == null || json.isEmpty) return null;
    try {
      final m = jsonDecode(json) as Map<String, dynamic>;
      return Micronutrients.fromMap(m);
    } catch (_) {
      return null;
    }
  }

  String toJsonString() => jsonEncode(toMap());

  /// いずれかが正の値か
  bool get hasAnyPositive {
    return vitaminAUg > 0 ||
        vitaminDUg > 0 ||
        vitaminEMg > 0 ||
        vitaminKUg > 0 ||
        vitaminB1Mg > 0 ||
        vitaminB2Mg > 0 ||
        niacinMg > 0 ||
        vitaminB6Mg > 0 ||
        vitaminB12Ug > 0 ||
        folateUg > 0 ||
        vitaminCMg > 0 ||
        calciumMg > 0 ||
        ironMg > 0 ||
        zincMg > 0 ||
        magnesiumMg > 0 ||
        phosphorusMg > 0 ||
        potassiumMg > 0 ||
        copperMg > 0 ||
        manganeseMg > 0;
  }
}
