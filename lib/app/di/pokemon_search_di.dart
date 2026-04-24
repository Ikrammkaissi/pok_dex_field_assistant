/// Composition root for the pokemon_search and pokemon_detail features.
///
/// All infrastructure providers (HTTP client, repository impl) and
/// domain use-case providers live here — never in presentation or domain layers.
///
/// Dependency graph:
///   httpClientProvider → pokemonRepositoryProvider
///   pokemonRepositoryProvider → getPokemonListProvider, getPokemonDetailProvider
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:pok_dex_field_assistant/core/network/http_client.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/data/repositories/pokemon_repository_impl.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/domain/repositories/pokemon_repository.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/domain/usecases/get_pokemon_detail.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/domain/usecases/get_pokemon_list.dart';

/// Provides a single shared [PokeApiHttpClient] backed by a real [http.Client].
/// Override in tests with a fake client via [ProviderScope] overrides.
/// [ref.onDispose] closes the underlying connection pool when the scope is destroyed.
final httpClientProvider = Provider<PokeApiHttpClient>((ref) {
  final client = http.Client();
  /// Release the connection pool when the provider scope is torn down.
  ref.onDispose(client.close);
  return PokeApiHttpClient(client);
});

/// Provides the [PokemonRepository] implementation.
/// Declared as the abstract domain type so tests can inject a fake without
/// changing downstream providers.
final pokemonRepositoryProvider = Provider<PokemonRepository>((ref) {
  /// Wire the shared HTTP client into the concrete implementation.
  return PokemonRepositoryImpl(ref.watch(httpClientProvider));
});

/// Provides the [GetPokemonList] use case.
/// Presentation-layer controllers call this — never the repository directly.
/// Keeps the controller decoupled from the data layer.
final getPokemonListProvider = Provider<GetPokemonList>((ref) {
  return GetPokemonList(ref.watch(pokemonRepositoryProvider));
});

/// Provides the [GetPokemonDetail] use case.
/// Used by [pokemonDetailProvider] in the pokemon_detail feature.
/// Injecting the use case prevents the detail screen from importing data types.
final getPokemonDetailProvider = Provider<GetPokemonDetail>((ref) {
  return GetPokemonDetail(ref.watch(pokemonRepositoryProvider));
});
