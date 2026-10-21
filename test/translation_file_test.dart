import 'dart:convert';
import 'dart:io';

import 'package:impaktfull_translations/impaktfull_translations.dart';
import 'package:test/test.dart';

/// 0.1.0's file format, COPIED VERBATIM from
/// `lib/src/translation_downloader/json/json_translation_downloader.dart` at
/// v0.1.0 (only the file write is replaced by a return).
///
/// It is the reference every consuming app's committed files were written
/// with. 1.0.0 must produce the same bytes for the same strings, so that
/// switching an app is a pubspec change and not a translation diff.
String legacyEncode(String jsonString) {
  const encoder = JsonEncoder.withIndent('  ');
  final changedBody = jsonString.replaceAll(r'\\n', r'\n');
  final body = json.decode(changedBody) as Map<String, dynamic>;
  final keys = body.keys.toList();
  keys.sort((a, b) => a.compareTo(b));
  final translations = <String, String>{};
  for (final key in keys) {
    translations[key] = body[key].toString();
  }
  return encoder.convert(translations);
}

void main() {
  group('byte-identical to 0.1.0', () {
    // What the OLD dashboard sent: values with a literal backslash-n where a
    // newline was meant, which 0.1.0 turned into a newline.
    final legacyBody = jsonEncode({
      'welcome_message': 'Welcome to the impaktfull translations test app',
      'test': 'Testing in English',
      'b.key': 'Bonjour',
      'a.key': 'Aanmelden',
      'A.upper': 'Upper case sorts before lower case',
      'test_arg4': r'Testing argument %1$s %2$d %1$s',
      'test_new_line': r'Testing\nargument\n\n%1$s',
      'test_crlf': 'Carriage\r\nReturn',
      'quotes': 'She said "hi" and \'bye\'',
      'html': '<b>bold</b> &amp; <a href="https://x.y/?a=1&b=2">link</a>',
      'unicode': 'Café, Ærøskøbing, 日本語, emoji 🎉',
      'slash': 'a/b\\c',
      'tab': 'a\tb',
      'empty': '',
      'percent': r'100% sure, %.02f, %s',
    });

    // What the NEW server sends for the same strings: the import applied
    // 0.1.0's backslash-n replacement once to the stored values (server
    // ADR-0013), so the values arrive with real newlines.
    final delivered = (jsonDecode(legacyBody.replaceAll(r'\\n', r'\n'))
            as Map<String, dynamic>)
        .cast<String, Object?>();

    test('the same strings give the same bytes', () {
      expect(encodeTranslationFile(delivered), legacyEncode(legacyBody));
    });

    test('no trailing newline, two-space indent, sorted keys', () {
      final out = encodeTranslationFile(delivered);
      expect(out.endsWith('}'), isTrue);
      expect(out.split('\n')[1], startsWith('  "A.upper"'));
    });

    test('the delivery order does not matter', () {
      final reversed = Map.fromEntries(delivered.entries.toList().reversed);
      expect(encodeTranslationFile(reversed), legacyEncode(legacyBody));
    });

    // The files 0.1.0 wrote for the example app, read back and written again.
    for (final name in ['en', 'nl']) {
      test('example/assets/localization/$name.json round-trips', () {
        final file = File('example/assets/localization/$name.json');
        final bytes = file.readAsStringSync();
        final parsed =
            (jsonDecode(bytes) as Map<String, dynamic>).cast<String, Object?>();
        expect(encodeTranslationFile(parsed), bytes);
      });
    }
  });

  group('where 1.0.0 deliberately differs from 0.1.0', () {
    test('values are written as delivered: no second backslash-n pass', () {
      // A value that REALLY contains a backslash and an n (a Windows path in
      // help text, say). 0.1.0 would have turned it into a newline every
      // build; the server already did the one-time conversion at import.
      final out = encodeTranslationFile({'path': r'C:\new'});
      expect((jsonDecode(out) as Map)['path'], r'C:\new');
    });

    test('a plural key stays a nested object, forms in delivered order', () {
      final out = encodeTranslationFile({
        'cart.items': {'one': r'%1$d artikel', 'other': r'%1$d artikelen'},
        'a': 'x',
      });
      expect(
        out,
        '{\n'
        '  "a": "x",\n'
        '  "cart.items": {\n'
        '    "one": "%1\$d artikel",\n'
        '    "other": "%1\$d artikelen"\n'
        '  }\n'
        '}',
      );
    });
  });
}
