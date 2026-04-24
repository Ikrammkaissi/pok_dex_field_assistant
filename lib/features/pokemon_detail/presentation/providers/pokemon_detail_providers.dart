/// Riverpod providers for the pokemon_detail feature.
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/data/models/pokemon_models.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/data/providers/pokemon_data_providers.dart';

/// Fetches full detail for a single Pokémon by name or id string.
/// Cached per-name by Riverpod until the provider scope is disposed.
final pokemonDetailProvider =
    FutureProvider.family<PokemonDetail, String>((ref, nameOrId) {
  return ref.watch(pokemonRepositoryProvider).getPokemonDetail(nameOrId);
});

/// Provides an [AudioPlayer] for detail-screen cry playback.
/// Auto-disposed so native resources are always released with the screen scope.
final audioPlayerProvider = Provider.autoDispose<AudioPlayer>((ref) {
  final player = AudioPlayer();
  ref.onDispose(player.dispose);
  return player;
});
