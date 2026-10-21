import 'dart:io';

import 'package:impaktfull_translations/impaktfull_translations.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

/// The User-Agent and the CHANGELOG name the version; pubspec.yaml is where
/// it is set. Written down twice, so pinned together.
void main() {
  test('packageVersion matches pubspec.yaml and the CHANGELOG', () {
    final pubspec = loadYaml(File('pubspec.yaml').readAsStringSync()) as Map;
    expect(packageVersion, pubspec['version']);
    expect(
      File('CHANGELOG.md').readAsLinesSync().first,
      '# $packageVersion',
    );
  });
}
