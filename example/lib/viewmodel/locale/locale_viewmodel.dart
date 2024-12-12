import 'dart:ui';

import 'package:impaktfull_architecture/impaktfull_architecture.dart';
import 'package:impaktfull_translations_example/repository/locale_repository.dart';
import 'package:impaktfull_translations_example/util/locale/localization_delegate.dart';

class LocaleViewModel extends ChangeNotifierEx {
  final LocaleRepository _localeRepository;
  late var localeDelegate = LocalizationDelegate();
  Locale? _selectedLocale;

  Locale? get selectedLocale => _selectedLocale;

  LocaleViewModel(this._localeRepository);

  void init() => initLocale();

  Future<void> initLocale() async {
    final locale = await _localeRepository.getCustomLocale();
    _setLocalizationDelegat(locale);
  }

  void _setLocalizationDelegat(Locale? locale) {
    _selectedLocale = locale;
    if (locale != null) {
      localeDelegate = LocalizationDelegate(
        newLocale: locale,
      );
    } else {
      localeDelegate = LocalizationDelegate();
    }
    notifyListeners();
  }

  Future<void> onSwitchToLocale(Locale? locale) async {
    await _localeRepository.setCustomLocale(locale);
    _setLocalizationDelegat(locale);
  }
}
