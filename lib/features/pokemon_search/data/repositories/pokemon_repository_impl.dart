/// Concrete implementation of [PokemonRepository].
/// Holds an in-memory cache of the enriched Pokémon list so search queries
/// never trigger additional HTTP calls after the first load.
import 'package:pok_dex_field_assistant/features/pokemon_search/data/datasources/pokemon_remote_datasource.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/domain/entities/pokemon_detail.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/domain/entities/pokemon_list_item.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/domain/repositories/pokemon_repository.dart';

/// Implements [PokemonRepository] with network calls and an in-memory cache.
class PokemonRepositoryImpl implements PokemonRepository {
  /// Remote data source for raw API calls — injected for testability.
  final PokemonRemoteDatasource _datasource;

  /// In-memory cache populated on the first [getPokemonList] call.
  /// Null means the cache has not been loaded yet.
  List<PokemonListItem>? _cache;

  /// Creates a [PokemonRepositoryImpl] backed by [datasource].
  PokemonRepositoryImpl(this._datasource);

  /// Returns the cached list or fetches from the network if the cache is empty.
  /// After the first successful fetch, subsequent calls are O(1).
  @override
  Future<List<PokemonListItem>> getPokemonList({int limit = 151}) async {
    /// Return immediately if the cache is already populated.
    if (_cache != null) return _cache!;

    /// Fetch enriched list: one list call + parallel detail calls.
    final models = await _datasource.fetchEnrichedList(limit);
    /// Convert DTOs to domain entities and store in cache.
    _cache = models.map((m) => m.toEntity()).toList();
    return _cache!;
  }

  /// Filters the cached list to entries whose name contains [query].
  /// Match is case-insensitive substring; e.g. 'char' matches 'charizard'.
  /// Returns all items when [query] is empty.
  @override
  Future<List<PokemonListItem>> searchPokemon(String query) async {
    /// Ensure the cache is populated before filtering.
    final list = await getPokemonList();
    /// Empty query means show everything.
    if (query.isEmpty) return list;

    /// Lowercase the query once rather than per-iteration.
    final lower = query.toLowerCase();
    /// Filter by substring match on the Pokémon name.
    return list.where((p) => p.name.contains(lower)).toList();
  }

  /// Fetches full detail for [nameOrId] directly from the network.
  /// No caching — detail screens are opened infrequently.
  @override
  Future<PokemonDetail> getPokemonDetail(String nameOrId) async {
    /// Delegate to the datasource and convert the DTO to a domain entity.
    final model = await _datasource.fetchPokemonDetail(nameOrId);
    return model.toEntity();
  }
}
