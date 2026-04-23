/// Abstract contract and concrete implementation for Pokémon data operations.
/// [PokemonRepository] is the interface callers depend on — swap impl in tests.
/// [PokemonRepositoryImpl] calls [PokeApiHttpClient] directly; no datasource layer.
import 'package:pok_dex_field_assistant/core/logging/app_logger.dart';
import 'package:pok_dex_field_assistant/core/network/http_client.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/data/models/pokemon_models.dart';

/// Interface for fetching Pokémon data.
/// Declare dependency on this abstraction so the real impl can be swapped for a fake in tests.
abstract class PokemonRepository {
  /// Returns one page of [limit] Pokémon starting at [offset], enriched with sprite data.
  /// [hasMore] in the result is true when additional pages exist.
  Future<PokemonListPage> getPokemonList({int limit = 20, int offset = 0});

  /// Returns full detail for the Pokémon identified by [nameOrId].
  /// [nameOrId] may be a lowercase name ('bulbasaur') or a numeric string ('1').
  Future<PokemonDetail> getPokemonDetail(String nameOrId);
}

/// Implements [PokemonRepository] with paginated network calls.
/// No global in-memory cache — the controller accumulates pages in state.
class PokemonRepositoryImpl implements PokemonRepository {
  /// Logger tag for this class.
  static const _tag = 'PokemonRepository';

  /// HTTP client for PokéAPI calls — injected for testability.
  final PokeApiHttpClient _client;

  /// Creates a [PokemonRepositoryImpl] backed by [client].
  PokemonRepositoryImpl(this._client);

  /// Fetches one page of Pokémon starting at [offset] with [limit] entries.
  /// Fires detail calls concurrently to minimise wall-clock time.
  /// Returns a [PokemonListPage] with [hasMore] derived from the [next] field.
  @override
  Future<PokemonListPage> getPokemonList(
      {int limit = 20, int offset = 0}) async {
    AppLogger.info(
        _tag, 'Fetching page — limit=$limit offset=$offset from network');
    try {
      /// Single lightweight call to get name+url pairs for this page.
      final listJson =
          await _client.get('/pokemon?limit=$limit&offset=$offset');

      /// results is the array of name+url objects.
      final nameList =
          (listJson['results'] as List<dynamic>).cast<Map<String, dynamic>>();

      /// next is non-null when another page exists.
      final hasMore = listJson['next'] != null;

      /// Fire all detail calls concurrently to minimise wall-clock time.
      final futures = nameList.map((entry) async {
        /// Each entry has a name and a canonical API URL with the Pokémon ID.
        final name = entry['name'] as String;
        final apiUrl = entry['url'] as String;

        /// Detail endpoint returns types — still needed; sprite derived from URL.
        final detailJson = await _client.get('/pokemon/$name');
        final detail = PokemonDetail.fromJson(detailJson);

        /// Derive sprite URL from the list entry's API URL — no extra request,
        /// no dependence on the detail JSON sprite field being non-null.
        return PokemonSummary(
          id: detail.id,
          name: detail.name,
          spriteUrl: _spriteUrlFromApiUrl(apiUrl),
          primaryType: detail.types.isNotEmpty ? detail.types.first : '',
        );
      });

      final items = await Future.wait(futures);
      AppLogger.info(
          _tag, 'Loaded ${items.length} Pokémon — hasMore=$hasMore');
      return PokemonListPage(items: items, hasMore: hasMore);
    } catch (e, s) {
      /// Log unexpected failures before propagating — callers handle recovery.
      AppLogger.error(_tag, 'Failed to load Pokémon list',
          error: e, stackTrace: s);
      rethrow;
    }
  }

  /// Derives the front-default sprite CDN URL from a PokéAPI resource URL.
  ///
  /// PokéAPI list entries include a canonical URL such as:
  ///   `https://pokeapi.co/api/v2/pokemon/1/`
  /// Extracting the trailing numeric ID and inserting it into the sprite CDN
  /// path gives the same URL as `sprites.front_default` in the detail response,
  /// without parsing the detail JSON for this value.
  ///
  /// Example: `https://pokeapi.co/api/v2/pokemon/1/`
  ///       → `https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/1.png`
  static String _spriteUrlFromApiUrl(String url) {
    /// Last non-empty segment of the path is always the numeric Pokémon ID.
    final id = url.split('/').where((s) => s.isNotEmpty).last;
    return 'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/$id.png';
  }

  /// Fetches full detail for [nameOrId] directly from the network.
  /// No caching — detail is loaded on demand.
  @override
  Future<PokemonDetail> getPokemonDetail(String nameOrId) async {
    AppLogger.debug(_tag, 'Fetching detail for "$nameOrId"');
    try {
      /// Fetch and parse the detail JSON directly from the HTTP client.
      final json = await _client.get('/pokemon/$nameOrId');
      return PokemonDetail.fromJson(json);
    } catch (e, s) {
      AppLogger.error(_tag, 'Failed to fetch detail for "$nameOrId"',
          error: e, stackTrace: s);
      rethrow;
    }
  }
}
