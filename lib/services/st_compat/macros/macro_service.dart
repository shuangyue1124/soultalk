class MacroContext {
  final Map<String, String> values;

  const MacroContext(this.values);

  String valueOf(String key) => values[key] ?? '';
}

class MacroService {
  String render(String template, MacroContext context) {
    final withConditionals = _renderConditionals(template, context);
    return withConditionals.replaceAllMapped(
      RegExp(r'\{\{\s*([a-zA-Z0-9_]+)(?:::[^}]*)?\s*\}\}'),
      (match) {
        final key = match.group(1)!;
        if (key == 'trim') return '';
        return context.valueOf(key);
      },
    );
  }

  String _renderConditionals(String template, MacroContext context) {
    var result = template;
    final conditionalPattern = RegExp(
      r'\{\{#if\s+([a-zA-Z0-9_]+)\s*\}\}([\s\S]*?)\{\{/if\}\}',
      multiLine: true,
    );

    while (conditionalPattern.hasMatch(result)) {
      result = result.replaceAllMapped(conditionalPattern, (match) {
        final key = match.group(1)!;
        final body = match.group(2)!;
        return context.valueOf(key).isNotEmpty ? body : '';
      });
    }

    return result;
  }
}
