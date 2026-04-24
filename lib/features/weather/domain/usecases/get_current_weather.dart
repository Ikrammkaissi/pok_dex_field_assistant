/// Use case: fetch current weather for a set of coordinates.
///
/// Single-responsibility class that wraps [WeatherRepository.getCurrentWeather].
/// [WeatherController] calls this instead of the repository directly, keeping
/// the presentation layer decoupled from the Open-Meteo implementation.
import 'package:pok_dex_field_assistant/features/weather/domain/entities/weather_data.dart';
import 'package:pok_dex_field_assistant/features/weather/domain/repositories/weather_repository.dart';

/// Encapsulates the "fetch current weather" operation.
/// Injected via [getCurrentWeatherProvider] so tests can supply a fake
/// without touching the provider graph.
class GetCurrentWeather {
  /// Repository that calls the Open-Meteo API.
  final WeatherRepository _repository;

  /// Creates [GetCurrentWeather] backed by [repository].
  GetCurrentWeather(this._repository);

  /// Fetches live weather for the position at [lat] / [lon].
  /// Returns a [WeatherData] that includes [WeatherData.suggestedPokemonType]
  /// derived from temperature, windspeed, and weathercode.
  Future<WeatherData> call({required double lat, required double lon}) =>
      _repository.getCurrentWeather(lat: lat, lon: lon);
}
