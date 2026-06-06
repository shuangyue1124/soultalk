import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';

import '../../services/database/database_service.dart';

class SyncTableManifest {
  final String table;
  final int rowCount;
  final String hash;
  final int? maxTimestamp;

  const SyncTableManifest({
    required this.table,
    required this.rowCount,
    required this.hash,
    required this.maxTimestamp,
  });

  Map<String, dynamic> toJson() => {
    'table': table,
    'rowCount': rowCount,
    'hash': hash,
    'maxTimestamp': maxTimestamp,
  };
}

class SyncManifestBuilder {
  final DatabaseService dbService;

  const SyncManifestBuilder({required this.dbService});

  Future<Map<String, dynamic>> build() async {
    final db = await dbService.database;
    final tables = <String>[
      'contacts',
      'messages',
      'moments',
      'chat_presets',
      'regex_scripts',
      'memory_entries',
      'memory_states',
      'memory_cards',
    ];
    final manifests = <Map<String, dynamic>>[];
    for (final table in tables) {
      manifests.add((await _buildTableManifest(db, table)).toJson());
    }
    return {
      'app': 'soultalk',
      'version': 1,
      'generatedAt': DateTime.now().toIso8601String(),
      'tables': manifests,
    };
  }

  Future<SyncTableManifest> _buildTableManifest(
    Database db,
    String table,
  ) async {
    final rows = await db.query(table, orderBy: 'id ASC');
    final encodedRows = rows.map((row) => jsonEncode(row)).join('\n');
    final maxTimestamp = _maxTimestamp(rows);
    return SyncTableManifest(
      table: table,
      rowCount: rows.length,
      hash: sha256.convert(utf8.encode(encodedRows)).toString(),
      maxTimestamp: maxTimestamp,
    );
  }

  int? _maxTimestamp(List<Map<String, Object?>> rows) {
    int? max;
    for (final row in rows) {
      for (final key in const ['updated_at', 'created_at', 'last_message_at']) {
        final value = row[key];
        final millis = value is int
            ? value
            : value is String
            ? DateTime.tryParse(value)?.millisecondsSinceEpoch
            : null;
        if (millis != null && (max == null || millis > max)) max = millis;
      }
    }
    return max;
  }
}
