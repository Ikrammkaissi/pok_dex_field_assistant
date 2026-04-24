/// Riverpod provider declarations for the weather feature.
///
/// Dependency graph (left → right = depends on):
///   weatherHttpClientProvider ──┐
///                               ├→ weatherRepositoryProvider
///   httpClientProvider (PokeAPI)┘
///   weatherRepositoryProvider → getCurrentWeatherProvider, getPokemonByTypeProvider
///   getCurrentWeatherProvider + getPokemonByTypeProvider → weatherControllerProvider
///
/// Presentation layer imports only the use-case and controller providers;
/// it never imports the repository or HTTP client providers directly.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:pok_dex_field_assistant/core/network/weather_http_client.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/data/providers/pokemon_data_providers.dart';
import 'package:pok_dex_field_assistant/features/weather/data/repositories/weather_repository_impl.dart';
import 'package:pok_dex_field_assistant/features/weather/domain/repositories/weather_repository.dart';
import 'package:pok_dex_field_assistant/features/weather/domain/usecases/get_current_weather.dart';
import 'package:pok_dex_field_assistant/features/weather/domain/usecases/get_pokemon_by_type.dart';
import 'package:pok_dex_field_assistant/features/weather/presentation/providers/weather_controller.dart';
import 'package:pok_dex_field_assistant/features/weather/presentation/providers/weather_state.dart';

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
/// Declared as the abstract type so tests can inject a fake.
/// Depends on both HTTP clients: [weatherHttpClientProvider] for Open-Meteo
/// and [httpClientProvider] for the PokéAPI type endpoint.
final weatherRepositoryProvider = Provider<WeatherRepository>((ref) {
  /// Wire both clients into the implementation.
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

/// Provides [WeatherController] and exposes [WeatherState].
/// [autoDispose] ensures the controller is recreated each time the weather screen
/// opens — always shows fresh weather data, no stale state from a previous visit.
final weatherControllerProvider =
    StateNotifierProvider.autoDispose<WeatherController, WeatherState>((ref) {
  /// Inject both use cases so the controller never imports data-layer types.
  return WeatherController(
    ref.watch(getCurrentWeatherProvider),
    ref.watch(getPokemonByTypeProvider),
  );
});
