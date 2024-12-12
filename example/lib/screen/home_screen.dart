import 'package:flutter/widgets.dart';
import 'package:impaktfull_architecture/impaktfull_architecture.dart';
import 'package:impaktfull_translations_example/util/locale/localization.dart';
import 'package:impaktfull_translations_example/viewmodel/locale/locale_viewmodel.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final localization = Localization.of(context);
    final localeViewModel = Provider.of<LocaleViewModel>(context);
    return ImpaktfullUiStatusBar.dark(
      child: ImpaktfullUiScreen(
        title: 'impaktfull translations',
        child: ImpaktfullUiListView(
          padding: const EdgeInsets.all(16),
          spacing: 8,
          children: [
            ImpaktfullUiSeparatedColumn(
              children: [
                ImpaktfullUiRadioButtonListItem(
                  title: 'System language',
                  value: null,
                  groupValue: localeViewModel.selectedLocale,
                  onChanged: localeViewModel.onSwitchToLocale,
                ),
                ImpaktfullUiRadioButtonListItem(
                  title: 'English',
                  value: const Locale('en'),
                  groupValue: localeViewModel.selectedLocale,
                  onChanged: localeViewModel.onSwitchToLocale,
                ),
                ImpaktfullUiRadioButtonListItem(
                  title: 'Nederlands',
                  value: const Locale('nl'),
                  groupValue: localeViewModel.selectedLocale,
                  onChanged: localeViewModel.onSwitchToLocale,
                ),
              ],
            ),
            Text(localization.locale.toString()),
            const Text('--------------------------------'),
            Text(localization.test),
            Text(localization.testArg1('string')),
            Text(localization.testArg2(1)),
            Text(localization.testArg3('string', 1)),
            Text(localization.testArg4('string', 1)),
            Text(localization.testNonPositional('string', 1)),
            Text(localization.testPlural(4, 4)),
            Text(localization.testPlural(1, 1)),
          ],
        ),
      ),
    );
  }
}
