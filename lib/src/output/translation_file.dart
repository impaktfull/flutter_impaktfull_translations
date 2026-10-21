import 'dart:convert';

/// The bytes of one `<language>.json` file.
///
/// BYTE FOR BYTE what 0.x wrote, because every consuming app has those files
/// committed and switching to 1.0.0 must produce no diff: keys sorted with
/// `String.compareTo`, two-space indentation from `JsonEncoder.withIndent`,
/// and NO trailing newline. `test/translation_file_test.dart` pins this
/// against 0.x's own algorithm, copied verbatim.
///
/// WHAT 0.x DID THAT THIS DOES NOT:
///
///  - It ran `replaceAll(r'\\n', r'\n')` over the raw response, turning a
///    literal backslash-n into a newline. The server applied that exact
///    transformation once, to the stored values, when the data was imported
///    (its ADR-0013), so the values arrive with real newlines and are written
///    exactly as delivered. Doing it again here would change any value that
///    genuinely contains a backslash followed by an `n`.
///  - It called `toString()` on every value, which turned a plural object
///    into the text `{one: ..., other: ...}`. A plural key is now written as
///    the nested object locale_gen expects, forms in the order the server
///    sends them (canonical CLDR order).
String encodeTranslationFile(Map<String, Object?> translations) {
  final keys = translations.keys.toList()..sort((a, b) => a.compareTo(b));
  final sorted = <String, Object?>{
    for (final key in keys) key: _value(translations[key]),
  };
  return const JsonEncoder.withIndent('  ').convert(sorted);
}

Object _value(Object? value) {
  if (value is String) return value;
  if (value == null) return '';
  if (value is Map) {
    return <String, Object>{
      for (final entry in value.entries)
        entry.key.toString(): _value(entry.value),
    };
  }
  // Never sent by the server today. 0.x stringified anything that was not a
  // string, so a number would have been written as its text; keep that.
  return value.toString();
}

/// Whether a delivered value is empty: `""` for text, an empty `other` for a
/// plural. The server sends a missing translation in exactly that shape.
bool isEmptyTranslation(Object? value) {
  if (value == null) return true;
  if (value is String) return value.isEmpty;
  if (value is Map) {
    final other = value['other'];
    return other == null || (other is String && other.isEmpty);
  }
  return false;
}
