/// 同期・退会削除・Web初期化で使うテーブル一覧の唯一の正規定義。
///
/// 以前は sync_service / auth_service / database_web の3箇所に別々のリストが
/// あり、同期漏れ・削除漏れ・Web永続化バグの温床になっていた。ここに集約する。
class SyncTables {
  SyncTables._();

  /// Firestore のサブコレクションへレコード単位で同期するテーブル。
  /// マルチデバイスで共有すべきユーザーデータ。
  static const synced = <String>[
    'food_items',
    'training_logs',
    'body_metrics',
    'water_logs',
    'sleep_logs',
    'achievements',
    'training_plans',
    'meal_presets',
    'training_routines',
    'training_session_records',
  ];

  /// 端末ローカル限定のキャッシュ／派生データ。クラウド同期しない。
  /// （アニメーションキャッシュ・買い物リストの表記ゆれ統計）
  static const localOnly = <String>[
    'exercise_animations',
    'shopping_ingredient_aliases',
    'shopping_ingredient_surface_stats',
  ];

  /// アプリが利用する全ローカルテーブル（Web初期化・退会時のローカル全消去用）。
  static const all = <String>[
    ...synced,
    ...localOnly,
  ];
}
