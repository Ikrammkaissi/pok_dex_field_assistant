/// Riverpod provider declarations for the pokemon_search feature.
/// Dependency graph:
///   getPokemonListProvider → pokemonSearchControllerProvider
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/data/providers/pokemon_data_providers.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/presentation/providers/pokemon_search_controller.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/presentation/providers/pokemon_search_state.dart';

/// Re-exports data-layer providers so screens only need to import this file.
export 'package:pok_dex_field_assistant/features/pokemon_search/data/providers/pokemon_data_providers.dart';

/// Provides [PokemonSearchController] and exposes [PokemonSearchState].
/// Uses [StateNotifierProvider] so widgets rebuild on every state change.
/// The controller calls [getPokemonListProvider] — never the repository directly.
final pokemonSearchControllerProvider =
    StateNotifierProvider<PokemonSearchController, PokemonSearchState>((ref) {
  /// Inject the GetPokemonList use case so the controller stays decoupled
  /// from the data layer.
  return PokemonSearchController(ref.watch(getPokemonListProvider));
});
