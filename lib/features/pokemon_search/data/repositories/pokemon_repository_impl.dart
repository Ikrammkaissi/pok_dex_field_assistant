/// Concrete implementation of [PokemonRepository] backed by [PokeApiHttpClient].
///
/// Lives in the data layer — the only layer allowed to import [PokeApiHttpClient]
/// and JSON parsing mappers.  The domain layer depends on the abstract
/// [PokemonRepository] interface, not this class, so the HTTP implementation
/// can be swapped without touching controllers or use cases.
import 'package:pok_dex_field_assistant/core/logging/app_logger.dart';
import 'package:pok_dex_field_assistant/core/network/http_client.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/data/models/pokemon_detail_mapper.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/domain/entities/pokemon_list_page.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/domain/entities/pokemon_summary.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/domain/entities/pokemon_detail.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/domain/repositories/pokemon_repository.dart';

/// Implements [PokemonRepository] with paginated network calls to PokéAPI.
/// No global in-memory cache — the controller accumulates pages in state.
class PokemonRepositoryImpl implements PokemonRepository {
  /// Logger tag used for all log lines emitted by this class.
  static const _tag = 'PokemonRepository';

  /// HTTP client for PokéAPI calls, injected for testability.
  final PokeApiHttpClient _client;

  /// Creates a [PokemonRepositoryImpl] backed by [client].
  PokemonRepositoryImpl(this._client);

  /// Fetches one page of [limit] Pokémon starting at [offset].
  ///
  /// Strategy:
  /// 1. GET `/pokemon?limit&offset` — returns name + URL pairs only (no sprites/types).
  /// 2. Fire one GET `/pokemon/{name}` per entry concurrently via [Future.wait]
  ///    to minimise wall-clock time (acknowledged N+1; unavoidable with this API).
  /// 3. Derive the sprite URL from the list entry's URL — avoids re-parsing the
  ///    detail JSON for a field that's also calculable from the numeric ID.
  /// 4. Return [PokemonListPage] with [hasMore] derived from the `next` field.
  @override
  Future<PokemonListPage> getPokemonList(
      {int limit = 20, int offset = 0}) async {
    AppLogger.info(
        _tag, 'Fetching page , limit=$limit offset=$offset from network');
    try {
      /// Single lightweight call that returns only name + canonical URL per entry.
      final listJson =
          await _client.get('/pokemon?limit=$limit&offset=$offset');

      /// `results` is the array of {name, url} objects for this page.
      final nameList =
          (listJson['results'] as List<dynamic>).cast<Map<String, dynamic>>();

      /// `next` is non-null when another page exists beyond this one.
      final hasMore = listJson['next'] != null;

      /// Fire all detail calls concurrently to minimise wall-clock time.
      final futures = nameList.map((entry) async {
        /// Each entry contains the Pokémon name and its canonical API URL.
        final name = entry['name'] as String;

        /// The URL encodes the numeric ID — used below to build the sprite URL
        /// without parsing the detail response field.
        final apiUrl = entry['url'] as String;

        /// Fetch the detail JSON; [PokemonDetailMapper] converts it to an entity.
        final detailJson = await _client.get('/pokemon/$name');
        final detail = PokemonDetailMapper.fromJson(detailJson);

        /// Build a lightweight summary for the list view.
        /// Sprite URL derived from list-entry URL — no extra request.
        return PokemonSummary(
          id: detail.id,
          name: detail.name,
          spriteUrl: _spriteUrlFromApiUrl(apiUrl),
          primaryType: detail.types.isNotEmpty ? detail.types.first : '',
        );
      });

      /// Await all concurrent detail calls before returning the page.
      final items = await Future.wait(futures);
      AppLogger.info(
          _tag, 'Loaded ${items.length} Pokémon , hasMore=$hasMore');
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
  /// PokéAPI list entries include a URL such as:
  ///   `https://pokeapi.co/api/v2/pokemon/1/`
  /// Extracting the trailing numeric ID and inserting it into the GitHub raw
  /// sprites path gives the same URL as `sprites.front_default` in the detail
  /// response, without needing to parse that field.
  static String _spriteUrlFromApiUrl(String url) {
    /// Split on `/`, drop empty segments, take the last one — always the numeric ID.
    final id = url.split('/').where((s) => s.isNotEmpty).last;
    return 'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/$id.png';
  }

  /// Fetches full detail for [nameOrId] directly from the network.
  /// No caching — detail is loaded on demand by the detail screen.
  @override
  Future<PokemonDetail> getPokemonDetail(String nameOrId) async {
    AppLogger.debug(_tag, 'Fetching detail for "$nameOrId"');
    try {
      /// Fetch the detail JSON; [PokemonDetailMapper] converts it to an entity.
      final json = await _client.get('/pokemon/$nameOrId');
      final detail = PokemonDetailMapper.fromJson(json);
      AppLogger.debug(
          _tag, 'Loaded detail for "${detail.name}" (#${detail.id})');
      return detail;
    } catch (e, s) {
      AppLogger.error(_tag, 'Failed to fetch detail for "$nameOrId"',
          error: e, stackTrace: s);
      rethrow;
    }
  }
}
