import 'dart:io';

import 'package:locale_gen/locale_gen.dart';
import 'package:path/path.dart';

class Params extends LocaleGenParams {
  static const envApiKey = 'IMPAKTFULL_TRANSLATIONS_TRANSLATION_APP_API_KEY';
  static const envAppUuid = 'IMPAKTFULL_TRANSLATIONS_TRANSLATION_APP_UUID';
  static const envHost = 'IMPAKTFULL_TRANSLATIONS_HOST';

  String? _apiKey;
  String? _appUuid;
  String? _host;

  String get apiKey => _apiKey!;
  String get appUuid => _appUuid!;
  String get host => _host ?? 'https://dashboard.impaktfull.com';

  factory Params(String programName) {
    final pubspecYaml = File(join(Directory.current.path, 'pubspec.yaml'));
    if (!pubspecYaml.existsSync()) {
      throw Exception(
          'This program should be run from the root of a flutter/dart project');
    }

    final pubspecContent = pubspecYaml.readAsStringSync();
    return Params.fromYamlString(
      programName,
      pubspecContent,
    );
  }

  Params.fromYamlString(
    super.programName,
    super.pubspecContent,
  ) : super.fromYamlString();

  @override
  void configure(config) {
    super.configure(config);
    _apiKey = config['api_key'] as String?;
    _appUuid = config['app_uuid'] as String?;
    _host = config['host'] as String?;

    if (_apiKey == null || _apiKey?.isEmpty == true) {
      _apiKey = Platform.environment[envApiKey];
    }
    if (_appUuid == null || _appUuid?.isEmpty == true) {
      _appUuid = Platform.environment[envAppUuid];
    }
    if (_host == null || _host?.isEmpty == true) {
      _host = Platform.environment[envHost];
    }

    if (_apiKey == null || _apiKey?.isEmpty == true) {
      throw Exception(
          'A `api_key` should be added to the $programName section in the pubspec.yaml\n'
          '$programName'
          "  api_key: 'your-api-key'");
    }

    if (_apiKey == null || _apiKey?.isEmpty == true) {
      throw Exception(
          'A `app_uuid` should be added to the $programName section in the pubspec.yaml\n'
          '$programName'
          "  app_uuid: 'your-api-key'");
    }

    if (!host.startsWith('https://')) {
      throw Exception('the `host` must start with `https://`');
    }
  }
}
