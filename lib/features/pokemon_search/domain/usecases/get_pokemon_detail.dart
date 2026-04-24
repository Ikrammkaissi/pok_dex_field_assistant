/// Use case: fetch full detail for a single Pokémon.
///
/// Single-responsibility class that wraps [PokemonRepository.getPokemonDetail].
/// Used by [pokemonDetailProvider] in the pokemon_detail feature so the
/// presentation layer never imports the data layer directly.
///
/// Imports only domain types — zero data-layer or framework dependencies.
import 'package:pok_dex_field_assistant/features/pokemon_search/domain/entities/pokemon_detail.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/domain/repositories/pokemon_repository.dart';

/// Encapsulates the "load detail for one Pokémon" operation.
/// Injected via [getPokemonDetailProvider] so tests can replace it without
/// touching the provider graph.
class GetPokemonDetail {
  /// Repository that supplies the actual data.
  final PokemonRepository _repository;

  /// Creates [GetPokemonDetail] backed by [repository].
  GetPokemonDetail(this._repository);

  /// Fetches full detail for the Pokémon identified by [nameOrId].
  /// [nameOrId] may be a lowercase name ('bulbasaur') or a numeric id string ('1').
  Future<PokemonDetail> call(String nameOrId) =>
      _repository.getPokemonDetail(nameOrId);
}
