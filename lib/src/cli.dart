import 'dart:io';

import 'package:args/args.dart';
import 'package:http/http.dart' as http;
import 'package:locale_gen/locale_gen.dart';
import 'package:path/path.dart' as p;

import 'config/translations_config.dart';
import 'delivery/delivery_client.dart';
import 'output/translation_file.dart';

/// Keep in step with `version:` in pubspec.yaml; `test/version_test.dart`
/// fails when they differ.
const packageVersion = '1.0.0';

/// The exit codes of spec 17.3.
abstract final class ExitCodes {
  static const success = 0;
  static const checkFoundDifferences = 1;
  static const configuration = 2;
  static const network = 3;
  static const localeGen = 4;
}

/// `dart run impaktfull_translations [--check] [--verbose]`.
class ImpaktfullTranslations {
  ImpaktfullTranslations({
    http.Client? httpClient,
    Map<String, String>? environment,
    Directory? workingDirectory,
    void Function(LocaleGenParams params)? generate,
    void Function(String line)? out,
    void Function(String line)? err,
  })  : _httpClient = httpClient,
        _environment = environment ?? Platform.environment,
        _workingDirectory = workingDirectory ?? Directory.current,
        _generate = generate ?? LocaleGenWriter.write,
        _out = out ?? print,
        _err = err ?? ((line) => stderr.writeln(line));

  final http.Client? _httpClient;
  final Map<String, String> _environment;
  final Directory _workingDirectory;
  final void Function(LocaleGenParams params) _generate;
  final void Function(String line) _out;
  final void Function(String line) _err;

  static ArgParser get _parser => ArgParser()
    ..addFlag(
      'check',
      negatable: false,
      help: 'Compare the translations on the server with the files on disk, '
          'write nothing, and exit 1 when they differ.',
    )
    ..addFlag(
      'verbose',
      abbr: 'v',
      negatable: false,
      help: 'List the empty and deprecated keys behind each warning.',
    )
    ..addOption('host', help: 'Overrides `host` in pubspec.yaml.')
    ..addOption('project-id', help: 'Overrides `project_id` in pubspec.yaml.')
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show this help.');

