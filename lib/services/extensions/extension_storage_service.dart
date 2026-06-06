class ExtensionStorageService {
  final Map<String, Map<String, Object?>> _values = {};

  Object? getValue(String extensionId, String key) {
    return _values[extensionId]?[key];
  }

  void setValue(String extensionId, String key, Object? value) {
    _values.putIfAbsent(extensionId, () => <String, Object?>{})[key] = value;
  }

  void removeValue(String extensionId, String key) {
    _values[extensionId]?.remove(key);
  }

  Map<String, Object?> snapshot(String extensionId) {
    return Map<String, Object?>.unmodifiable(
      _values[extensionId] ?? const <String, Object?>{},
    );
  }
}
