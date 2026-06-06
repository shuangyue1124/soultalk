class PathSanitizer {
  static final RegExp _windowsReservedChars = RegExp(r'[<>:"/\\|?*\x00-\x1F]');
  static const Set<String> _reservedNames = {
    'con',
    'prn',
    'aux',
    'nul',
    'com1',
    'com2',
    'com3',
    'com4',
    'com5',
    'com6',
    'com7',
    'com8',
    'com9',
    'lpt1',
    'lpt2',
    'lpt3',
    'lpt4',
    'lpt5',
    'lpt6',
    'lpt7',
    'lpt8',
    'lpt9',
  };

  String fileName(String input, {String fallback = 'untitled'}) {
    var value = input.trim().replaceAll(_windowsReservedChars, '_');
    value = value.replaceAll(RegExp(r'\s+'), ' ');
    value = value.replaceAll(RegExp(r'[. ]+$'), '');

    if (value.isEmpty) return fallback;
    if (_reservedNames.contains(value.toLowerCase())) return '${value}_file';
    return value;
  }

  String relativePath(String input) {
    final normalized = input.replaceAll('\\', '/');
    final parts = normalized.split('/');
    final sanitizedParts = <String>[];

    for (final part in parts) {
      if (part.isEmpty || part == '.') continue;
      if (part == '..') {
        throw ArgumentError('Relative path cannot contain parent segments.');
      }
      sanitizedParts.add(fileName(part));
    }

    if (sanitizedParts.isEmpty) {
      throw ArgumentError('Relative path cannot be empty.');
    }
    return sanitizedParts.join('/');
  }
}
