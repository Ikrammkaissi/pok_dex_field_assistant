/// Riverpod provider declarations for the pokemon_search feature.
/// Dependency graph:
///   httpClientProvider → pokemonRepositoryProvider → pokemonSearchControllerProvider
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:pok_dex_field_assistant/core/network/http_client.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/data/models/pokemon_models.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/data/pokemon_repository.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/presentation/providers/pokemon_search_controller.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/presentation/providers/pokemon_search_state.dart';

/// Provides a single shared [PokeApiHttpClient] backed by a real [http.Client].
/// Override in tests with a fake client via [ProviderScope] overrides.
final httpClientProvider = Provider<PokeApiHttpClient>((ref) {
  /// Create a long-lived http.Client — not recreated on every request.
  final client = http.Client();

  /// Dispose the client when the provider scope is destroyed.
  ref.onDispose(client.close);
  return PokeApiHttpClient(client);
});

/// Provides the [PokemonRepository] implementation.
/// Declared as [PokemonRepository] (abstract) so overrides can inject a fake.
final pokemonRepositoryProvider = Provider<PokemonRepository>((ref) {
  /// Wire the impl directly to the HTTP client — no datasource layer.
  return PokemonRepositoryImpl(ref.watch(httpClientProvider));
});

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
