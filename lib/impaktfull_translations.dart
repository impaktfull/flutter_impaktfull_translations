import 'dart:async';
import 'dart:io';

import 'package:impaktfull_translations/src/params.dart';
import 'package:impaktfull_translations/src/translation_downloader/translations_downloader.dart';
import 'package:locale_gen/locale_gen.dart';
import 'package:path/path.dart';

const programName = 'impaktfull_translations';

class ImpaktfullTranslations {
  Future<void> run(List<String> args) async {
    final params = Params(programName);

    final downloader = ImpaktfullTranslationDownloader.create(params);

    await Future.wait(params.languages
        .map((language) async => downloader.fetchTranslations(language))
        .toList());

    final localeFolder =
        Directory(join(Directory.current.path, params.localeAssetsDir));
    if (!localeFolder.existsSync()) {
      print('${params.localeAssetsDir} folder does not yet exist.');
      print('Creating folder...');
      localeFolder.createSync(recursive: true);
    }

    LocaleGenWriter.write(params);
  }
}
