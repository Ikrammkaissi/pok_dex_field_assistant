/// Riverpod provider declarations for the weather feature.
/// Dependency graph:
///   weatherHttpClientProvider ──┐
///                               ├→ weatherRepositoryProvider → weatherControllerProvider
///   httpClientProvider (PokeAPI)┘
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:pok_dex_field_assistant/core/network/weather_http_client.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/data/providers/pokemon_data_providers.dart';
import 'package:pok_dex_field_assistant/features/weather/data/weather_repository.dart';
import 'package:pok_dex_field_assistant/features/weather/presentation/providers/weather_controller.dart';
import 'package:pok_dex_field_assistant/features/weather/presentation/providers/weather_state.dart';

/// Provides a single shared [WeatherHttpClient] backed by a real [http.Client].
/// Override in tests with a fake client via [ProviderScope] overrides.
final weatherHttpClientProvider = Provider<WeatherHttpClient>((ref) {
  /// Create a long-lived http.Client — not recreated on every request.
  final client = http.Client();

  /// Dispose the client when the provider scope is destroyed.
  ref.onDispose(client.close);
  return WeatherHttpClient(client);
});

/// Provides the [WeatherRepository] implementation.
/// Declared as [WeatherRepository] (abstract) so overrides can inject a fake.
/// Depends on [weatherHttpClientProvider] for weather data and
/// [httpClientProvider] for the PokéAPI type endpoint.
final weatherRepositoryProvider = Provider<WeatherRepository>((ref) {
  /// Wire both HTTP clients into the repository implementation.
  return WeatherRepositoryImpl(
    ref.watch(weatherHttpClientProvider),
    ref.watch(httpClientProvider),
  );
});

/// Provides [WeatherController] and exposes [WeatherState].
/// Uses [autoDispose] so the controller is recreated (and re-fetches) each time
/// the weather screen is opened — always shows fresh weather data.
final weatherControllerProvider =
    StateNotifierProvider.autoDispose<WeatherController, WeatherState>((ref) {
  /// Controller reads the repository and auto-fetches on construction.
  return WeatherController(ref.watch(weatherRepositoryProvider));
});
