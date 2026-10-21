# 1.0.0

## BREAKING CHANGES

1.0.0 fetches from [impaktfull translations](https://translations.impaktfull.com),
which replaces the translations part of dashboard.impaktfull.com. The old
dashboard API, its API keys and its app uuids no longer work, and there is no
compatibility route: every app switches by upgrading to 1.0.0.

- The API key is read from the `IMPAKTFULL_TRANSLATIONS_API_KEY` environment
  variable only (a CI secret in CI). `api_key` in `pubspec.yaml` is refused.
- `app_uuid` is replaced by `project_id`.
- The default `host` is `https://translations.impaktfull.com`. `http://` is
  allowed for `localhost` and `127.0.0.1` only.
- `IMPAKTFULL_TRANSLATIONS_TRANSLATION_APP_API_KEY` and
  `IMPAKTFULL_TRANSLATIONS_TRANSLATION_APP_UUID` are replaced by
  `IMPAKTFULL_TRANSLATIONS_API_KEY` and `IMPAKTFULL_TRANSLATIONS_PROJECT_ID`.
- Values are written exactly as delivered. 0.x replaced every literal `\n`
  (backslash, n) with a newline on each download; impaktfull translations did
  that once for all existing values when they were imported, so the files are
  unchanged, but a value typed with a literal `\n` from now on stays literal.
- `ImpaktfullTranslations.run` returns the exit code instead of throwing.

## Features

- One request for every language (`GET /api/delivery/v1/translations`) with
  `Authorization: Bearer itk_...`.
- `only_approved: true` delivers an unapproved translation as an empty string.
- `--check` compares the server with the files on disk, writes nothing and
  exits 1 when they differ, for CI jobs that fail on stale translations.
- `--verbose`, `--host` and `--project-id`.
- A summary line and warnings for empty translations and deprecated keys.
- Clear errors for a refused key (401), a forbidden or missing project
  (403, 404), a language the project does not have (422) and the rate limit
  (429). The key is never printed, only its public prefix (`itk_ABCDEFGH`).
- `project_id` is checked against the project the key belongs to, so a key of
  another app fails instead of delivering that app's strings.
- Every configuration problem is reported at once.
- Plural keys are written as nested objects, which locale_gen turns into
  plural functions.
- Exit codes: `0` success, `1` `--check` found differences, `2` configuration,
  `3` HTTP or network, `4` locale_gen.
- Works with locale_gen 12.6.0 up to 13.x.

## Fixes

- The locale folder is created before anything is fetched, so a first run no
  longer fails.
- Responses are read as UTF-8 whatever their content type says.

## Migrating from 0.x

1. Create an API key on your project's **Settings > API keys** tab in
   impaktfull translations. The same tab shows the complete `pubspec.yaml`
   snippet for your project, for Flutter and for Dart.
2. In `pubspec.yaml`, bump the dependency and change the config:

   ```diff
    dev_dependencies:
   -  impaktfull_translations: ^0.1.0
   +  impaktfull_translations: ^1.0.0

    impaktfull_translations:
   -  api_key: "..."
   -  app_uuid: "..."
   -  host: "https://dashboard.impaktfull.com"
   +  project_id: <project id from Settings > API keys>
      default_language: nl
      languages: [en, nl]
      locale_assets_path: assets/locale/
      assets_path: assets/locale/
   ```

3. Set the key as `IMPAKTFULL_TRANSLATIONS_API_KEY` on your machine and as a
   CI secret, and remove `IMPAKTFULL_TRANSLATIONS_TRANSLATION_APP_API_KEY` and
   `IMPAKTFULL_TRANSLATIONS_TRANSLATION_APP_UUID`.
4. Run `dart run impaktfull_translations`. The language files are written in
   exactly the format 0.x wrote (sorted keys, two-space indent, no trailing
   newline), so for the same translations `git diff` shows only your
   `pubspec.yaml`.

Running 1.0.0 with the 0.x config fails with a message listing these changes.

# 0.1.0

## Feature

- Added support to `locale_gen` 12.6.0. Containing a dart writer to use the translations in a dart app or backend.
- Better readme documentation about the `output_type` configuration

# 0.0.4

## Docs

- Updated docs

## Fix

- Example to use correct order of configuration

# 0.0.3

## Fix

- Fixed the `JsonTranslationDownloader` to use the correct api to download the translations
- Fixed the correct use of `host` configuration & validation
- Fixed example to use a production api key & translation app uuid
- Updated the license to 2025

# 0.0.2

## Fix

- Updated example to use `impaktfull_ui` to 0.13.0

# 0.0.1

- Initial release
- Supports downloading translations from the Impaktfull Dashboard - Translation App so you can use it in your Flutter app
- Used `locale_gen` to generate the translations dart code
