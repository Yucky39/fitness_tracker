import 'database_service.dart';
import 'auth_service.dart';

/// 買い物リスト集計用: DB の別名と、過去の出現回数（相対的な代表表記の決定に使用）
class IngredientMergeContext {
  const IngredientMergeContext({
    required this.surfaceToCanonical,
    required this.surfaceSeenCount,
  });

  /// 食材の表記 → ユーザーが紐づけた代表名（shopping_ingredient_aliases）
  final Map<String, String> surfaceToCanonical;

  /// 各表記が買い物リストに載った回数（shopping_ingredient_surface_stats）
  final Map<String, int> surfaceSeenCount;

  static const empty = IngredientMergeContext(
    surfaceToCanonical: {},
    surfaceSeenCount: {},
  );
}

/// ログイン中は Firebase UID、未ログインは端末ローカル用キー
String ingredientMergeUserKey() => AuthService().userId ?? 'local';

class IngredientMergeService {
  IngredientMergeService._();
  static final IngredientMergeService instance = IngredientMergeService._();

  Future<IngredientMergeContext> loadContext(String userId) async {
    final db = await DatabaseService().database;
    final aliasRows = await db.query(
      'shopping_ingredient_aliases',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    final statRows = await db.query(
      'shopping_ingredient_surface_stats',
      where: 'user_id = ?',
      whereArgs: [userId],
    );

    final aliases = <String, String>{};
    for (final r in aliasRows) {
      final s = r['surface']?.toString() ?? '';
      final c = r['canonical']?.toString() ?? '';
      if (s.isNotEmpty && c.isNotEmpty) {
        aliases[s] = c;
      }
    }

    final stats = <String, int>{};
    for (final r in statRows) {
      final s = r['surface']?.toString() ?? '';
      final n = r['seen_count'];
      final count = n is int ? n : int.tryParse(n?.toString() ?? '') ?? 0;
      if (s.isNotEmpty) {
        stats[s] = count;
      }
    }

    return IngredientMergeContext(
      surfaceToCanonical: aliases,
      surfaceSeenCount: stats,
    );
  }

  /// 買い物リストを開いたタイミングで、今回のメニューに出てきた表記ごとに回数を 1 加算（同一リスト内は表記ごとに1回）
  Future<void> recordSurfacesSeen(
    String userId,
    Iterable<String> surfaces,
  ) async {
    final db = await DatabaseService().database;
    final now = DateTime.now().toIso8601String();
    for (final raw in surfaces.toSet()) {
      final s = raw.trim();
      if (s.isEmpty) continue;

      final rows = await db.query(
        'shopping_ingredient_surface_stats',
        where: 'user_id = ?',
        whereArgs: [userId],
      );
      final match = rows
          .where((r) => (r['surface']?.toString() ?? '') == s)
          .toList();

      if (match.isEmpty) {
        await db.insert('shopping_ingredient_surface_stats', {
          'user_id': userId,
          'surface': s,
          'seen_count': 1,
          'last_seen': now,
        });
      } else {
        final prev = match.first['seen_count'];
        final prevN =
            prev is int ? prev : int.tryParse(prev?.toString() ?? '') ?? 0;
        await db.update(
          'shopping_ingredient_surface_stats',
          {
            'seen_count': prevN + 1,
            'last_seen': now,
          },
          where: 'user_id = ? AND surface = ?',
          whereArgs: [userId, s],
        );
      }
    }
  }

  /// 表記揺れを手動で代表名に紐づける（設定UIなどから呼ぶ想定）
  Future<void> upsertAlias(
    String userId, {
    required String surface,
    required String canonical,
  }) async {
    final db = await DatabaseService().database;
    final now = DateTime.now().toIso8601String();
    final s = surface.trim();
    final c = canonical.trim();
    if (s.isEmpty || c.isEmpty) return;

    final rows = await db.query(
      'shopping_ingredient_aliases',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    final exists =
        rows.any((r) => (r['surface']?.toString() ?? '') == s);
    if (exists) {
      await db.update(
        'shopping_ingredient_aliases',
        {
          'canonical': c,
          'updated_at': now,
        },
        where: 'user_id = ? AND surface = ?',
        whereArgs: [userId, s],
      );
    } else {
      await db.insert('shopping_ingredient_aliases', {
        'user_id': userId,
        'surface': s,
        'canonical': c,
        'updated_at': now,
      });
    }
  }

  Future<void> deleteAlias(String userId, String surface) async {
    final db = await DatabaseService().database;
    await db.delete(
      'shopping_ingredient_aliases',
      where: 'user_id = ? AND surface = ?',
      whereArgs: [userId, surface.trim()],
    );
  }
}
