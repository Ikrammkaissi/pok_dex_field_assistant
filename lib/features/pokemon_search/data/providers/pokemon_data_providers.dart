/// Data-layer providers for the pokemon_search feature.
///
/// Dependency graph (left → right = depends on):
///   httpClientProvider → pokemonRepositoryProvider
///   pokemonRepositoryProvider → getPokemonListProvider
///   pokemonRepositoryProvider → getPokemonDetailProvider
///
/// Presentation layer imports only the use-case providers; it never imports
/// the repository or HTTP client providers directly.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:pok_dex_field_assistant/core/network/http_client.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/data/repositories/pokemon_repository_impl.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/domain/repositories/pokemon_repository.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/domain/usecases/get_pokemon_detail.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/domain/usecases/get_pokemon_list.dart';

/// Provides a single shared [PokeApiHttpClient] backed by a real [http.Client].
/// Override in tests with a fake client via [ProviderScope] overrides.
/// [ref.onDispose] closes the underlying [http.Client] when the scope is destroyed.
final httpClientProvider = Provider<PokeApiHttpClient>((ref) {
  final client = http.Client();
  /// Release the connection pool when the provider scope is torn down.
  ref.onDispose(client.close);
  return PokeApiHttpClient(client);
});

/// Provides the [PokemonRepository] implementation.
/// Declared as the abstract type so test overrides can inject a fake without
/// changing downstream providers.
final pokemonRepositoryProvider = Provider<PokemonRepository>((ref) {
  /// Wire the shared HTTP client into the concrete implementation.
  return PokemonRepositoryImpl(ref.watch(httpClientProvider));
});

/// Provides the [GetPokemonList] use case.
/// Controllers call this rather than the repository directly, keeping the
/// presentation layer decoupled from the data layer.
final getPokemonListProvider = Provider<GetPokemonList>((ref) {
  return GetPokemonList(ref.watch(pokemonRepositoryProvider));
});

/// Provides the [GetPokemonDetail] use case.
/// Used by [pokemonDetailProvider] in the pokemon_detail feature so the detail
/// screen never imports data-layer types.
final getPokemonDetailProvider = Provider<GetPokemonDetail>((ref) {
  return GetPokemonDetail(ref.watch(pokemonRepositoryProvider));
});
