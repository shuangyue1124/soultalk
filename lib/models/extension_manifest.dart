class ExtensionManifest {
  final String id;
  final String displayName;
  final String? version;
  final String? author;
  final int loadingOrder;
  final List<String> js;
  final List<String> css;
  final List<String> requires;
  final List<String> optional;
  final Map<String, dynamic> raw;

  const ExtensionManifest({
    required this.id,
    required this.displayName,
    required this.version,
    required this.author,
    required this.loadingOrder,
    required this.js,
    required this.css,
    required this.requires,
    required this.optional,
    required this.raw,
  });

  factory ExtensionManifest.fromJson(Map<String, dynamic> json) {
    final displayName =
        json['display_name'] as String? ??
        json['displayName'] as String? ??
        json['name'] as String?;
    if (displayName == null || displayName.trim().isEmpty) {
      throw const FormatException('Extension display_name is required');
    }
    final id = json['id'] as String? ?? _stableId(displayName);
    final js = _stringList(json['js'] ?? json['scripts']);
    if (js.isEmpty) {
      throw const FormatException('Extension js entry is required');
    }
    return ExtensionManifest(
      id: id,
      displayName: displayName,
      version: json['version'] as String?,
      author: json['author'] as String?,
      loadingOrder:
          json['loading_order'] as int? ?? json['loadingOrder'] as int? ?? 0,
      js: js,
      css: _stringList(json['css']),
      requires: _stringList(json['requires']),
      optional: _stringList(json['optional']),
      raw: Map<String, dynamic>.from(json),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'display_name': displayName,
    'version': version,
    'author': author,
    'loading_order': loadingOrder,
    'js': js,
    'css': css,
    'requires': requires,
    'optional': optional,
    'raw': raw,
  };

  static List<String> _stringList(Object? value) {
    if (value == null) return const [];
    if (value is String) return [value];
    if (value is List) return value.whereType<String>().toList();
    return const [];
  }

  static String _stableId(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }
}
