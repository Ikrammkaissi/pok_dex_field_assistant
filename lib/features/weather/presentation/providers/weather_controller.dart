/// State management for the weather Pokémon suggestion feature.
/// [WeatherController] fetches current weather then retrieves Pokémon of the
/// mapped type in a single sequential flow. UI calls [fetchWeatherSuggestions]
/// to trigger or retry; the controller handles all error states internally.
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/data/models/pokemon_models.dart';
import 'package:pok_dex_field_assistant/features/weather/data/weather_repository.dart';
import 'package:pok_dex_field_assistant/features/weather/presentation/providers/weather_state.dart';

/// Orchestrates weather fetch → type mapping → Pokémon list fetch.
/// Extends [StateNotifier] so the screen rebuilds automatically on state changes.
class WeatherController extends StateNotifier<WeatherState> {
  /// Number of Pokémon shown per page in the list.
  static const _pageSize = 20;

  /// Full Pokémon list for the current type — sliced into pages for display.
  List<PokemonSummary> _allPokemon = [];

  /// Number of items from [_allPokemon] currently visible in [state.pokemon].
  int _visibleCount = 0;

  /// Repository that supplies weather data and type-filtered Pokémon lists.
  final WeatherRepository _repository;

  /// Generates a random latitude in the inhabited range [−60°, 70°].
  static double _randomLat() =>
      (math.Random().nextDouble() * 130) - 60;

  /// Generates a random longitude in the full range [−180°, 180°].
  static double _randomLon() =>
      (math.Random().nextDouble() * 360) - 180;

  /// Creates a [WeatherController] with randomised coordinates and immediately
  /// triggers the first fetch so the screen shows data as soon as it opens.
  WeatherController(this._repository)
      : super(WeatherState(lat: _randomLat(), lon: _randomLon())) {
    fetchWeatherSuggestions();
  }

  /// Fetches current weather then retrieves Pokémon matching the suggested type.
  ///
  /// [lat] and [lon] set specific coordinates (e.g. from the text fields).
  /// [randomise] generates fresh random coordinates, ignoring [lat]/[lon].
  /// When all are omitted, existing [state] coordinates are reused (retry).
  ///
  /// Flow:
  /// 1. Set loading state, preserving the active coordinates.
  /// 2. Call [WeatherRepository.getCurrentWeather] with the coordinates.
  /// 3. Derive suggested Pokémon type from [WeatherData.suggestedPokemonType].
  /// 4. Call [WeatherRepository.getPokemonByType] with the derived type.
  /// 5. Emit success state or error state on failure.
  Future<void> fetchWeatherSuggestions({
    double? lat,
    double? lon,
    bool randomise = false,
  }) async {
    /// Randomise flag wins — generate fresh coords regardless of other args.
    final useLat = randomise ? _randomLat() : (lat ?? state.lat);
    final useLon = randomise ? _randomLon() : (lon ?? state.lon);

    /// Reset to loading — clears error and pokemon list, preserves coordinates.
    state = WeatherState(isLoading: true, lat: useLat, lon: useLon);

    try {
      /// Step 1: get current weather for the active coordinates.
      final weather = await _repository.getCurrentWeather(
        lat: useLat,
        lon: useLon,
      );

      /// Step 2: derive the Pokémon type from the weather conditions.
      final type = weather.suggestedPokemonType;

      /// Step 3: fetch full Pokémon list for the derived type.
      _allPokemon = await _repository.getPokemonByType(type);

      /// Show only the first page — user scrolls to load more.
      _visibleCount = math.min(_pageSize, _allPokemon.length);

      /// Emit success — first page visible, hasMore signals more pages exist.
      state = WeatherState(
        weather: weather,
        pokemon: _allPokemon.take(_visibleCount).toList(),
        hasMore: _visibleCount < _allPokemon.length,
        lat: useLat,
        lon: useLon,
      );
    } catch (e) {
      /// Emit error state — screen shows retry button with the error message.
      state = WeatherState(error: e.toString(), lat: useLat, lon: useLon);
    }
  }

  /// Appends the next [_pageSize] items from [_allPokemon] into [state.pokemon].
  /// No-op when already loading or no more items remain.
  void loadMore() {
    if (state.isLoadingMore || !state.hasMore) return;

    /// Signal that the bottom spinner should appear.
    state = state.copyWith(isLoadingMore: true);

    /// Advance the visible window by one page.
    _visibleCount = math.min(_visibleCount + _pageSize, _allPokemon.length);

    /// Emit new slice — synchronous since data is already in memory.
    state = state.copyWith(
      isLoadingMore: false,
      pokemon: _allPokemon.take(_visibleCount).toList(),
      hasMore: _visibleCount < _allPokemon.length,
    );
  }
}
