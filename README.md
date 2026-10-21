# impaktfull_translations

[![pub package](https://img.shields.io/pub/v/impaktfull_translations.svg)](https://pub.dev/packages/impaktfull_translations)

Fetches your translations from [impaktfull translations](https://translations.impaktfull.com)
and generates the Dart code for them with [locale_gen](https://pub.dev/packages/locale_gen),
for Flutter apps and Dart projects.

Coming from 0.x and dashboard.impaktfull.com? See [Migrating from 0.x](#migrating-from-0x).

## Setup

Your project's **Settings > API keys** tab in impaktfull translations shows
this whole snippet with your project id and languages filled in, for Flutter
and for Dart. Copy it from there.

### 1. pubspec.yaml

Flutter:

```yaml
dependencies:
  flutter_localizations:
    sdk: flutter
  intl: ^0.20.2
  sprintf: ^7.0.0

dev_dependencies:
  impaktfull_translations: ^1.0.0

flutter:
  assets:
    - assets/locale/

impaktfull_translations:
  host: https://translations.impaktfull.com
  project_id: <project id>
  only_approved: false
  output_type: flutter
  default_language: nl
  languages: [nl, en, fr-BE]
  locale_assets_path: assets/locale/
  assets_path: assets/locale/
```

Dart (no Flutter): the same, without `flutter_localizations`, the `flutter:`
block and `assets_path`, and with `output_type: dart`.

| Key | Default | |
| --- | --- | --- |
| `host` | `https://translations.impaktfull.com` | `http://` is allowed for `localhost` and `127.0.0.1` |
| `project_id` | required | Checked against the project the API key belongs to |
| `only_approved` | `false` | `true` delivers a translation nobody approved as an empty string |
| `output_type` | `flutter` | `flutter` or `dart` |
| `default_language`, `languages`, `locale_assets_path`, `assets_path`, `output_path`, `doc_languages` | | Passed to locale_gen unchanged |

The snippet on the API keys tab also contains `release: draft` and
`fallback: default`. They are accepted and have no effect: the server delivers
the project's current state and a missing translation is an empty string.

A language is written to a file named exactly as you spell it in `languages`:
`fr_BE` writes `fr_BE.json`, `fr-BE` writes `fr-BE.json`.

### 2. The API key

Create a key on the **Settings > API keys** tab and give it to the CLI as an
environment variable, on your machine and as a CI secret:

```shell
export IMPAKTFULL_TRANSLATIONS_API_KEY=itk_...
```

The key is never read from `pubspec.yaml`, and never printed: errors name its
public prefix (`itk_ABCDEFGH`) only.

| Environment variable | |
| --- | --- |
| `IMPAKTFULL_TRANSLATIONS_API_KEY` | Required |
| `IMPAKTFULL_TRANSLATIONS_PROJECT_ID` | Used when `project_id` is not in `pubspec.yaml` |
| `IMPAKTFULL_TRANSLATIONS_HOST` | Used when `host` is not in `pubspec.yaml` |

A command-line flag wins over `pubspec.yaml`, which wins over the environment.

### 3. Run

```shell
dart run impaktfull_translations
```

It fetches every language in one request, writes
`<locale_assets_path>/<language>.json` and runs locale_gen, which generates the
code in `lib/util/locale/`.

| Option | |
| --- | --- |
| `--check` | Compare the server with the files on disk, write nothing, exit 1 when they differ |
| `--verbose` | List the keys behind the empty and deprecated warnings |
| `--host`, `--project-id` | Override `pubspec.yaml` |

Exit codes: `0` success, `1` `--check` found differences, `2` configuration
error, `3` HTTP or network error, `4` locale_gen failed.

In CI:

```yaml
- run: dart run impaktfull_translations --check
  env:
    IMPAKTFULL_TRANSLATIONS_API_KEY: ${{ secrets.IMPAKTFULL_TRANSLATIONS_API_KEY }}
```

## Migrating from 0.x

0.x fetched from dashboard.impaktfull.com. 1.0.0 fetches from impaktfull
translations, with new API keys: the old keys and app uuids do not work.

1. Create an API key on your project's **Settings > API keys** tab.
2. In `pubspec.yaml`: bump to `impaktfull_translations: ^1.0.0`, remove
   `api_key`, replace `app_uuid` with `project_id`, and remove a `host` that
   points at dashboard.impaktfull.com.
3. Set `IMPAKTFULL_TRANSLATIONS_API_KEY` locally and in CI, and remove
   `IMPAKTFULL_TRANSLATIONS_TRANSLATION_APP_API_KEY` and
   `IMPAKTFULL_TRANSLATIONS_TRANSLATION_APP_UUID`.
4. Run `dart run impaktfull_translations`. The files are written in exactly
   the format 0.x wrote, so the same translations produce no diff.

Running 1.0.0 with a 0.x config fails and says what to change. The
[CHANGELOG](CHANGELOG.md) has the details.

## Translations

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
