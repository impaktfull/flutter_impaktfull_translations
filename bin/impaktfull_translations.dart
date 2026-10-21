import 'dart:async';
import 'dart:io';

import 'package:impaktfull_translations/impaktfull_translations.dart';

Future<void> main(List<String> args) async {
  exitCode = await ImpaktfullTranslations().run(args);
}
