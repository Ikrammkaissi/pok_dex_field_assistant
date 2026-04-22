/// Thin HTTP wrapper scoped to the PokéAPI base URL.
/// Translates all failure modes into typed exceptions so callers never
/// handle raw [http.Response] or socket errors directly.
/// Inject a fake [http.Client] in tests to avoid real network calls.
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:pok_dex_field_assistant/core/error/exceptions.dart';
import 'package:pok_dex_field_assistant/core/logging/app_logger.dart';

/// Wraps [http.Client] with PokéAPI-scoped GET requests and typed error handling.
class PokeApiHttpClient {
  /// PokéAPI v2 base URL — all [get] paths are appended here.
  static const _baseUrl = 'https://pokeapi.co/api/v2';

  /// Logger tag for this class.
  static const _tag = 'HttpClient';

  /// The underlying HTTP client — injected so tests can substitute a fake.
  final http.Client _client;

  /// Creates a [PokeApiHttpClient] backed by [client].
  const PokeApiHttpClient(this._client);

  /// Sends `GET [_baseUrl][path]` and returns the decoded JSON body as a map.
  ///
  /// [path] must start with `/` (e.g. `/pokemon?limit=100`).
  ///
  /// Throws:
  /// - [NetworkException] for socket or connectivity failures.
  /// - [ServerException] for non-2xx HTTP responses.
  /// - [ParseException] if the body is not a valid JSON object.
  Future<Map<String, dynamic>> get(String path) async {
    /// Build the full URI by appending path to the base URL.
    final uri = Uri.parse('$_baseUrl$path');
  //  AppLogger.debug(_tag, 'GET $uri');

    try {
      /// Send request — SocketException propagates on network failure.
      final response = await _client.get(uri);

      /// Treat any 2xx status code as success.
      if (response.statusCode >= 200 && response.statusCode < 300) {
       AppLogger.debug(_tag, '${response.statusCode} OK — $path');
        return _decodeBody(response.body, path);
      }

      /// Non-2xx means a server-side error.
      AppLogger.warning(_tag, 'Server error ${response.statusCode} — $path');
      throw ServerException(
        statusCode: response.statusCode,
        message: 'HTTP ${response.statusCode} for $path',
      );
    } on SocketException catch (e, s) {
      /// No connectivity, DNS failure, or connection refused.
      AppLogger.error(_tag, 'Network failure — $path',
          error: e, stackTrace: s);
      throw NetworkException('Network error: ${e.message}');
    } on ServerException {
      /// Already typed and logged above — propagate unchanged.
      rethrow;
    } on ParseException catch (e, s) {
      /// Log parse failures so we know which endpoint returned bad JSON.
      AppLogger.error(_tag, 'Parse failure — $path', error: e, stackTrace: s);
      rethrow;
    } catch (e, s) {
      /// Catch-all for TLS failures, timeouts, and other unexpected errors.
      AppLogger.error(_tag, 'Unexpected error — $path', error: e, stackTrace: s);
      throw NetworkException('Unexpected error: $e');
    }
  }

  /// Decodes [body] as a JSON object map.
  /// Throws [ParseException] if the body is not valid JSON or not a map.
  Map<String, dynamic> _decodeBody(String body, String path) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
      /// PokéAPI always returns a JSON object at the top level.
      throw ParseException(
          'Expected JSON object at $path, got ${decoded.runtimeType}');
    } on FormatException catch (e) {
      throw ParseException('Invalid JSON at $path: ${e.message}');
    }
  }
}
