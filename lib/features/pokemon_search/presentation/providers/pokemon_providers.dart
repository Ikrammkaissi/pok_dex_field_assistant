/// Riverpod provider declarations for the pokemon_search feature.
/// Dependency graph (each provider reads the one above it):
///   httpClientProvider → pokemonDatasourceProvider
///     → pokemonRepositoryProvider → pokemonSearchControllerProvider
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:pok_dex_field_assistant/core/network/http_client.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/data/datasources/pokemon_remote_datasource.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/data/repositories/pokemon_repository_impl.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/domain/repositories/pokemon_repository.dart';
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

/// Provides [PokemonRemoteDatasource] wired to [httpClientProvider].
final pokemonDatasourceProvider = Provider<PokemonRemoteDatasource>((ref) {
  /// Reads the HTTP client from the provider above.
  return PokemonRemoteDatasource(ref.watch(httpClientProvider));
});

/// Provides the [PokemonRepository] implementation.
/// Declared as [PokemonRepository] (abstract) so overrides can inject a fake.
final pokemonRepositoryProvider = Provider<PokemonRepository>((ref) {
  return PokemonRepositoryImpl(ref.watch(pokemonDatasourceProvider));
});

/// Provides the [PokemonSearchController] and exposes [PokemonSearchState].
/// Uses [StateNotifierProvider] so widgets rebuild on state changes.
final pokemonSearchControllerProvider =
    StateNotifierProvider<PokemonSearchController, PokemonSearchState>((ref) {
  /// Controller reads the repository — starts loading immediately on creation.
  return PokemonSearchController(ref.watch(pokemonRepositoryProvider));
});
