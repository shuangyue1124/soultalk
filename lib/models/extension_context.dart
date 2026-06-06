class ExtensionContext {
  final Map<String, dynamic> data;

  const ExtensionContext(this.data);

  Map<String, dynamic> toJson() => data;
}
