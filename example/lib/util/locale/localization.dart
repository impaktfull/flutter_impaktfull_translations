import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:impaktfull_translations_example/util/locale/localization_keys.dart';
import 'package:impaktfull_translations_example/util/locale/localization_overrides.dart';
import 'package:sprintf/sprintf.dart';

//============================================================//
//THIS FILE IS AUTO GENERATED. DO NOT EDIT//
//============================================================//

typedef LocaleFilter = bool Function(String languageCode);

class Localization {
  LocaleFilter? localeFilter;

  var _localisedValues = <String, dynamic>{};
  var _localisedOverrideValues = <String, dynamic>{};

  static Localization of(BuildContext context) =>
      Localizations.of<Localization>(context, Localization)!;

  /// The locale is used to get the correct json locale.
  /// It can later be used to check what the locale is that was used to load this Localization instance.
  final Locale? locale;

  Localization({required this.locale});

  static Future<Localization> load({
    required Locale locale,
    LocalizationOverrides? localizationOverrides,
    bool showLocalizationKeys = false,
    bool useCaching = true,
    AssetBundle? bundle,
  }) async {
    final localizations = Localization(locale: locale);
    if (showLocalizationKeys) {
      return localizations;
    }
    if (localizationOverrides != null) {
      final overrideLocalizations =
          await localizationOverrides.getOverriddenLocalizations(locale);
      localizations._localisedOverrideValues = overrideLocalizations;
    }
    final jsonContent = await (bundle ?? rootBundle).loadString(
        'assets/localization/${locale.toLanguageTag()}.json',
        cache: useCaching);
    localizations._localisedValues =
        json.decode(jsonContent) as Map<String, dynamic>;
    return localizations;
  }

  String _t(String key, {List<dynamic>? args}) {
    try {
      final value =
          (_localisedOverrideValues[key] ?? _localisedValues[key]) as String?;
      if (value == null) return key;
      if (args == null || args.isEmpty) return value;
      return sprintf(value, args);
    } catch (e) {
      return '⚠$key⚠';
    }
  }

  /// Translations:
  ///
  /// en:  **'Testing in English'**
  ///
  /// nl:  **'Test in het Nederlands'**
  String get test => _t(LocalizationKeys.test);

  /// Translations:
  ///
  /// en:  **'Testing argument [arg1 string]'**
  ///
  /// nl:  **'Test argument [arg1 string]'**
  String testArg1(String arg1) =>
      _t(LocalizationKeys.testArg1, args: <dynamic>[arg1]);

  /// Translations:
  ///
  /// en:  **'Testing argument [arg1 number]'**
  ///
  /// nl:  **'Test argument [arg1 number]'**
  String testArg2(int arg1) =>
      _t(LocalizationKeys.testArg2, args: <dynamic>[arg1]);

  /// Translations:
  ///
  /// en:  **'Testing argument [arg1 string] [arg2 number]'**
  ///
  /// nl:  **'Test argument [arg1 string] [arg2 number]'**
  String testArg3(String arg1, int arg2) =>
      _t(LocalizationKeys.testArg3, args: <dynamic>[arg1, arg2]);

  /// Translations:
  ///
  /// en:  **'Testing argument [arg1 string] [arg2 number] [arg1 string]'**
  ///
  /// nl:  **'Test argument [arg1 string] [arg2 number] [arg1 string]'**
  String testArg4(String arg1, int arg2) =>
      _t(LocalizationKeys.testArg4, args: <dynamic>[arg1, arg2]);

  /// Translations:
  ///
  /// en:  **'Testing\nargument\n\n[arg1 string] [arg2 number] [arg1 string]'**
  ///
  /// nl:  **'Test\nargument\n\n[arg1 string] [arg2 number] [arg1 string]'**
  String testNewLine(String arg1, int arg2) =>
      _t(LocalizationKeys.testNewLine, args: <dynamic>[arg1, arg2]);

  /// Translations:
  ///
  /// en:  **'Carriage\r\nReturn'**
  ///
  /// nl:  **'Carriage\r\nReturn'**
  String get testNewLineCarriageReturn =>
      _t(LocalizationKeys.testNewLineCarriageReturn);

  /// Translations:
  ///
  /// en:  **'Testing non positional argument %s and %.02f'**
  ///
  /// nl:  **'Test niet positioneel argument %s en %f'**
  String testNonPositional(String arg1, double arg2) =>
      _t(LocalizationKeys.testNonPositional, args: <dynamic>[arg1, arg2]);

  /// Translations:
  ///
  /// en:  **'Welcome to the impaktfull translations test app'**
  ///
  /// nl:  **'Welkom bij de impaktfull translations test app'**
  String get welcomeMessage => _t(LocalizationKeys.welcomeMessage);

  String getTranslation(String key, {List<dynamic>? args}) =>
      _t(key, args: args ?? <dynamic>[]);
}
