import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:soultalk/core/app_paths.dart';
import 'package:soultalk/services/database/attachment_index_dao.dart';
import 'package:soultalk/services/database/database_service.dart';
import 'package:soultalk/services/database/migrations/migration_v8.dart';
import 'package:soultalk/services/file_send/attachment_service.dart';

void main() {
  late Directory root;
  late Database db;
  late DatabaseService dbService;

  setUp(() async {
    sqfliteFfiInit();
    root = await Directory.systemTemp.createTemp('attachment_service_test_');
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await migrateV8(db);
    dbService = _TestDatabaseService(db);
  });

  tearDown(() async {
    await db.close();
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('imports file into managed attachments and indexes it', () async {
    final source = File('${root.path}/hello.png');
    final bytes = utf8.encode('image bytes');
    await source.writeAsBytes(bytes);

    final dao = AttachmentIndexDao(dbService);
    final service = AttachmentService(
      paths: AppPaths.fromRootForTesting(root),
      attachmentIndexDao: dao,
    );

    final record = await service.importFile(
      chatId: 'chat-1',
      source: source,
      mimeType: 'image/png',
    );

    final imported = File('${root.path}/${record.relativePath}');
    expect(await imported.exists(), isTrue);
    expect(await imported.readAsBytes(), bytes);
    expect(record.chatId, 'chat-1');
    expect(record.originalName, 'hello.png');
    expect(record.mimeType, 'image/png');
    expect(record.size, bytes.length);
    expect(record.sha256, sha256.convert(bytes).toString());

    final indexed = await dao.getById(record.id);
    expect(indexed, isNotNull);
    expect(indexed!.relativePath, record.relativePath);

    await service.attachToMessage(attachmentId: record.id, messageId: 'msg-1');
    expect((await dao.getById(record.id))!.messageId, 'msg-1');

    expect(service.toChatExtra(record), {
      'id': record.id,
      'name': 'hello.png',
      'mime': 'image/png',
      'relative_path': record.relativePath,
      'size': bytes.length,
      'sha256': record.sha256,
    });
  });

  test('infers common image mime types', () {
    expect(AttachmentService.inferMimeType('a.jpg'), 'image/jpeg');
    expect(AttachmentService.inferMimeType('a.jpeg'), 'image/jpeg');
    expect(AttachmentService.inferMimeType('a.png'), 'image/png');
    expect(AttachmentService.inferMimeType('a.gif'), 'image/gif');
    expect(AttachmentService.inferMimeType('a.webp'), 'image/webp');
    expect(AttachmentService.inferMimeType('a.bin'), isNull);
  });

  test(
    'sanitizes chat id before using it as an attachment directory',
    () async {
      final source = File('${root.path}/note.txt');
      await source.writeAsString('hello');

      final dao = AttachmentIndexDao(dbService);
      final service = AttachmentService(
        paths: AppPaths.fromRootForTesting(root),
        attachmentIndexDao: dao,
      );

      final record = await service.importFile(
        chatId: 'chat/../../evil:room',
        source: source,
        mimeType: 'text/plain',
      );

      expect(record.chatId, 'chat/../../evil:room');
      expect(record.relativePath.split('/'), isNot(contains('..')));
      expect(
        record.relativePath,
        startsWith('soultalk/attachments/chat_.._.._evil_room/'),
      );
      expect(
        await File('${root.path}/${record.relativePath}').exists(),
        isTrue,
      );
    },
  );
}

class _TestDatabaseService implements DatabaseService {
  final Database _database;

  _TestDatabaseService(this._database);

  @override
  Future<Database> get database async => _database;

  @override
  Future<void> close() async {}
}
