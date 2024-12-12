# impaktfull_translations

A dart package to automaticly download translations from the impaktfull translation tool so they can be used in your flutter app. The rest of the implementation is done by locale_gen https://pub.dev/packages/locale_gen

## Disclaimer

**impaktfull_cli is still in unstable & untested. everything under <1.0.0 should not be used unless you want to test it**

## Usage

### Add dependency to pubspec

[![pub package](https://img.shields.io/pub/v/impaktfull_translations.svg)](https://pub.dartlang.org/packages/impaktfull_translations)

```yaml
dependencies:
  sprintf: ^7.0.0

dev-dependencies:
  impaktfull_translations: <latest-version>
```

### Add config to pubspec

Add your locale folder to the assets to make use all your translations are loaded.

```yaml
flutter:
  assets:
    - assets/locale/
```

Add the impaktfull_translations config to fetch the latest translations

```yaml
impaktfull_translations:
  api_key: "enter-your-api-key"
  project_id: "optional project id"
  host: "optional host ip/domain"
  default_language: "nl"
  languages: ["en", "nl"]
  locale_assets_path: "assets/locale/"
  assets_path: "assets/locale/"
```

alternatively set an env variable for your `api_key` and/or `app_uuid`

### ENV Variables:

- IMPAKTFULL_TRANSLATIONS_TRANSLATION_APP_API_KEY
- IMPAKTFULL_TRANSLATIONS_TRANSLATION_APP_UUID
- IMPAKTFULL_TRANSLATIONS_HOST

### Run package with Flutter

```shell
flutter packages pub run impaktfull_translations
```

### Run package with Dart

```shell
dart pub run impaktfull_translations
```

### Arguments

You can pass a String or a num as an argument.

Formatting for String: %1$s
Formatting for num: %1$d

The number in between % and $ indicate the index of the argument. It is possible to place an argument in 1 language first but in another second:

ex (Grammatically incorrect but it makes my point):

```
nl '%1$s, ik woon in %2$s. Wist je dat niet?' => KOEN, ik woon in ANTWERPEN. Wist je dat niet?

fr 'I live in %2$s. You didn't knew that %1$s?" => I live in ANTWERP. You didn't knew that KOEN?
```

### Plurals

To specify a plural, you can use the following syntax in the json file:

```json
{
  "example_plural": {
    "zero": "You have no items",
    "one": "You have %1$d item",
    "two": "You have 2 items, party!",
    "few": "You have a few items, nice!",
    "many": "You have many items, fantastic!",
    "other": "You have %1$d items"
  }
}
```

This will generate functions where you pass the number of items as an argument. The function will then return the correct translation based on the number of items.
The count argument _WILL NOT_ be passed as an argument for string interpolation.

Note that the "other" key is always required, the other keys are dependant on the language in question
