/// Abstract contract and concrete implementation for Pokémon data operations.
/// [PokemonRepository] is the interface callers depend on — swap impl in tests.
/// [PokemonRepositoryImpl] calls [PokeApiHttpClient] directly; no datasource layer.
import 'package:pok_dex_field_assistant/core/logging/app_logger.dart';
import 'package:pok_dex_field_assistant/core/network/http_client.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/data/models/pokemon_models.dart';

/// Interface for fetching and searching Pokémon data.
/// Declare dependency on this abstraction so the real impl can be swapped for a fake in tests.
abstract class PokemonRepository {
  /// Returns the first [limit] Pokémon enriched with type and sprite data.
  /// Results are cached after the first call; subsequent calls return instantly.
  Future<List<PokemonSummary>> getPokemonList({int limit = 151});

  /// Filters the cached list to entries whose name contains [query] (case-insensitive).
  /// Returns all items when [query] is empty.
  Future<List<PokemonSummary>> searchPokemon(String query);

  /// Returns full detail for the Pokémon identified by [nameOrId].
  /// [nameOrId] may be a lowercase name ('bulbasaur') or a numeric string ('1').
  Future<PokemonDetail> getPokemonDetail(String nameOrId);
}

/// Implements [PokemonRepository] with network calls and an in-memory cache.
class PokemonRepositoryImpl implements PokemonRepository {
  /// Logger tag for this class.
  static const _tag = 'PokemonRepository';

  /// HTTP client for PokéAPI calls — injected for testability.
  final PokeApiHttpClient _client;

  /// In-memory cache populated on the first [getPokemonList] call.
  /// Null means the cache has not been loaded yet.
  List<PokemonSummary>? _cache;

  /// Creates a [PokemonRepositoryImpl] backed by [client].
  PokemonRepositoryImpl(this._client);

  /// Returns the cached list or fetches from the network if the cache is empty.
  /// After the first successful fetch, subsequent calls are O(1).
  @override
  Future<List<PokemonSummary>> getPokemonList({int limit = 151}) async {
    /// Return immediately if the cache is already populated.
    if (_cache != null) {
      AppLogger.debug(_tag, 'Cache hit — returning ${_cache!.length} items');
      return _cache!;
    }

    AppLogger.info(_tag, 'Cache miss — fetching $limit Pokémon from network');
    try {
      /// Single lightweight call to get all Pokémon names up to [limit].
      final listJson = await _client.get('/pokemon?limit=$limit&offset=0');

      /// results is the array of name+url objects from the list endpoint.
      final nameList =
          (listJson['results'] as List<dynamic>).cast<Map<String, dynamic>>();

      /// Fire all detail calls concurrently to minimise wall-clock time.
      final futures = nameList.map((entry) async {
        /// Each entry has a name field we pass to the detail endpoint.
        final name = entry['name'] as String;

        /// Detail endpoint returns all fields including types and sprites.
        final detailJson = await _client.get('/pokemon/$name');
        final detail = PokemonDetail.fromJson(detailJson);

        /// Build summary from detail — list endpoint has no sprites.
        return PokemonSummary(
          id: detail.id,
          name: detail.name,
          spriteUrl: detail.spriteUrl,
        );
      });

      /// Await all parallel calls and store results in cache.
      _cache = await Future.wait(futures);
      AppLogger.info(_tag, 'Loaded ${_cache!.length} Pokémon into cache');
      return _cache!;
    } catch (e, s) {
      /// Log unexpected failures before propagating — callers handle recovery.
      AppLogger.error(_tag, 'Failed to load Pokémon list',
          error: e, stackTrace: s);
      rethrow;
    }
  }

  /// Filters the cached list to entries whose name contains [query].
  /// Match is case-insensitive substring; e.g. 'char' matches 'charizard'.
  /// Returns all items when [query] is empty.
  @override
  Future<List<PokemonSummary>> searchPokemon(String query) async {
    /// Ensure the cache is populated before filtering.
    final list = await getPokemonList();

    /// Empty query means show everything.
    if (query.isEmpty) return list;

    /// Lowercase the query once rather than per-iteration.
    final lower = query.toLowerCase();

    /// Filter by substring match on the Pokémon name.
    final results = list.where((p) => p.name.contains(lower)).toList();
    AppLogger.debug(_tag, 'Search "$query" → ${results.length} result(s)');
    return results;
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
