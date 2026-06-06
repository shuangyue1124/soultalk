import 'dart:io';
import 'dart:typed_data';

class AtomicFileWriter {
  Future<void> writeAsBytes(File target, Uint8List bytes) async {
    await target.parent.create(recursive: true);
    final temp = File(
      '${target.path}.tmp.${DateTime.now().microsecondsSinceEpoch}',
    );
    await temp.writeAsBytes(bytes, flush: true);
    if (await target.exists()) {
      await target.delete();
    }
    await temp.rename(target.path);
  }

  Future<void> writeAsString(File target, String contents) async {
    await target.parent.create(recursive: true);
    final temp = File(
      '${target.path}.tmp.${DateTime.now().microsecondsSinceEpoch}',
    );
    await temp.writeAsString(contents, flush: true);
    if (await target.exists()) {
      await target.delete();
    }
    await temp.rename(target.path);
  }
}
