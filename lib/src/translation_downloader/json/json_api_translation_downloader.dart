import 'package:http/http.dart' as http;

import 'json_translation_downloader.dart';

const _baseUrl = 'https://dashboard.impaktfull.com';
const _baseUrlPath = '/api/apps/translations';

class JsonApiTranslationDownloader extends JsonTranslationDownloader {
  String get host => params.host ?? _baseUrl;

  const JsonApiTranslationDownloader(
    super.params,
  );

  @override
  Future<String> downloadJson(String language) async {
    final headers = <String, String>{
      'accept': 'application/json',
      'Authorization': 'Bearer ${params.apiKey}',
    };
    final url = '$host$_baseUrlPath/${params.appUuid}/translations/$language';
    final uri = Uri.parse(url);
    final response = await http.get(
      uri,
      headers: headers,
    );
    if (response.statusCode != 200) {
      throw Exception(
        '\n\nFailed to get $url with status code ${response.statusCode}\n',
      );
    }
    return response.body;
  }
}
