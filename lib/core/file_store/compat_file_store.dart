import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../app_paths.dart';
import 'atomic_file_writer.dart';
import 'path_sanitizer.dart';

class CompatFileStore {
  final AppPaths paths;
  final PathSanitizer pathSanitizer;
  final AtomicFileWriter atomicFileWriter;

  CompatFileStore({
    required this.paths,
    PathSanitizer? pathSanitizer,
    AtomicFileWriter? atomicFileWriter,
  }) : pathSanitizer = pathSanitizer ?? PathSanitizer(),
       atomicFileWriter = atomicFileWriter ?? AtomicFileWriter();

  Future<void> initialize() => paths.ensureInitialized();

  File file(String relativePath) {
    final sanitized = pathSanitizer.relativePath(relativePath);
    final filePath = p.normalize(p.join(paths.root.path, sanitized));
    final rootPath = p.normalize(paths.root.path);
    if (!p.isWithin(rootPath, filePath) && filePath != rootPath) {
      throw ArgumentError('Path escapes application data directory.');
    }
    return File(filePath);
  }

  Future<void> writeBytes(String relativePath, Uint8List bytes) {
    return atomicFileWriter.writeAsBytes(file(relativePath), bytes);
  }

  Future<void> writeString(String relativePath, String contents) {
    return atomicFileWriter.writeAsString(file(relativePath), contents);
  }

  Future<Uint8List> readBytes(String relativePath) {
    return file(relativePath).readAsBytes();
  }

  Future<String> readString(String relativePath) {
    return file(relativePath).readAsString();
  }

  Future<bool> exists(String relativePath) {
    return file(relativePath).exists();
  }
}
