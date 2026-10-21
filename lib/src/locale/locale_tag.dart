/// Locale tag canonicalisation, the same rules the server applies.
///
/// WHY THE CLI NEEDS ITS OWN COPY: the server answers with the CANONICAL tag
/// (`fr_be` in a query comes back as `fr-BE`), while the file has to be named
/// after the spelling in `languages` (`fr_BE.json`), because that is the name
/// locale_gen reads and the name an app has committed. Canonicalising here is
/// what lets the CLI map each answer back to the language it asked for.
///
/// It mirrors `LocaleTag.tryParse` in the server's core package: language,
/// optional script, optional region, `_` accepted as a separator, case
/// normalised per subtag position. If the two ever disagree, a request for
/// a locale would come back under a key the CLI does not expect, and the CLI
/// reports that rather than writing a wrong file.
library;

final RegExp _languagePattern = RegExp(r'^[a-z]{2,3}$');
final RegExp _scriptPattern = RegExp(r'^[A-Za-z]{4}$');
final RegExp _regionPattern = RegExp(r'^([A-Za-z]{2}|\d{3})$');

/// The canonical form of [input] (`nl_be` gives `nl-BE`), or null when it is
/// not a locale tag of the form `language[-Script][-REGION]`.
String? canonicalLocale(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return null;
  final parts = trimmed.replaceAll('_', '-').split('-');
  if (parts.length > 3) return null;

  final language = parts.first.toLowerCase();
  if (!_languagePattern.hasMatch(language)) return null;

  String? script;
  String? region;
  for (final raw in parts.skip(1)) {
    if (_scriptPattern.hasMatch(raw)) {
      if (script != null || region != null) return null;
      script = raw[0].toUpperCase() + raw.substring(1).toLowerCase();
      continue;
    }
    if (_regionPattern.hasMatch(raw)) {
      if (region != null) return null;
      region = raw.toUpperCase();
      continue;
    }
    return null;
  }
  return [language, if (script != null) script, if (region != null) region]
      .join('-');
}
