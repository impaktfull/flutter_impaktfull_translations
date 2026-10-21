import 'package:locale_gen/locale_gen.dart';
import 'package:yaml/yaml.dart';

import '../locale/locale_tag.dart';

/// The pubspec section, and locale_gen's program name.
const programName = 'impaktfull_translations';

/// The production instance (spec 17.1).
const defaultHost = 'https://translations.impaktfull.com';

/// Where the README explains the setup, for every message that points there.
const readmeSetupUrl =
    'https://github.com/impaktfull/flutter_impaktfull_translations#setup';
const readmeMigrationUrl =
    'https://github.com/impaktfull/flutter_impaktfull_translations#migrating-from-0x';

/// The environment variables 1.0.0 reads.
const envApiKey = 'IMPAKTFULL_TRANSLATIONS_API_KEY';
const envProjectId = 'IMPAKTFULL_TRANSLATIONS_PROJECT_ID';
const envHost = 'IMPAKTFULL_TRANSLATIONS_HOST';

/// The 0.x variables, read only to explain why they no longer work.
const legacyEnvApiKey = 'IMPAKTFULL_TRANSLATIONS_TRANSLATION_APP_API_KEY';
const legacyEnvAppUuid = 'IMPAKTFULL_TRANSLATIONS_TRANSLATION_APP_UUID';

/// Every configuration problem found, reported together (spec 17.1: "all
/// problems are printed at once"), so a CI run that is wrong in three ways
/// takes one fix rather than three.
class ConfigException implements Exception {
  ConfigException(this.problems);

  final List<String> problems;

  @override
  String toString() => problems.join('\n');
}

/// The resolved configuration for one run.
class TranslationsConfig {
  TranslationsConfig._({
    required this.host,
    required this.projectId,
    required this.apiKey,
    required this.onlyApproved,
    required this.canonicalByLanguage,
    required this.localeGenParams,
    required this.notes,
  });

  /// The instance's origin, without a trailing slash.
  final Uri host;
  final String projectId;

  /// The bearer token. NEVER printed: use [apiKeyLabel].
  final String apiKey;
  final bool onlyApproved;

  /// Each language exactly as spelled in `languages`, to the canonical tag the
  /// server knows it by. Insertion order is the order of `languages`.
  final Map<String, String> canonicalByLanguage;
  final LocaleGenParams localeGenParams;

  /// Things worth saying that are not errors (ignored 0.x-era settings).
  final List<String> notes;

  List<String> get languages => canonicalByLanguage.keys.toList();
  String get localeAssetsDir => localeGenParams.localeAssetsDir;

  /// The key's public 8-character prefix, the only part of it that may be
  /// printed (it is what the API keys tab shows next to the key's name).
  String get apiKeyLabel => apiKeyPrefix(apiKey);

  /// The delivery URL for [locales] (canonical tags).
  Uri deliveryUri(List<String> locales) {
    final base = host.path.endsWith('/')
        ? host.path.substring(0, host.path.length - 1)
        : host.path;
    return host.replace(
      path: '$base/api/delivery/v1/translations',
      queryParameters: {
        'locales': locales.join(','),
        if (onlyApproved) 'onlyApproved': 'true',
      },
    );
  }

