import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class AppPaths {
  final Directory root;

  AppPaths._(this.root);

  static Future<AppPaths> create() async {
    final supportDir = await getApplicationSupportDirectory();
    return AppPaths._(supportDir);
  }

  static AppPaths fromRootForTesting(Directory root) => AppPaths._(root);

  Directory get stCompat => Directory(p.join(root.path, 'st_compat'));
  Directory get soultalk => Directory(p.join(root.path, 'soultalk'));
  Directory get attachments => Directory(p.join(soultalk.path, 'attachments'));
  Directory get characters => Directory(p.join(stCompat.path, 'characters'));
  Directory get chats => Directory(p.join(stCompat.path, 'chats'));
  Directory get worlds => Directory(p.join(stCompat.path, 'worlds'));
  Directory get settings => Directory(p.join(stCompat.path, 'settings'));
  Directory get themes => Directory(p.join(stCompat.path, 'themes'));
  Directory get extensions => Directory(p.join(stCompat.path, 'extensions'));
  Directory get plugins => Directory(p.join(stCompat.path, 'plugins'));
  Directory get personas => Directory(p.join(stCompat.path, 'user'));
  Directory get groups => Directory(p.join(stCompat.path, 'groups'));
  Directory get avatars => Directory(p.join(stCompat.path, 'avatars'));
  Directory get thumbnails => Directory(p.join(stCompat.path, 'thumbnails'));
  Directory get cache => Directory(p.join(stCompat.path, '_cache'));

  Future<void> ensureInitialized() async {
    final directories = [
      stCompat,
      soultalk,
      attachments,
      characters,
      chats,
      worlds,
      settings,
      Directory(p.join(settings.path, 'KoboldAI Settings')),
      Directory(p.join(settings.path, 'NovelAI Settings')),
      Directory(p.join(settings.path, 'OpenAI Settings')),
      Directory(p.join(settings.path, 'TextGen Settings')),
      Directory(p.join(settings.path, 'instruct')),
      Directory(p.join(settings.path, 'context')),
      Directory(p.join(settings.path, 'sysprompt')),
      Directory(p.join(settings.path, 'reasoning')),
      themes,
      extensions,
      plugins,
      personas,
      groups,
      avatars,
      thumbnails,
      cache,
    ];

    for (final directory in directories) {
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
    }
  }
}
