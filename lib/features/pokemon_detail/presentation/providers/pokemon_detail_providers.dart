/// Riverpod providers for the pokemon_detail feature.
///
/// Dependency graph (left → right = depends on):
///   getPokemonDetailProvider (from pokemon_search data layer)
///   → pokemonDetailProvider
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/data/models/pokemon_models.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/data/providers/pokemon_data_providers.dart';

/// Fetches full detail for a single Pokémon identified by name or numeric id string.
///
/// Uses [GetPokemonDetail] use case so the detail screen never imports data-layer
/// types directly.  Riverpod caches one result per [nameOrId] for the lifetime
/// of the [ProviderScope] — re-navigating to the same detail screen = zero API calls.
final pokemonDetailProvider =
    FutureProvider.family<PokemonDetail, String>((ref, nameOrId) {
  /// Delegate to the use case; the use case calls the repository.
  return ref.watch(getPokemonDetailProvider).call(nameOrId);
});

/// Provides an [AudioPlayer] for detail-screen Pokémon cry playback.
/// [autoDispose] ensures the native audio resources are always released
/// when the detail screen leaves the widget tree.
final audioPlayerProvider = Provider.autoDispose<AudioPlayer>((ref) {
  final player = AudioPlayer();
  /// Release the native player when the provider scope is destroyed.
  ref.onDispose(player.dispose);
  return player;
});
