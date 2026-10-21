import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:impaktfull_translations/impaktfull_translations.dart';
import 'package:locale_gen/locale_gen.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

const projectId = '4b0e0f6c-1d2e-4f30-9a8b-7c6d5e4f3a2b';
const token = 'itk_4Q7M2KX9_bW9yZS1yYW5kb20tYnl0ZXMtaGVyZS4uLg';
const env = {'IMPAKTFULL_TRANSLATIONS_API_KEY': token};

/// A response in the shape the server's delivery endpoint builds today.
Map<String, Object?> delivery({
  Map<String, Map<String, Object?>>? locales,
  String id = projectId,
  List<String> deprecated = const [],
}) {
  final l = locales ??
      {
        'nl': {'home.title': 'Welkom', 'login.button': 'Aanmelden'},
        'fr-BE': {'home.title': 'Bienvenue', 'login.button': ''},
      };
  return {
    'project': {'id': id, 'sourceLocale': 'nl'},
    'locales': l,
    'meta': {'keyCount': l.values.first.length, 'deprecatedKeys': deprecated},
  };
}

http.Response jsonResponse(Object body,
        [int status = 200, Map<String, String>? headers]) =>
    http.Response.bytes(
      utf8.encode(jsonEncode(body)),
      status,
      // No charset on purpose: the server sends none, and the CLI must still
      // read UTF-8.
      headers: {'content-type': 'application/json', ...?headers},
    );

http.Response errorResponse(int status, String code, String message,
        [Map<String, String>? headers]) =>
    jsonResponse({
      'error': {'code': code, 'message': message},
    }, status, headers);

class Harness {
  Harness(this.dir);

  final Directory dir;
  final out = <String>[];
  final err = <String>[];
  final requests = <http.Request>[];
  var generated = 0;

  String get output => [...out, ...err].join('\n');

  void writePubspec([String? section]) {
    File(p.join(dir.path, 'pubspec.yaml')).writeAsStringSync('''
name: my_app

${section ?? '''
impaktfull_translations:
  project_id: $projectId
  default_language: nl
  languages: [nl, fr_BE]
  locale_assets_path: assets/locale/
  assets_path: assets/locale/'''}
''');
  }

  File file(String language) =>
      File(p.join(dir.path, 'assets', 'locale', '$language.json'));

  Future<int> run(
    http.Response Function(http.Request) handler, {
    List<String> args = const [],
    Map<String, String> environment = env,
    void Function(LocaleGenParams)? generate,
  }) =>
      ImpaktfullTranslations(
        httpClient: MockClient((request) async {
          requests.add(request);
          return handler(request);
        }),
        environment: environment,
        workingDirectory: dir,
        generate: generate ?? (_) => generated++,
        out: out.add,
        err: err.add,
      ).run(args);
}