  /// Runs the CLI and returns its exit code.
  Future<int> run(List<String> args) async {
    final ArgResults options;
    try {
      options = _parser.parse(args);
    } on FormatException catch (e) {
      _err('${e.message}\n\n${_usage()}');
      return ExitCodes.configuration;
    }
    if (options.flag('help')) {
      _out(_usage());
      return ExitCodes.success;
    }
    final check = options.flag('check');
    final verbose = options.flag('verbose');

    // 1. CONFIGURATION, every problem at once.
    final pubspec = File(p.join(_workingDirectory.path, 'pubspec.yaml'));
    if (!pubspec.existsSync()) {
      _err('No pubspec.yaml here. Run $programName from the root of your '
          'Flutter or Dart project.');
      return ExitCodes.configuration;
    }
    final TranslationsConfig config;
    try {
      config = TranslationsConfig.load(
        pubspecContent: pubspec.readAsStringSync(),
        environment: _environment,
        hostFlag: options.option('host'),
        projectIdFlag: options.option('project-id'),
      );
    } on ConfigException catch (e) {
      _err('$programName: the configuration is not valid.');
      for (final problem in e.problems) {
        _err('\n- $problem');
      }
      return ExitCodes.configuration;
    }
    for (final note in config.notes) {
      _out('Note: $note');
    }

    // Created BEFORE anything else (spec 17.2 step 1): 0.x fetched first and
    // created the folder afterwards, so a first run crashed writing into a
    // folder that did not exist yet.
    final localeDir =
        Directory(p.join(_workingDirectory.path, config.localeAssetsDir));
    if (!check && !localeDir.existsSync()) {
      _out('Creating ${config.localeAssetsDir}');
      localeDir.createSync(recursive: true);
    }

    // 2. ONE REQUEST for every language.
    final canonical = config.canonicalByLanguage.values.toList();
    _out('Fetching ${config.languages.join(', ')} from ${config.host} '
        '(key ${config.apiKeyLabel})');
    final client = _httpClient ?? http.Client();
    final DeliveryResponse response;
    try {
      response = await DeliveryClient(
        client,
        userAgent: '$programName/$packageVersion',
      ).fetch(config, canonical);
    } on DeliveryException catch (e) {
      _err(e.message);
      return ExitCodes.network;
    } finally {
      if (_httpClient == null) client.close();
    }

    // A KEY FOR ANOTHER PROJECT is the one mistake the server cannot see:
    // the key alone picks the project, so it would happily deliver the wrong
    // app's strings. `project_id` is what makes that a loud failure.
    if (response.projectId != null &&
        response.projectId!.toLowerCase() != config.projectId.toLowerCase()) {
      _err('The API key ${config.apiKeyLabel} belongs to project '
          '${response.projectId}, but `project_id` is ${config.projectId}. '
          "Use a key created on this project's Settings > API keys tab, or "
          'fix `project_id`.');
      return ExitCodes.configuration;
    }

    // 3. MAP BACK to the spelling in `languages`.
    final files = <String, String>{};
    final empty = <String, List<String>>{};
    for (final MapEntry(key: language, value: tag)
        in config.canonicalByLanguage.entries) {
      final translations = response.locales[tag];
      if (translations == null) {
        _err('The server did not return $tag (for "$language").');
        return ExitCodes.network;
      }
      files[language] = encodeTranslationFile(translations);
      empty[language] = [
        for (final entry in translations.entries)
          if (isEmptyTranslation(entry.value)) entry.key,
      ]..sort();
    }

    final keyCount = response.keyCount ??
        (response.locales.isEmpty ? 0 : response.locales.values.first.length);
    _out('$keyCount keys · ${config.languages.join(', ')}');
    _warnings(empty, response.deprecatedKeys, verbose);

    // 4. WRITE, or compare.
    String pathFor(String language) => p.join(
        _workingDirectory.path, config.localeAssetsDir, '$language.json');

    if (check) {
      final stale = <String>[];
      for (final MapEntry(key: language, value: content) in files.entries) {
        final file = File(pathFor(language));
        if (!file.existsSync() || file.readAsStringSync() != content) {
          stale.add(p.join(config.localeAssetsDir, '$language.json'));
        }
      }
      if (stale.isEmpty) {
        _out('Up to date.');
        return ExitCodes.success;
      }
      _err('Out of date with the server:');
      for (final path in stale) {
        _err('  $path');
      }
      _err('Run `dart run $programName` and commit the result.');
      return ExitCodes.checkFoundDifferences;
    }

    for (final MapEntry(key: language, value: content) in files.entries) {
      final file = File(pathFor(language));
      final changed = !file.existsSync() || file.readAsStringSync() != content;
      _out('${changed ? 'Updated' : 'Unchanged'} '
          '${p.join(config.localeAssetsDir, '$language.json')}');
      if (changed) file.writeAsStringSync(content);
    }

    // 5. LOCALE_GEN, as 0.x did.
    try {
      _generate(config.localeGenParams);
    } catch (e) {
      _err('locale_gen failed: $e');
      return ExitCodes.localeGen;
    }
    return ExitCodes.success;
  }

  void _warnings(
    Map<String, List<String>> empty,
    List<String> deprecated,
    bool verbose,
  ) {
    for (final MapEntry(key: language, value: keys) in empty.entries) {
      if (keys.isEmpty) continue;
      _out('Warning: $language: ${keys.length} '
          '${keys.length == 1 ? 'key' : 'keys'} empty');
      if (verbose) {
        for (final key in keys) {
          _out('  $key');
        }
      }
    }
    if (deprecated.isNotEmpty) {
      _out('Warning: ${deprecated.length} deprecated '
          '${deprecated.length == 1 ? 'key' : 'keys'} still shipped');
      if (verbose) {
        for (final key in deprecated) {
          _out('  $key');
        }
      }
    }
    if (!verbose &&
        (deprecated.isNotEmpty || empty.values.any((k) => k.isNotEmpty))) {
      _out('Run with --verbose to list them.');
    }
  }

  String _usage() => 'Fetches the translations from impaktfull translations '
      'and generates the code with locale_gen.\n\n'
      'Usage: dart run $programName [options]\n\n'
      '${_parser.usage}\n\n'
      'The API key is read from $envApiKey. See $readmeSetupUrl';
}
