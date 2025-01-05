import 'package:http/http.dart' as http;

import 'json_translation_downloader.dart';

const _baseUrlPath = '/api/apps/translations';

class JsonApiTranslationDownloader extends JsonTranslationDownloader {
  const JsonApiTranslationDownloader(
    super.params,
  );

  @override
  Future<String> downloadJson(String language) async {
    final headers = <String, String>{
      'accept': 'application/json',
      'X-IF-TRANSLATION-APP-API-KEY': params.apiKey,
    };
    final uri = Uri(
      scheme: 'https',
      host: params.host.replaceFirst('https://', ''),
      path: _baseUrlPath,
      queryParameters: {
        'translationAppUuid': params.appUuid,
        'locales': language,
      },
    );
    final response = await http.get(
      uri,
      headers: headers,
    );
    if (response.statusCode != 200) {
      throw Exception(
        '\n\nFailed to get ${uri.toString()} with status code ${response.statusCode}\n',
      );
    }
    return response.body;
  }
}