void main() {
  late Harness h;

  setUp(() {
    h = Harness(Directory.systemTemp.createTempSync('impaktfull_translations'));
    h.writePubspec();
  });
  tearDown(() => h.dir.deleteSync(recursive: true));

  test('one request for every language, with the bearer key', () async {
    final code = await h.run((_) => jsonResponse(delivery()));
    expect(code, ExitCodes.success, reason: h.output);

    final request = h.requests.single;
    expect(request.method, 'GET');
    expect(request.url.origin, 'https://translations.impaktfull.com');
    expect(request.url.path, '/api/delivery/v1/translations');
    expect(request.url.queryParameters, {'locales': 'nl,fr-BE'});
    expect(request.headers['authorization'], 'Bearer $token');
    expect(request.headers['accept'], 'application/json');
    expect(h.generated, 1);
  });

  test('files are named after the spelling in languages', () async {
    await h.run((_) => jsonResponse(delivery()));
    expect(
      h.file('fr_BE').readAsStringSync(),
      '{\n  "home.title": "Bienvenue",\n  "login.button": ""\n}',
    );
    expect(
      h.file('nl').readAsStringSync(),
      '{\n  "home.title": "Welkom",\n  "login.button": "Aanmelden"\n}',
    );
  });

  test('UTF-8 survives a response without a charset', () async {
    await h.run((_) => jsonResponse(delivery(locales: {
          'nl': {'a': 'Café 🎉'},
          'fr-BE': {'a': 'Ça'},
        })));
    expect(jsonDecode(h.file('nl').readAsStringSync()), {'a': 'Café 🎉'});
  });

  test('the locale folder is created before the first fetch', () async {
    expect(Directory(p.join(h.dir.path, 'assets', 'locale')).existsSync(),
        isFalse);
    await h.run((_) {
      expect(Directory(p.join(h.dir.path, 'assets', 'locale')).existsSync(),
          isTrue);
      return jsonResponse(delivery());
    });
  });

  test('summary and warnings for empty and deprecated keys', () async {
    await h.run((_) => jsonResponse(delivery(deprecated: ['home.title'])),
        args: ['--verbose']);
    expect(h.out, contains('2 keys · nl, fr_BE'));
    expect(h.out, contains('Warning: fr_BE: 1 key empty'));
    expect(h.out, contains('Warning: 1 deprecated key still shipped'));
    expect(h.out, contains('  login.button'));
  });

  test('only_approved is sent', () async {
    h.writePubspec('''
impaktfull_translations:
  project_id: $projectId
  only_approved: true
  languages: [nl, fr_BE]
  locale_assets_path: assets/locale/''');
    await h.run((_) => jsonResponse(delivery()));
    expect(h.requests.single.url.queryParameters['onlyApproved'], 'true');
  });

  test('a key for another project is refused before writing', () async {
    final code = await h.run((_) =>
        jsonResponse(delivery(id: '00000000-0000-0000-0000-000000000000')));
    expect(code, ExitCodes.configuration);
    expect(h.output, contains('belongs to project 00000000'));
    expect(h.file('nl').existsSync(), isFalse);
    expect(h.generated, 0);
  });

  test('a configuration error makes no request', () async {
    final code =
        await h.run((_) => fail('no request expected'), environment: const {});
    expect(code, ExitCodes.configuration);
    expect(h.output, contains('IMPAKTFULL_TRANSLATIONS_API_KEY is not set'));
    expect(h.requests, isEmpty);
  });

  test('the 0.x pubspec fails with the migration message', () async {
    h.writePubspec('''
impaktfull_translations:
  api_key: "05a73dc9-fdf3-48a9-984a-343c3c0df1f6"
  app_uuid: "b6925bf4-f5c0-47cf-9724-792987c7a695"
  default_language: nl
  languages: [en, nl]''');
    final code = await h.run((_) => fail('no request expected'));
    expect(code, ExitCodes.configuration);
    expect(
        h.output, contains('0.x configuration for dashboard.impaktfull.com'));
  });

  group('HTTP failures', () {
    final cases = <int, (http.Response, String)>{
      401: (
        errorResponse(
            401, 'invalid_api_key', 'the API key is not valid or was revoked'),
        '401 invalid_api_key: the API key is not valid or was revoked',
      ),
      403: (
        errorResponse(403, 'forbidden', 'not allowed'),
        'may not read this project',
      ),
      404: (
        errorResponse(404, 'release_not_found', 'not found'),
        'not found or is archived',
      ),
      422: (
        errorResponse(
            422, 'unknown_locale', '"fr-BE" is not a locale of this project'),
        "Settings > Languages",
      ),
      429: (
        errorResponse(429, 'rate_limited', 'too many requests for this API key',
            {'retry-after': '60'}),
        'Try again in 60 seconds',
      ),
      502: (http.Response('<html>Bad gateway</html>', 502), '502'),
    };
    for (final MapEntry(key: status, value: (response, expected))
        in cases.entries) {
      test('$status exits 3 with a clear message', () async {
        final code = await h.run((_) => response);
        expect(code, ExitCodes.network);
        expect(h.output, contains(expected));
        expect(h.generated, 0);
      });
    }

    test('a network failure exits 3', () async {
      final code =
          await h.run((_) => throw http.ClientException('connection refused'));
      expect(code, ExitCodes.network);
      expect(h.output, contains('Could not reach'));
    });
  });

  test('the key is never printed, only its prefix', () async {
    await h.run((_) => errorResponse(401, 'invalid_api_key', 'nope'));
    await h.run((_) => jsonResponse(delivery()));
    expect(h.output, isNot(contains('bW9yZS1yYW5kb20')));
    expect(h.output, contains('itk_4Q7M2KX9'));
  });

  group('--check', () {
    test('up to date exits 0 and writes nothing', () async {
      await h.run((_) => jsonResponse(delivery()));
      final before = h.file('nl').lastModifiedSync();
      h.generated = 0;
      final code =
          await h.run((_) => jsonResponse(delivery()), args: ['--check']);
      expect(code, ExitCodes.success);
      expect(h.file('nl').lastModifiedSync(), before);
      expect(h.generated, 0);
    });

    test('stale files exit 1 and are listed', () async {
      await h.run((_) => jsonResponse(delivery()));
      final changed = delivery(locales: {
        'nl': {'home.title': 'Hallo', 'login.button': 'Aanmelden'},
        'fr-BE': {'home.title': 'Bienvenue', 'login.button': ''},
      });
      final code = await h.run((_) => jsonResponse(changed), args: ['--check']);
      expect(code, ExitCodes.checkFoundDifferences);
      expect(h.err, contains('  ${p.join('assets/locale/', 'nl.json')}'));
      expect(h.err.where((l) => l.contains('fr_BE.json')), isEmpty);
      expect(
          jsonDecode(h.file('nl').readAsStringSync())['home.title'], 'Welkom');
    });
  });

  test('a locale_gen failure exits 4', () async {
    final code = await h.run((_) => jsonResponse(delivery()),
        generate: (_) => throw Exception('boom'));
    expect(code, ExitCodes.localeGen);
  });

  test('locale_gen really generates from the written files', () async {
    final previous = Directory.current;
    // locale_gen reads Directory.current, as it always has.
    Directory.current = h.dir;
    addTearDown(() => Directory.current = previous);

    final code = await h.run(
      (_) => jsonResponse(delivery(locales: {
        'nl': {
          'greeting': r'Hallo %1$s',
          'cart_items': {'one': r'%1$d artikel', 'other': r'%1$d artikelen'},
        },
        'fr-BE': {
          'greeting': r'Bonjour %1$s',
          'cart_items': {'one': r'%1$d article', 'other': r'%1$d articles'},
        },
      })),
      generate: LocaleGenWriter.write,
    );
    expect(code, ExitCodes.success, reason: h.output);
    final generated = Directory(p.join(h.dir.path, 'lib', 'util', 'locale'))
        .listSync()
        .whereType<File>()
        .map((f) => f.readAsStringSync())
        .join('\n');
    expect(generated, contains('greeting'));
    expect(generated, contains('cartItems'));
  });
}
