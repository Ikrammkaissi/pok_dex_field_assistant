/// Remote data source — all raw PokéAPI HTTP calls live here.
/// Returns DTOs only; never domain entities.
/// Injecting [PokeApiHttpClient] allows tests to substitute a fake client.
import 'package:pok_dex_field_assistant/core/network/http_client.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/data/models/pokemon_detail_model.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/data/models/pokemon_list_item_model.dart';

/// Handles all outbound calls to the PokéAPI for Pokémon data.
class PokemonRemoteDatasource {
  /// Injected HTTP client — replace with a fake in tests.
  final PokeApiHttpClient _client;

  /// Creates a [PokemonRemoteDatasource] backed by [client].
  const PokemonRemoteDatasource(this._client);

  /// Fetches the raw name+url list from `/pokemon?limit=[limit]&offset=0`.
  /// Returns each entry as `{'name': String, 'url': String}`.
  /// The list endpoint does not include types or sprites — those require a
  /// separate detail call per Pokémon.
  Future<List<Map<String, dynamic>>> fetchPokemonNameList(int limit) async {
    /// Single cheap request to get all Pokémon names up to [limit].
    final json = await _client.get('/pokemon?limit=$limit&offset=0');
    /// `results` is the array of name+url objects.
    final results = json['results'] as List<dynamic>;
    return results.cast<Map<String, dynamic>>();
  }

  /// Fetches full detail for [nameOrId] from `/pokemon/[nameOrId]`.
  /// Returns a [PokemonDetailModel] with types, sprites, stats, abilities.
  Future<PokemonDetailModel> fetchPokemonDetail(String nameOrId) async {
    /// Detail endpoint returns all fields in one response.
    final json = await _client.get('/pokemon/$nameOrId');
    return PokemonDetailModel.fromJson(json);
  }

  /// Fetches [limit] Pokémon with type and sprite data.
  ///
  /// Strategy:
  /// 1. One call to the list endpoint to get names.
  /// 2. Parallel [Future.wait] of detail calls to get types and sprites.
  ///
  /// All [limit] detail calls fire concurrently — suitable for 151 Pokémon.
  Future<List<PokemonListItemModel>> fetchEnrichedList(int limit) async {
    /// Get names first; the list endpoint is a single lightweight call.
    final nameList = await fetchPokemonNameList(limit);

    /// Fire all detail calls at the same time to minimise wall-clock time.
    final futures = nameList.map((entry) {
      /// Each entry has a `name` field we pass to the detail endpoint.
      final name = entry['name'] as String;
      return fetchPokemonDetail(name).then(
        (detail) => PokemonListItemModel(
          id: detail.id,
          name: detail.name,
          spriteUrl: detail.spriteUrl,
          /// Slot 0 is always the primary type; fall back to 'unknown' if empty.
          primaryType: detail.types.isNotEmpty ? detail.types.first : 'unknown',
        ),
      );
    });

    /// Await all parallel calls and collect results in order.
    return Future.wait(futures);
  }
}
