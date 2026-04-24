/// Domain contract for weather data and type-filtered Pokémon retrieval.
///
/// Lives in the domain layer so use cases and [WeatherController] depend on
/// this abstraction, not on the concrete Open-Meteo / PokéAPI implementation.
/// Swap [WeatherRepositoryImpl] for a fake in tests via Riverpod overrides.
///
/// Imports only domain entities — zero data-layer or framework dependencies.
import 'package:pok_dex_field_assistant/features/pokemon_search/domain/entities/pokemon_summary.dart';
import 'package:pok_dex_field_assistant/features/weather/domain/entities/weather_data.dart';

/// Interface that defines how weather and type-filtered Pokémon are fetched.
/// Concrete implementations (e.g. [WeatherRepositoryImpl]) live in the data layer.
abstract class WeatherRepository {
  /// Fetches current weather conditions for [lat] / [lon] coordinates.
  /// Returns a [WeatherData] with temperature, windspeed, weathercode, and
  /// the derived [WeatherData.suggestedPokemonType].
  Future<WeatherData> getCurrentWeather({
    required double lat,
    required double lon,
  });

  /// Returns all [PokemonSummary] items whose primary type is [typeName].
  /// Uses the PokéAPI `/type/{name}` endpoint — no extra detail calls needed.
  Future<List<PokemonSummary>> getPokemonByType(String typeName);
}
