import '../websocket_client.dart';
import '../services/database/pc_mirror_dao.dart';

class PullSyncService {
  final WebSocketClient client;
  final PcMirrorDao mirrorDao;

  PullSyncService({required this.client, PcMirrorDao? mirrorDao})
    : mirrorDao = mirrorDao ?? PcMirrorDao();

  void requestManifest() {
    client.sendRaw({'type': 'manifest.request', 'payload': {}});
  }

  void requestTable(String table, {List<String>? ids, int limit = 500}) {
    final payload = <String, dynamic>{'table': table, 'limit': limit};
    if (ids != null) {
      payload['ids'] = ids;
    }
    client.sendRaw({'type': 'pull.request', 'payload': payload});
  }

  Future<void> handlePullChunk(Map<String, dynamic> event) async {
    final payload = (event['payload'] as Map?)?.cast<String, dynamic>();
    if (payload == null) return;
    final table = payload['table'] as String?;
    final rows = (payload['rows'] as List?)?.cast<Map>();
    if (table == null || rows == null) return;
    await mirrorDao.upsertRows(
      table,
      rows.map((row) => row.cast<String, dynamic>()).toList(),
    );
  }
}
