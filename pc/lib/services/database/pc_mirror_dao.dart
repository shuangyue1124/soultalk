import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'pc_database_service.dart';

class PcMirrorDao {
  final PcDatabaseService dbService;

  PcMirrorDao({PcDatabaseService? dbService})
    : dbService = dbService ?? PcDatabaseService();

  Future<Database> get _database => dbService.database;

  Future<void> upsertRows(String table, List<Map<String, dynamic>> rows) async {
    final db = await _database;
    final batch = db.batch();
    for (final row in rows) {
      final id = row['id']?.toString();
      if (id == null || id.isEmpty) continue;
      final json = jsonEncode(row);
      batch.insert('pc_mirror_rows', {
        'table_name': table,
        'id': id,
        'json': json,
        'updated_at': _timestamp(row),
        'hash': sha256.convert(utf8.encode(json)).toString(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getRows(String table) async {
    final db = await _database;
    final rows = await db.query(
      'pc_mirror_rows',
      where: 'table_name = ?',
      whereArgs: [table],
      orderBy: 'updated_at ASC, id ASC',
    );
    return rows
        .map(
          (row) => jsonDecode(row['json']! as String) as Map<String, dynamic>,
        )
        .toList();
  }

  int? _timestamp(Map<String, dynamic> row) {
    for (final key in const ['updated_at', 'created_at', 'timestamp']) {
      final value = row[key];
      if (value is int) return value;
      if (value is String) {
        return DateTime.tryParse(value)?.millisecondsSinceEpoch;
      }
    }
    return null;
  }
}
