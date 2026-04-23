/// Riverpod provider declarations for the pokemon_search feature.
/// Dependency graph:
///   pokemonRepositoryProvider → pokemonSearchControllerProvider
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/data/providers/pokemon_data_providers.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/data/models/pokemon_models.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/presentation/providers/pokemon_search_controller.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/presentation/providers/pokemon_search_state.dart';

export 'package:pok_dex_field_assistant/features/pokemon_search/data/providers/pokemon_data_providers.dart';

/// Fetches full detail for a single Pokémon by name or id string.
/// Cached per-name by Riverpod until the provider scope is disposed.
final pokemonDetailProvider =
    FutureProvider.family<PokemonDetail, String>((ref, nameOrId) {
  return ref.watch(pokemonRepositoryProvider).getPokemonDetail(nameOrId);
});

/// Provides [PokemonSearchController] and exposes [PokemonSearchState].
/// Uses [StateNotifierProvider] so widgets rebuild on state changes.
final pokemonSearchControllerProvider =
    StateNotifierProvider<PokemonSearchController, PokemonSearchState>((ref) {
  /// Controller reads the repository — starts loading immediately on creation.
  return PokemonSearchController(ref.watch(pokemonRepositoryProvider));
});

/// Provides an [AudioPlayer] for detail-screen cry playback.
/// Auto-disposed so native resources are always released with the screen scope.
final audioPlayerProvider = Provider.autoDispose<AudioPlayer>((ref) {
  final player = AudioPlayer();
  ref.onDispose(player.dispose);
  return player;
});
