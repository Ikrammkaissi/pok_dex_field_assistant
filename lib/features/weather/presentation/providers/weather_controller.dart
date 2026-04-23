/// State management for the weather Pokémon suggestion feature.
/// [WeatherController] fetches current weather then retrieves Pokémon of the
/// mapped type in a single sequential flow. UI calls [fetchWeatherSuggestions]
/// to trigger or retry; the controller handles all error states internally.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pok_dex_field_assistant/features/weather/data/weather_repository.dart';
import 'package:pok_dex_field_assistant/features/weather/presentation/providers/weather_state.dart';

/// Orchestrates weather fetch → type mapping → Pokémon list fetch.
/// Extends [StateNotifier] so the screen rebuilds automatically on state changes.
class WeatherController extends StateNotifier<WeatherState> {
  /// Default latitude used when no device location is available.
  /// Using Paris (48.8566°N, 2.3522°E) as a sensible central-European default.
  /// Extend with the `geolocator` package to use real device GPS coordinates.
  static const _defaultLat = 48.8566;

  /// Default longitude paired with [_defaultLat].
  static const _defaultLon = 2.3522;

  /// Repository that supplies weather data and type-filtered Pokémon lists.
  final WeatherRepository _repository;

  /// Creates a [WeatherController] and immediately triggers the first fetch.
  WeatherController(this._repository) : super(const WeatherState()) {
    /// Auto-fetch on creation so the screen shows data as soon as it opens.
    fetchWeatherSuggestions();
  }

  /// Fetches current weather then retrieves Pokémon matching the suggested type.
  ///
  /// Flow:
  /// 1. Set loading state.
  /// 2. Call [WeatherRepository.getCurrentWeather] with default coordinates.
  /// 3. Derive suggested Pokémon type from [WeatherData.suggestedPokemonType].
  /// 4. Call [WeatherRepository.getPokemonByType] with the derived type.
  /// 5. Emit success state or error state on failure.
  Future<void> fetchWeatherSuggestions() async {
    /// Reset to loading — clears any previous error and pokemon list.
    state = const WeatherState(isLoading: true);

    try {
      /// Step 1: get current weather for the default coordinates.
      final weather = await _repository.getCurrentWeather(
        lat: _defaultLat,
        lon: _defaultLon,
      );

      /// Step 2: derive the Pokémon type from the weather conditions.
      final type = weather.suggestedPokemonType;

      /// Step 3: fetch up to 20 Pokémon of the derived type.
      final pokemon = await _repository.getPokemonByType(type);

      /// Emit success — both weather and pokemon list are populated.
      state = WeatherState(weather: weather, pokemon: pokemon);
    } catch (e) {
      /// Emit error state — screen shows retry button with the error message.
      state = WeatherState(error: e.toString());
    }
  }
}
