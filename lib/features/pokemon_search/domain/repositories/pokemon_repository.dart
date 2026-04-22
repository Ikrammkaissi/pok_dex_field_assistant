/// Abstract contract for all Pokémon data operations.
/// The domain layer depends on this interface; the data layer implements it.
/// Callers (providers, controllers) depend only on this abstraction so
/// the real implementation can be swapped for a fake in tests.
import 'package:pok_dex_field_assistant/features/pokemon_search/domain/entities/pokemon_detail.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/domain/entities/pokemon_list_item.dart';

/// Interface for fetching and searching Pokémon data.
abstract class PokemonRepository {
  /// Returns the first [limit] Pokémon enriched with type and sprite data.
  /// Results are cached after the first call; subsequent calls return instantly.
  Future<List<PokemonListItem>> getPokemonList({int limit = 151});

  /// Filters the cached list to entries whose name contains [query]
  /// (case-insensitive substring match).
  /// Populates the cache via [getPokemonList] if it is empty.
  /// Returns all items when [query] is empty.
  Future<List<PokemonListItem>> searchPokemon(String query);

  /// Returns full detail for the Pokémon identified by [nameOrId].
  /// [nameOrId] may be a lowercase name ('bulbasaur') or a numeric string ('1').
  Future<PokemonDetail> getPokemonDetail(String nameOrId);
}
