import 'package:sqflite/sqflite.dart';

import '../services/database/database_service.dart';

class SyncExporter {
  final DatabaseService dbService;

  const SyncExporter({required this.dbService});

  Future<Map<String, dynamic>> exportRows({
    required String table,
    List<String>? ids,
    int limit = 500,
  }) async {
    if (!_allowedTables.contains(table)) {
      throw ArgumentError.value(table, 'table', 'Table is not syncable');
    }
    final db = await dbService.database;
    final rows = await _queryRows(db, table, ids, limit);
    return {
      'table': table,
      'rows': rows,
      'hasMore': ids == null && rows.length == limit,
      'exportedAt': DateTime.now().toIso8601String(),
    };
  }

  Future<List<Map<String, Object?>>> _queryRows(
    Database db,
    String table,
    List<String>? ids,
    int limit,
  ) {
    if (ids == null || ids.isEmpty) {
      return db.query(table, orderBy: 'id ASC', limit: limit);
    }
    final placeholders = List.filled(ids.length, '?').join(',');
    return db.query(
      table,
      where: 'id IN ($placeholders)',
      whereArgs: ids,
      orderBy: 'id ASC',
      limit: limit,
    );
  }

  static const _allowedTables = {
    'contacts',
    'messages',
    'moments',
    'chat_presets',
    'regex_scripts',
    'memory_entries',
    'memory_states',
    'memory_cards',
  };
}
