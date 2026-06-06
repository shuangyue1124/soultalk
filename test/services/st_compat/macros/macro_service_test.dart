import 'package:flutter_test/flutter_test.dart';
import 'package:soultalk/services/st_compat/macros/macro_service.dart';

void main() {
  test('renders simple double-curly macros', () {
    final output = MacroService().render(
      '{{char}} greets {{user}} in {{scenario}}.',
      const MacroContext({
        'char': 'Alice',
        'user': 'Bob',
        'scenario': 'a cafe',
      }),
    );

    expect(output, 'Alice greets Bob in a cafe.');
  });

  test('renders if blocks when value is present', () {
    final output = MacroService().render(
      '{{#if system}}System: {{system}}{{/if}}{{#if empty}}Hidden{{/if}}',
      const MacroContext({'system': 'Be kind'}),
    );

    expect(output, 'System: Be kind');
  });

  test('turns trim macro into empty string', () {
    final output = MacroService().render('A{{trim}}B', const MacroContext({}));

    expect(output, 'AB');
  });
}