  /// Resolves the configuration from the pubspec, flags and environment.
  ///
  /// Order per field (spec 17.1): command-line flag, then `pubspec.yaml`,
  /// then the environment. The API key is the exception: it is read from the
  /// environment ONLY, because a key in `pubspec.yaml` is a key in git.
  static TranslationsConfig load({
    required String pubspecContent,
    required Map<String, String> environment,
    String? hostFlag,
    String? projectIdFlag,
  }) {
    final problems = <String>[];
    final notes = <String>[];

    final Object? doc;
    try {
      doc = loadYaml(pubspecContent);
    } on YamlException catch (e) {
      throw ConfigException(['pubspec.yaml is not valid YAML: ${e.message}']);
    }
    final section = doc is YamlMap ? doc[programName] : null;
    if (section is! YamlMap) {
      throw ConfigException([
        'pubspec.yaml has no `$programName:` section. Copy the snippet from '
            "your project's Settings > API keys tab in impaktfull translations, "
            'or see $readmeSetupUrl',
      ]);
    }

    // THE 0.x CONFIGURATION, named precisely. It is the most likely thing to
    // be in a pubspec the day an app upgrades, and "project_id is missing"
    // alone would not tell anybody that the two lines above it are the
    // reason.
    final legacy = [
      if (section.containsKey('api_key')) 'api_key',
      if (section.containsKey('app_uuid')) 'app_uuid',
    ];
    if (legacy.isNotEmpty) {
      problems.add(
        '${legacy.map((k) => '`$k`').join(' and ')} '
        '${legacy.length == 1 ? 'is' : 'are'} 0.x configuration for '
        'dashboard.impaktfull.com, which 1.0.0 no longer talks to. Under '
        '`$programName:` in pubspec.yaml:\n'
        '  - remove `api_key`, and set the new key (itk_...) as the '
        '$envApiKey environment variable instead (a CI secret in CI). '
        'A key never goes in pubspec.yaml.\n'
        '  - replace `app_uuid: ...` with `project_id: <project id>`.\n'
        "  Both are on your project's Settings > API keys tab in impaktfull "
        'translations. See $readmeMigrationUrl',
      );
    }

    // HOST
    final hostRaw = _string(hostFlag) ??
        _string(section['host']) ??
        _string(environment[envHost]) ??
        defaultHost;
    final host = _parseHost(hostRaw, problems);

    // PROJECT ID
    final projectId = _string(projectIdFlag) ??
        _string(section['project_id']) ??
        _string(environment[envProjectId]);
    if (projectId == null) {
      if (!section.containsKey('app_uuid')) {
        problems.add(
          '`project_id` is missing. Add `project_id: <project id>` under '
          "`$programName:` in pubspec.yaml; it is in the snippet on your project's "
          'Settings > API keys tab. See $readmeSetupUrl',
        );
      }
    } else if (!_uuid.hasMatch(projectId)) {
      problems.add('`project_id` "$projectId" is not a project id (a uuid).');
    }

    // API KEY, from the environment only.
    final apiKey = _string(environment[envApiKey]);
    if (apiKey == null) {
      final legacyKey = _string(environment[legacyEnvApiKey]) != null;
      problems.add(
        '$envApiKey is not set. Create a key on your project\'s Settings > '
        'API keys tab and set it as that environment variable (a CI secret in '
        'CI).'
        '${legacyKey ? ' $legacyEnvApiKey is set, but that is the 0.x variable and its keys do not work with impaktfull translations.' : ''}',
      );
    } else if (!_token.hasMatch(apiKey)) {
      // Not echoed, not even partly: a value of the wrong shape may be a
      // different secret pasted into the wrong variable.
      problems.add(
        '$envApiKey does not hold an impaktfull translations API key, which '
        'starts with `itk_`. A key from dashboard.impaktfull.com does not '
        "work: create a new one on your project's Settings > API keys tab.",
      );
    }
    if (_string(environment[legacyEnvAppUuid]) != null && projectId == null) {
      problems.add(
        '$legacyEnvAppUuid is the 0.x variable. Use `project_id` in '
        'pubspec.yaml (or $envProjectId) with the id from your project\'s '
        'Settings > API keys tab.',
      );
    }

    // ONLY APPROVED
    var onlyApproved = false;
    final onlyApprovedRaw = section['only_approved'];
    if (onlyApprovedRaw is bool) {
      onlyApproved = onlyApprovedRaw;
    } else if (onlyApprovedRaw == 'true' || onlyApprovedRaw == 'false') {
      onlyApproved = onlyApprovedRaw == 'true';
    } else if (onlyApprovedRaw != null) {
      problems.add('`only_approved` must be true or false.');
    }

    // RELEASE AND FALLBACK: accepted, because the server's own setup snippet
    // writes them (`release: draft`, `fallback: default`), and ignored,
    // because the server no longer has either. It delivers the project's
    // current state, and a missing translation is an empty string. Only a
    // value that EXPECTS something different gets a note.
    final release = section['release'];
    if (release != null && release.toString() != 'draft') {
      notes.add(
        '`release: $release` is ignored: impaktfull translations delivers the '
        "project's current state and has no releases. Remove the line.",
      );
    }
    final fallback = section['fallback'];
    if (fallback is YamlList ||
        (fallback != null &&
            fallback.toString() != 'default' &&
            fallback.toString() != 'none')) {
      notes.add(
        '`fallback: $fallback` is ignored: impaktfull translations does not '
        'fall back to another language; a missing translation is an empty '
        'string.',
      );
    }

    // LOCALE_GEN's own parameters, validated by locale_gen itself so the two
    // can never disagree about what a valid `languages` list is.
    LocaleGenParams? params;
    try {
      params = LocaleGenParams.fromYamlString(programName, pubspecContent);
    } catch (e) {
      problems.add(_message(e));
    }

    final canonicalByLanguage = <String, String>{};
    if (params != null) {
      final seen = <String, String>{};
      for (final language in params.languages) {
        final canonical = canonicalLocale(language);
        if (canonical == null) {
          problems.add(
            '`languages` contains "$language", which is not a locale tag '
            '(language[-Script][-REGION], for example nl, fr-BE or fr_BE).',
          );
          continue;
        }
        final earlier = seen[canonical];
        if (earlier != null) {
          problems.add(
            '`languages` contains "$earlier" and "$language", which are the '
            'same locale ($canonical).',
          );
          continue;
        }
        seen[canonical] = language;
        canonicalByLanguage[language] = canonical;
      }
    }

    if (problems.isNotEmpty) throw ConfigException(problems);

    return TranslationsConfig._(
      host: host!,
      projectId: projectId!,
      apiKey: apiKey!,
      onlyApproved: onlyApproved,
      canonicalByLanguage: canonicalByLanguage,
      localeGenParams: params!,
      notes: notes,
    );
  }

