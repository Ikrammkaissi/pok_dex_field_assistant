/// Composition root for the weather feature.
///
/// All infrastructure providers (HTTP clients, repository impl) and
/// domain use-case providers live here — never in presentation or domain layers.
///
/// Dependency graph:
///   weatherHttpClientProvider ──┐
///                               ├→ weatherRepositoryProvider
///   httpClientProvider (PokeAPI)┘
///   weatherRepositoryProvider → getCurrentWeatherProvider, getPokemonByTypeProvider
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:pok_dex_field_assistant/app/di/pokemon_search_di.dart';
import 'package:pok_dex_field_assistant/core/network/weather_http_client.dart';
import 'package:pok_dex_field_assistant/features/weather/data/repositories/weather_repository_impl.dart';
import 'package:pok_dex_field_assistant/features/weather/domain/repositories/weather_repository.dart';
import 'package:pok_dex_field_assistant/features/weather/domain/usecases/get_current_weather.dart';
import 'package:pok_dex_field_assistant/features/weather/domain/usecases/get_pokemon_by_type.dart';

/// Provides a single shared [WeatherHttpClient] backed by a real [http.Client].
/// Override in tests with a fake client via [ProviderScope] overrides.
/// [ref.onDispose] closes the underlying connection pool when the scope is destroyed.
final weatherHttpClientProvider = Provider<WeatherHttpClient>((ref) {
  final client = http.Client();
  /// Release the connection pool when the provider scope is torn down.
  ref.onDispose(client.close);
  return WeatherHttpClient(client);
});

/// Provides the [WeatherRepository] implementation.
/// Declared as the abstract domain type so tests can inject a fake.
/// Depends on both HTTP clients: [weatherHttpClientProvider] for Open-Meteo
/// and [httpClientProvider] for the PokéAPI type endpoint.
final weatherRepositoryProvider = Provider<WeatherRepository>((ref) {
  return WeatherRepositoryImpl(
    ref.watch(weatherHttpClientProvider),
    ref.watch(httpClientProvider),
  );
});

/// Provides the [GetCurrentWeather] use case.
/// [WeatherController] calls this to fetch live weather for the active coordinates.
final getCurrentWeatherProvider = Provider<GetCurrentWeather>((ref) {
  return GetCurrentWeather(ref.watch(weatherRepositoryProvider));
});

/// Provides the [GetPokemonByType] use case.
/// [WeatherController] calls this after deriving the suggested type from weather.
final getPokemonByTypeProvider = Provider<GetPokemonByType>((ref) {
  return GetPokemonByType(ref.watch(weatherRepositoryProvider));
});
