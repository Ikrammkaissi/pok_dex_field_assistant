/// Use case: fetch one paginated page of Pokémon.
///
/// Single-responsibility class that wraps [PokemonRepository.getPokemonList].
/// Controllers call this instead of the repository directly, keeping the
/// presentation layer decoupled from the data layer.
///
/// Imports only domain types — zero data-layer or framework dependencies.
import 'package:pok_dex_field_assistant/features/pokemon_search/domain/entities/pokemon_list_page.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/domain/repositories/pokemon_repository.dart';

/// Encapsulates the "load one page of Pokémon" operation.
/// Injected into [PokemonSearchController] via Riverpod so it can be replaced
/// with a fake use case in tests without touching the provider graph.
class GetPokemonList {
  /// Repository that supplies the actual data.
  final PokemonRepository _repository;

  /// Creates [GetPokemonList] backed by [repository].
  GetPokemonList(this._repository);

  /// Fetches one page of [limit] Pokémon starting at [offset].
  /// Delegates to [PokemonRepository.getPokemonList] and returns a [PokemonListPage].
  Future<PokemonListPage> call({int limit = 20, int offset = 0}) =>
      _repository.getPokemonList(limit: limit, offset: offset);
}
