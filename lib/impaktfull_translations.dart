/// The impaktfull translations CLI: fetches a project's translations from the
/// delivery API and generates the Dart code for them with locale_gen.
library;

export 'src/cli.dart' show ImpaktfullTranslations, ExitCodes, packageVersion;
export 'src/config/translations_config.dart'
    show ConfigException, TranslationsConfig;
export 'src/output/translation_file.dart' show encodeTranslationFile;
