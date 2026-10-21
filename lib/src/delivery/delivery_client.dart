import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/translations_config.dart';

/// What the delivery API answered (spec 9.3, as the server builds it today).
class DeliveryResponse {
  const DeliveryResponse({
    required this.projectId,
    required this.locales,
    required this.keyCount,
    required this.deprecatedKeys,
  });

  final String? projectId;

  /// Canonical locale tag to its key-to-value map.
  final Map<String, Map<String, Object?>> locales;
  final int? keyCount;
  final List<String> deprecatedKeys;
}

/// A failed request, with everything needed to tell somebody what to do.
class DeliveryException implements Exception {
  const DeliveryException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// The one call the CLI makes: `GET /api/delivery/v1/translations`.
class DeliveryClient {
  const DeliveryClient(this._client, {required this.userAgent});

  final http.Client _client;
  final String userAgent;

  /// Every locale in ONE request: the route takes a comma-separated list and
  /// returns all of them in one payload, so there is one rate-limit token
  /// spent per build rather than one per language.
  Future<DeliveryResponse> fetch(
    TranslationsConfig config,
    List<String> locales,
  ) async {
    final uri = config.deliveryUri(locales);
    final http.Response response;
    try {
      response = await _client.get(
        uri,
        headers: {
          // The only place the key is used. It is never logged; failures
          // name its public prefix instead.
          'authorization': 'Bearer ${config.apiKey}',
          'accept': 'application/json',
          'user-agent': userAgent,
        },
      );
    } on SocketException catch (e) {
      throw DeliveryException(
        'Could not reach ${config.host}: ${e.message}. Check your network '
        'and the `host` setting.',
      );
    } on http.ClientException catch (e) {
      throw DeliveryException(
        'Could not reach ${config.host}: ${e.message}. Check your network '
        'and the `host` setting.',
      );
    } on HandshakeException catch (e) {
      throw DeliveryException(
        'TLS handshake with ${config.host} failed: ${e.message}.',
      );
    }

    // DECODED AS UTF-8 FROM THE BYTES, not through `response.body`: package
    // http falls back to latin1 when the content type names no charset, and
    // every accented character in a client's copy would be mangled.
    final text = utf8.decode(response.bodyBytes, allowMalformed: true);

    if (response.statusCode != 200) {
      throw DeliveryException(_describeFailure(config, response, text));
    }

    final Object? json;
    try {
      json = jsonDecode(text);
    } on FormatException {
      throw DeliveryException(
        '${config.host} answered 200 with a body that is not JSON. Is `host` '
        'an impaktfull translations instance?',
      );
    }
    if (json is! Map<String, Object?> ||
        json['locales'] is! Map<String, Object?>) {
      throw DeliveryException(
        '${config.host} answered 200 without a `locales` object. Is `host` '
        'an impaktfull translations instance?',
      );
    }

    final delivered = <String, Map<String, Object?>>{};
    for (final entry in (json['locales']! as Map<String, Object?>).entries) {
      final value = entry.value;
      if (value is! Map<String, Object?>) {
        throw DeliveryException(
          'The delivery response for ${entry.key} is not an object.',
        );
      }
      delivered[entry.key] = value;
    }

    final project = json['project'];
    final meta = json['meta'];
    return DeliveryResponse(
      projectId: project is Map ? project['id']?.toString() : null,
      locales: delivered,
      keyCount: meta is Map && meta['keyCount'] is int
          ? meta['keyCount'] as int
          : null,
      deprecatedKeys: meta is Map && meta['deprecatedKeys'] is List
          ? [for (final k in meta['deprecatedKeys'] as List) k.toString()]
          : const [],
    );
  }
}

/// `401 invalid_api_key: <message>`, then what to do about it.
///
/// THE ENVELOPE IS PRINTED AS THE SERVER SENT IT (spec 17.3), followed by a
/// hint for the statuses a build actually meets. The server deliberately
/// gives the same 401 for an unknown, revoked or archived key, so the hint
/// lists all three rather than guessing.
String _describeFailure(
  TranslationsConfig config,
  http.Response response,
  String body,
) {
  final status = response.statusCode;
  String? code;
  String? message;
  try {
    final json = jsonDecode(body);
    if (json is Map && json['error'] is Map) {
      final error = json['error'] as Map;
      code = error['code']?.toString();
      message = error['message']?.toString();
    }
  } on FormatException {
    // Not the house envelope (a proxy's error page, say): status alone.
  }

  final head = [
    '$status',
    if (code != null) '$code:',
    message ?? response.reasonPhrase ?? 'request failed',
  ].join(' ');

  final key = config.apiKeyLabel;
  final hint = switch (status) {
    401 => 'The API key $key in $envApiKey was refused: it is unknown, '
        'revoked, or its project is archived. Create a new key on the '
        "project's Settings > API keys tab. Keys from dashboard.impaktfull.com "
        'do not work here.',
    403 => 'The API key $key may not read this project.',
    404 => 'The project behind the API key $key was not found or is archived.',
    422 => 'Every entry in `languages` has to be a language of the project. '
        "Add it on the project's Settings > Languages tab, or remove it from "
        '`languages`.',
    429 => 'Too many requests for the API key $key. Try again in '
        '${response.headers['retry-after'] ?? 'a minute'} seconds.',
    400 => null,
    _ when status >= 500 =>
      '${config.host} had a problem answering. Try again in a moment.',
    _ => null,
  };
  return hint == null ? head : '$head\n$hint';
}
