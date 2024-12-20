import 'dart:ui';

import 'package:impaktfull_architecture/impaktfull_architecture.dart';

class LocaleRepository {
  static const storeLocale = 'locale';

  static LocaleRepository? _instance;

  LocaleRepository._();

  factory LocaleRepository() => _instance ??= LocaleRepository._();

  Future<void> setCustomLocale(Locale? locale) async {
    final prefs = await SharedPreferences.getInstance();
    if (locale == null) {
      await prefs.remove(storeLocale);
      return;
    }
    await prefs.setString(storeLocale, locale.languageCode);
  }

  Future<Locale?> getCustomLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final localeCode = prefs.getString(storeLocale);
    if (localeCode == null || localeCode.isEmpty) return null;
    return Locale(localeCode);
  }
}
