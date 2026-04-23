/// Data-layer providers for the pokemon_search feature.
/// Dependency graph:
///   httpClientProvider → pokemonRepositoryProvider
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:pok_dex_field_assistant/core/network/http_client.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/data/pokemon_repository.dart';

/// Provides a single shared [PokeApiHttpClient] backed by a real [http.Client].
/// Override in tests with a fake client via [ProviderScope] overrides.
final httpClientProvider = Provider<PokeApiHttpClient>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return PokeApiHttpClient(client);
});

/// Provides the [PokemonRepository] implementation.
/// Declared as [PokemonRepository] (abstract) so overrides can inject a fake.
final pokemonRepositoryProvider = Provider<PokemonRepository>((ref) {
  return PokemonRepositoryImpl(ref.watch(httpClientProvider));
});
