import 'package:impaktfull_translations/impaktfull_translations.dart';
import 'package:test/test.dart';

const projectId = '4b0e0f6c-1d2e-4f30-9a8b-7c6d5e4f3a2b';
const token = 'itk_4Q7M2KX9_bW9yZS1yYW5kb20tYnl0ZXMtaGVyZS4uLg';

String pubspec(String section) => 'name: my_app\n\n$section\n';

TranslationsConfig load(
  String section, {
  Map<String, String> env = const {'IMPAKTFULL_TRANSLATIONS_API_KEY': token},
}) =>
    TranslationsConfig.load(pubspecContent: pubspec(section), environment: env);

List<String> problems(
  String section, {
  Map<String, String> env = const {'IMPAKTFULL_TRANSLATIONS_API_KEY': token},
}) {
  try {
    load(section, env: env);
  } on ConfigException catch (e) {
    return e.problems;
  }
  fail('expected a ConfigException');
}

void main() {
  test('the snippet the server shows on the API keys tab is accepted', () {
    // COPIED from `cliConfig` and the Flutter stack in the server's
    // web/src/features/settings/SettingsPage.tsx (impaktfull_translations
    // 2.0.0), with a real project id and languages filled in. If the server
    // changes what it tells people to paste, this is where the CLI finds out.
    final config = load('''
impaktfull_translations:
  host: https://translations.impaktfull.com
  project_id: $projectId
  release: draft
  only_approved: false
  fallback: default
  output_type: flutter
  default_language: nl
  languages: [nl, en, fr-BE]
  locale_assets_path: assets/locale/
  assets_path: assets/locale/''');
    expect(config.host.toString(), 'https://translations.impaktfull.com');
    expect(config.projectId, projectId);
    expect(config.onlyApproved, isFalse);
    expect(config.languages, ['nl', 'en', 'fr-BE']);
    expect(config.localeAssetsDir, 'assets/locale/');
    expect(config.notes, isEmpty, reason: 'nothing in it is worth a note');
  });

  test('defaults: production host, no onlyApproved', () {
    final config = load('''
impaktfull_translations:
  project_id: $projectId
  languages: [nl]''');
    expect(config.host.toString(), 'https://translations.impaktfull.com');
    expect(
      config.deliveryUri(['nl', 'fr-BE']).toString(),
      'https://translations.impaktfull.com/api/delivery/v1/translations'
      '?locales=nl%2Cfr-BE',
    );
  });

  test('only_approved: true is sent as onlyApproved=true', () {
    final config = load('''
impaktfull_translations:
  project_id: $projectId
  only_approved: true
  languages: [nl]''');
    expect(
      config.deliveryUri(['nl']).queryParameters['onlyApproved'],
      'true',
    );
  });

  test('the spelling in languages is kept, the request is canonical', () {
    final config = load('''
impaktfull_translations:
  project_id: $projectId
  languages: [nl, fr_BE, zh_hant_tw]''');
    expect(config.canonicalByLanguage, {
      'nl': 'nl',
      'fr_BE': 'fr-BE',
      'zh_hant_tw': 'zh-Hant-TW',
    });
  });

  group('migration from 0.x', () {
    test('api_key and app_uuid fail with what to change', () {
      final found = problems('''
impaktfull_translations:
  api_key: "05a73dc9-fdf3-48a9-984a-343c3c0df1f6"
  app_uuid: "b6925bf4-f5c0-47cf-9724-792987c7a695"
  default_language: nl
  languages: [en, nl]''', env: const {});
      final text = found.join('\n');
      expect(text, contains('`api_key` and `app_uuid` are 0.x configuration'));
      expect(text, contains('IMPAKTFULL_TRANSLATIONS_API_KEY'));
      expect(text, contains('`project_id: <project id>`'));
      expect(text, contains('#migrating-from-0x'));
      // The old key is not repeated back.
      expect(text, isNot(contains('05a73dc9')));
    });

    test('an itk_ key in pubspec.yaml is still refused', () {
      final found = problems('''
impaktfull_translations:
  api_key: $token
  project_id: $projectId
  languages: [nl]''');
      expect(found.single, contains('A key never goes in pubspec.yaml'));
      expect(found.single, isNot(contains(token)));
    });

    test('the dashboard host is refused', () {
      final found = problems('''
impaktfull_translations:
  host: https://dashboard.impaktfull.com
  project_id: $projectId
  languages: [nl]''');
      expect(found.single, contains('dashboard.impaktfull.com'));
    });

    test('the 0.x environment variables are named as such', () {
      final found = problems(
        '''
impaktfull_translations:
  languages: [nl]''',
        env: const {
          'IMPAKTFULL_TRANSLATIONS_TRANSLATION_APP_API_KEY': 'old',
          'IMPAKTFULL_TRANSLATIONS_TRANSLATION_APP_UUID': 'old',
        },
      ).join('\n');
      expect(found, contains('is the 0.x variable'));
      expect(found, contains('IMPAKTFULL_TRANSLATIONS_TRANSLATION_APP_UUID'));
    });

    test('an old dashboard key in the new variable is refused unechoed', () {
      final found = problems(
        '''
impaktfull_translations:
  project_id: $projectId
  languages: [nl]''',
        env: const {
          'IMPAKTFULL_TRANSLATIONS_API_KEY':
              '05a73dc9-fdf3-48a9-984a-343c3c0df1f6',
        },
      );
      expect(found.single, contains('starts with `itk_`'));
      expect(found.single, isNot(contains('05a73dc9')));
    });
  });

  test('every problem is reported at once', () {
    final found = problems('''
impaktfull_translations:
  host: ftp://example.com
  languages: [nl, nl_xx_yy_zz]''', env: const {});
    expect(found, hasLength(4)); // host, project_id, api key, language
  });

  test('no section at all points to the setup', () {
    final found = problems('dependencies: {}');
    expect(found.single, contains('#setup'));
  });

  test('locale_gen problems are reported too', () {
    final found = problems('''
impaktfull_translations:
  project_id: $projectId
  default_language: de
  languages: [nl]''');
    expect(found.single, contains('default language'));
  });

  test('the env supplies project id and host when pubspec does not', () {
    final config = load(
      '''
impaktfull_translations:
  languages: [nl]''',
      env: const {
        'IMPAKTFULL_TRANSLATIONS_API_KEY': token,
        'IMPAKTFULL_TRANSLATIONS_PROJECT_ID': projectId,
        'IMPAKTFULL_TRANSLATIONS_HOST': 'http://localhost:8085',
      },
    );
    expect(config.projectId, projectId);
    expect(config.host.toString(), 'http://localhost:8085');
  });

  test('pubspec wins over the env, and a flag over both', () {
    final config = TranslationsConfig.load(
      pubspecContent: pubspec('''
impaktfull_translations:
  host: https://a.example.com
  languages: [nl]'''),
      environment: const {
        'IMPAKTFULL_TRANSLATIONS_API_KEY': token,
        'IMPAKTFULL_TRANSLATIONS_HOST': 'https://b.example.com',
      },
      projectIdFlag: projectId,
    );
    expect(config.host.host, 'a.example.com');
    expect(config.projectId, projectId);
  });

  test('http is only allowed for localhost', () {
    expect(
      problems('''
impaktfull_translations:
  host: http://translations.impaktfull.com
  project_id: $projectId
  languages: [nl]''').single,
      contains('https://'),
    );
  });

  test('release and fallback values that expect more get a note', () {
    final config = load('''
impaktfull_translations:
  project_id: $projectId
  release: latest
  fallback: [en, nl]
  languages: [nl]''');
    expect(config.notes, hasLength(2));
  });

  test('the key prints as its public prefix only', () {
    final config = load('''
impaktfull_translations:
  project_id: $projectId
  languages: [nl]''');
    expect(config.apiKeyLabel, 'itk_4Q7M2KX9');
  });
}