  static Uri? _parseHost(String raw, List<String> problems) {
    final uri = Uri.tryParse(raw);
    if (uri == null || uri.host.isEmpty || !uri.hasScheme) {
      problems.add(
        '`host` "$raw" is not a URL. Leave it out to use $defaultHost.',
      );
      return null;
    }
    if (uri.host == 'dashboard.impaktfull.com') {
      problems.add(
        '`host` points at dashboard.impaktfull.com, which no longer serves '
        'translations. Remove `host` to use $defaultHost.',
      );
      return null;
    }
    final local = uri.host == 'localhost' || uri.host == '127.0.0.1';
    if (uri.scheme != 'https' && !(uri.scheme == 'http' && local)) {
      problems.add(
        '`host` must start with https:// (http:// is allowed for localhost '
        'and 127.0.0.1 only).',
      );
      return null;
    }
    if (uri.hasQuery || uri.hasFragment) {
      problems.add('`host` "$raw" must not have a query or a fragment.');
      return null;
    }
    return uri;
  }
}

/// The public part of a key: `itk_` and the 8-character prefix the API keys
/// tab shows. Anything that is not shaped like a key prints as `(unknown)`.
String apiKeyPrefix(String token) {
  final match = _token.firstMatch(token);
  return match == null ? '(unknown)' : 'itk_${match.group(1)}';
}

/// `itk_<8 chars Crockford base32>_<secret>` (spec 9.2).
final RegExp _token = RegExp(r'^itk_([0-9A-Za-z]{8})_\S+$');
final RegExp _uuid = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

String? _string(Object? value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

String _message(Object error) {
  final text = error.toString();
  return text.startsWith('Exception: ') ? text.substring(11) : text;
}
