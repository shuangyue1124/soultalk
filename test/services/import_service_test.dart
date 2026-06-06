import 'package:flutter_test/flutter_test.dart';
import 'package:soultalk/services/import/import_service.dart';

void main() {
  group('ImportService', () {
    group('BOM handling', () {
      test('accepts character card with UTF-8 BOM', () {
        final content = '''${String.fromCharCodes([0xFEFF])}{
          "spec": "chara_card_v2",
          "spec_version": "2.0",
          "data": {
            "name": "TestChar",
            "description": "A test character"
          }
        }''';

        final result = ImportService.validateCharacterCard(content);

        expect(result.isValid, isTrue);
        expect(result.warning, contains('V2'));
      });
    });

    group('validateCharacterCard', () {
      test('accepts valid V2 card', () {
        final json = '''{
          "spec": "chara_card_v2",
          "spec_version": "2.0",
          "data": {
            "name": "TestChar",
            "description": "A test character"
          }
        }''';

        final result = ImportService.validateCharacterCard(json);

        expect(result.isValid, isTrue);
        expect(result.warning, contains('V2'));
      });

      test('accepts valid V3 card', () {
        final json = '''{
          "spec": "chara_card_v3",
          "spec_version": "3.0",
          "data": {
            "name": "V3Char",
            "description": "V3 desc"
          }
        }''';

        final result = ImportService.validateCharacterCard(json);

        expect(result.isValid, isTrue);
        expect(result.warning, contains('V3'));
      });

      test('rejects card without name', () {
        final json = '''{
          "data": {
            "description": "No name"
          }
        }''';

        final result = ImportService.validateCharacterCard(json);

        expect(result.isValid, isFalse);
        expect(result.error, contains('name'));
      });

      test('rejects empty content', () {
        final result = ImportService.validateCharacterCard('');

        expect(result.isValid, isFalse);
        expect(result.error, contains('空'));
      });

      test('rejects invalid JSON', () {
        final result = ImportService.validateCharacterCard('{invalid json}');

        expect(result.isValid, isFalse);
        expect(result.error, contains('JSON'));
      });

      test('rejects non-object data field', () {
        final json = '''{
          "data": "not an object"
        }''';

        final result = ImportService.validateCharacterCard(json);

        expect(result.isValid, isFalse);
        expect(result.error, contains('data'));
      });

      test('handles BOM in content', () {
        final bom = String.fromCharCodes([0xFEFF]);
        final json = '$bom{"data":{"name":"Test"}}';

        final result = ImportService.validateCharacterCard(json);

        expect(result.isValid, isTrue);
      });

      test('accepts V1 format (flat object)', () {
        final json = '''{
          "name": "V1Char",
          "char_description": "Old format"
        }''';

        final result = ImportService.validateCharacterCard(json);

        expect(result.isValid, isTrue);
        expect(result.warning, contains('V1'));
      });
    });

    group('validateRegexScripts', () {
      test('accepts valid script array', () {
        final json = '''[
          {
            "scriptName": "test",
            "findRegex": "hello",
            "replaceString": "world"
          }
        ]''';

        final result = ImportService.validateRegexScripts(json);

        expect(result.isValid, isTrue);
        expect(result.data!['scripts'], isA<List>());
      });

      test('rejects invalid regex pattern', () {
        final json = '''[
          {
            "scriptName": "test",
            "findRegex": "",
            "replaceString": "world"
          }
        ]''';

        final result = ImportService.validateRegexScripts(json);

        expect(result.isValid, isFalse);
      });

      test('handles single script object', () {
        final json = '''{
          "scriptName": "test",
          "findRegex": "hello",
          "replaceString": "world"
        }''';

        final result = ImportService.validateRegexScripts(json);

        expect(result.isValid, isTrue);
      });

      test('handles numbered key format (SillyTavern export)', () {
        final json = '''{
          "0": {
            "scriptName": "test1",
            "findRegex": "hello",
            "replaceString": "world"
          },
          "1": {
            "scriptName": "test2",
            "findRegex": "foo",
            "replaceString": "bar"
          }
        }''';

        final result = ImportService.validateRegexScripts(json);

        expect(result.isValid, isTrue);
      });
    });

    group('validatePreset', () {
      test('accepts valid preset with segments', () {
        final json = '''{
          "name": "TestPreset",
          "segments": [{"role": "system", "content": "Hello", "enabled": true}]
        }''';

        final result = ImportService.validatePreset(json);

        expect(result.isValid, isTrue);
      });

      test('rejects preset without segments', () {
        final json = '''{"name": "EmptyPreset"}''';

        final result = ImportService.validatePreset(json);

        expect(result.isValid, isFalse);
      });
    });
  });
}
