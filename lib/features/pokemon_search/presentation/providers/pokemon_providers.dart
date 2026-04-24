/// Riverpod provider declarations for the pokemon_search feature.
/// Dependency graph:
///   pokemonRepositoryProvider → pokemonSearchControllerProvider
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/data/providers/pokemon_data_providers.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/presentation/providers/pokemon_search_controller.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/presentation/providers/pokemon_search_state.dart';

export 'package:pok_dex_field_assistant/features/pokemon_search/data/providers/pokemon_data_providers.dart';

/// Provides [PokemonSearchController] and exposes [PokemonSearchState].
/// Uses [StateNotifierProvider] so widgets rebuild on state changes.
final pokemonSearchControllerProvider =
    StateNotifierProvider<PokemonSearchController, PokemonSearchState>((ref) {
  /// Controller reads the repository , starts loading immediately on creation.
  return PokemonSearchController(ref.watch(pokemonRepositoryProvider));
});
