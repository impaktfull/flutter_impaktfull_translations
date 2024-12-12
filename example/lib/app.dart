import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:impaktfull_translations_example/screen/home_screen.dart';
import 'package:impaktfull_translations_example/util/locale/localization_delegate.dart';
import 'package:impaktfull_translations_example/viewmodel/locale/locale_viewmodel.dart';
import 'package:impaktfull_ui_2/impaktfull_ui.dart';
import 'package:provider/provider.dart';

import 'repository/locale_repository.dart';

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<LocaleViewModel>(
      child: Consumer<LocaleViewModel>(
        builder: (context, viewModel, child) => ImpaktfullUiApp(
          title: 'impaktfull translations',
          localizationsDelegates: [
            viewModel.localeDelegate,
            ...GlobalMaterialLocalizations.delegates,
            GlobalWidgetsLocalizations.delegate,
          ],
          locale: viewModel.localeDelegate.activeLocale,
          supportedLocales: LocalizationDelegate.supportedLocales,
          home: const HomeScreen(),
        ),
      ),
      create: (_) => LocaleViewModel(LocaleRepository())..init(),
    );
  }
}
