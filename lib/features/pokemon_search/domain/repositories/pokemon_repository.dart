/// Domain contract for Pokémon data operations.
///
/// Lives in the domain layer so presentation (use cases, controllers) depends
/// on this abstraction, never on the concrete HTTP implementation.
/// Swap [PokemonRepositoryImpl] for a fake in tests via Riverpod overrides.
///
/// Imports only domain entities — zero data-layer or framework dependencies.
import 'package:pok_dex_field_assistant/features/pokemon_search/domain/entities/pokemon_detail.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/domain/entities/pokemon_list_page.dart';

/// Interface that defines how Pokémon data is fetched.
/// Concrete implementations (e.g. [PokemonRepositoryImpl]) live in the data layer.
abstract class PokemonRepository {
  /// Returns one page of [limit] Pokémon starting at [offset], enriched with
  /// sprite and type data. [PokemonListPage.hasMore] is true when further pages exist.
  Future<PokemonListPage> getPokemonList({int limit = 20, int offset = 0});

  /// Returns full detail for the Pokémon identified by [nameOrId].
  /// [nameOrId] may be a lowercase name ('bulbasaur') or a numeric string ('1').
  Future<PokemonDetail> getPokemonDetail(String nameOrId);
}
