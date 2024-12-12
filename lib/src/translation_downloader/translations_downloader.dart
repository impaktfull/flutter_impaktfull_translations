import 'json/json_api_translation_downloader.dart';
import '../params.dart';

abstract class ImpaktfullTranslationDownloader {
  static ImpaktfullTranslationDownloader create(Params params) =>
      JsonApiTranslationDownloader(params);

  Future<void> fetchTranslations(String language);
}
