import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soultalk/pc_connect/pairing_store.dart';
import 'package:soultalk/pc_connect/protocol.dart';
import 'package:soultalk/pc_connect/push/push_validator.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('encodes and decodes protocol envelope', () {
    final envelope = LanSyncEnvelope(
      v: 1,
      id: '1',
      type: 'manifest.request',
      deviceId: 'pc-1',
      sentAt: '2026-05-24T00:00:00Z',
      payload: {'hello': 'world'},
    );

    final decoded = LanSyncEnvelope.decode(envelope.encode());

    expect(decoded.v, 1);
    expect(decoded.type, 'manifest.request');
    expect(decoded.deviceId, 'pc-1');
    expect(decoded.payload['hello'], 'world');
  });

  test('approves verifies and revokes paired device', () async {
    final store = PairingStore();

    final device = await store.approve(
      deviceId: 'pc-1',
      deviceName: 'PC',
      deviceKey: 'secret',
    );

    expect(device.revoked, isFalse);
    expect(await store.verify('pc-1', 'secret'), isTrue);
    expect(await store.verify('pc-1', 'wrong'), isFalse);

    await store.revoke('pc-1');
    expect(await store.verify('pc-1', 'secret'), isFalse);
  });

  test('push validator allows only guarded message inserts', () {
    final validator = PushValidator();

    expect(
      validator.validate({
        'table': 'messages',
        'operation': 'insert',
        'row': {'content': 'hello'},
      }).allowed,
      isTrue,
    );
    expect(
      validator.validate({
        'table': 'api_configs',
        'operation': 'insert',
        'row': {'api_key': 'secret'},
      }).reason,
      'table_not_allowed',
    );
    expect(
      validator.validate({
        'table': 'messages',
        'operation': 'delete',
        'row': {'content': 'hello'},
      }).reason,
      'operation_not_allowed',
    );
    expect(
      validator.validate({
        'table': 'messages',
        'operation': 'insert',
        'row': {'content': 'hello', 'api_key': 'secret'},
      }).reason,
      'secret_field_not_allowed',
    );
  });
}
