/// Presentation-layer provider declarations for the pokemon_search feature.
///
/// Infrastructure providers (HTTP client, repository, use cases) live in
/// [lib/app/di/pokemon_search_di.dart] — this file only wires the controller.
///
/// Re-exports the use-case providers so screens that only import this file
/// still have access to them (e.g. [getPokemonListProvider]).
export 'package:pok_dex_field_assistant/app/di/pokemon_search_di.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pok_dex_field_assistant/app/di/pokemon_search_di.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/presentation/providers/pokemon_search_controller.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/presentation/providers/pokemon_search_state.dart';

/// Provides [PokemonSearchController] and exposes [PokemonSearchState].
/// Uses [StateNotifierProvider] so widgets rebuild on every state change.
/// The controller depends on [getPokemonListProvider] — never the repository directly.
final pokemonSearchControllerProvider =
    StateNotifierProvider<PokemonSearchController, PokemonSearchState>((ref) {
  /// Inject the use case so the controller stays decoupled from the data layer.
  return PokemonSearchController(ref.watch(getPokemonListProvider));
});
