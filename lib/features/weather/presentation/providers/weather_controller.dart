/// State management for the weather Pokémon suggestion feature.
/// [WeatherController] fetches current weather then retrieves Pokémon of the
/// mapped type in a single sequential flow. UI calls [fetchWeatherSuggestions]
/// to trigger or retry; the controller handles all error states internally.
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pok_dex_field_assistant/core/error/exceptions.dart';
import 'package:pok_dex_field_assistant/core/logging/app_logger.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/data/models/pokemon_models.dart';
import 'package:pok_dex_field_assistant/features/weather/domain/usecases/get_current_weather.dart';
import 'package:pok_dex_field_assistant/features/weather/domain/usecases/get_pokemon_by_type.dart';
import 'package:pok_dex_field_assistant/features/weather/presentation/providers/weather_state.dart';

/// Orchestrates weather fetch → type mapping → Pokémon list fetch.
/// Extends [StateNotifier] so the screen rebuilds automatically on state changes.
class WeatherController extends StateNotifier<WeatherState> {
  /// Logger tag for this class.
  static const _tag = 'WeatherController';

  /// Number of Pokémon shown per page in the list.
  static const _pageSize = 20;

  /// Full Pokémon list for the current type , sliced into pages for display.
  List<PokemonSummary> _allPokemon = [];

  /// Number of items from [_allPokemon] currently visible in [state.pokemon].
  int _visibleCount = 0;

  /// Use case that fetches live weather from Open-Meteo for given coordinates.
  final GetCurrentWeather _getCurrentWeather;

  /// Use case that fetches all Pokémon of a specific type from PokéAPI.
  final GetPokemonByType _getPokemonByType;

  /// Generates a random latitude within the inhabited range [−60°, 70°].
  static double _randomLat() => (math.Random().nextDouble() * 130) - 60;

  /// Generates a random longitude within the full valid range [−180°, 180°].
  static double _randomLon() => (math.Random().nextDouble() * 360) - 180;

  /// Creates [WeatherController] with randomised coordinates and immediately
  /// triggers the first weather fetch so the screen shows data as soon as it opens.
  WeatherController(this._getCurrentWeather, this._getPokemonByType)
      : super(WeatherState(lat: _randomLat(), lon: _randomLon())) {
    AppLogger.debug(_tag,
        'init , randomised coords lat=${state.lat.toStringAsFixed(4)}, lon=${state.lon.toStringAsFixed(4)}');
    fetchWeatherSuggestions();
  }

  /// Fetches current weather then retrieves Pokémon matching the suggested type.
  ///
  /// [lat] and [lon] set specific coordinates (e.g. from the text fields).
  /// [rawLat] and [rawLon] allow controller-owned parsing/validation for UI input.
  /// [randomise] generates fresh random coordinates, ignoring [lat]/[lon].
  /// When all are omitted, existing [state] coordinates are reused (retry).
  ///
  /// Flow:
  /// 1. Set loading state, preserving the active coordinates.
  /// 2. Call [GetCurrentWeather] use case with the resolved coordinates.
  /// 3. Derive the suggested Pokémon type from [WeatherData.suggestedPokemonType].
  /// 4. Call [GetPokemonByType] use case with the derived type name.
  /// 5. Emit success state or error state on failure.
  Future<void> fetchWeatherSuggestions({
    double? lat,
    double? lon,
    String? rawLat,
    String? rawLon,
    bool randomise = false,
  }) async {
    final hasRawCoordinates = rawLat != null || rawLon != null;
    if (!randomise && hasRawCoordinates) {
      final parsedLat = double.tryParse((rawLat ?? '').trim());
      final parsedLon = double.tryParse((rawLon ?? '').trim());

      if (parsedLat == null || parsedLon == null) {
        AppLogger.warning(_tag,
            'fetchWeatherSuggestions , invalid input: rawLat="$rawLat" rawLon="$rawLon"');
        state = state.copyWith(error: 'Enter valid numbers for lat and lon.');
        return;
      }
      if (parsedLat < -90 || parsedLat > 90) {
        AppLogger.warning(_tag,
            'fetchWeatherSuggestions , lat out of range: $parsedLat');
        state = state.copyWith(error: 'Latitude must be between -90 and 90.');
        return;
      }
      if (parsedLon < -180 || parsedLon > 180) {
        AppLogger.warning(_tag,
            'fetchWeatherSuggestions , lon out of range: $parsedLon');
        state = state.copyWith(error: 'Longitude must be between -180 and 180.');
        return;
      }

      lat = parsedLat;
      lon = parsedLon;
    }

    /// Randomise flag wins , generate fresh coords regardless of other args.
    final useLat = randomise ? _randomLat() : (lat ?? state.lat);
    final useLon = randomise ? _randomLon() : (lon ?? state.lon);

    AppLogger.debug(_tag,
        'fetchWeatherSuggestions , lat=${useLat.toStringAsFixed(4)}, lon=${useLon.toStringAsFixed(4)}, randomise=$randomise');

    /// Reset to loading , clears error and pokemon list, preserves coordinates.
    state = WeatherState(isLoading: true, lat: useLat, lon: useLon);

    try {
      final weather = await _getCurrentWeather(lat: useLat, lon: useLon);

      final type = weather.suggestedPokemonType;
      AppLogger.info(_tag,
          'weather fetched , condition="${weather.conditionLabel}", mapped type="$type"');

      _allPokemon = await _getPokemonByType(type);

      /// Show only the first page , user scrolls to load more.
      _visibleCount = math.min(_pageSize, _allPokemon.length);

      AppLogger.info(_tag,
          'fetchWeatherSuggestions complete , type="$type", total=${_allPokemon.length}, visible=$_visibleCount, hasMore=${_visibleCount < _allPokemon.length}');

      /// Emit success , first page visible, hasMore signals more pages exist.
      state = WeatherState(
        weather: weather,
        pokemon: _allPokemon.take(_visibleCount).toList(),
        hasMore: _visibleCount < _allPokemon.length,
        lat: useLat,
        lon: useLon,
      );
    } catch (e, s) {
      AppLogger.error(_tag,
          'fetchWeatherSuggestions failed , lat=${useLat.toStringAsFixed(4)}, lon=${useLon.toStringAsFixed(4)}',
          error: e, stackTrace: s);
      /// Emit error state , screen shows retry button with user-friendly message.
      state = WeatherState(error: _errorMessage(e), lat: useLat, lon: useLon);
    }
  }

  /// Translates typed exceptions into short user-facing strings.
  /// Mirrors [PokemonSearchController._errorMessage] so both features
  /// show consistent error copy rather than raw exception class names.
  String _errorMessage(Object e) {
    if (e is NetworkException) return 'No internet connection.';
    if (e is ServerException) return 'Server error (${e.statusCode}).';
    if (e is ParseException) return 'Data error , please try again.';
    return 'Something went wrong.';
  }

  /// Appends the next [_pageSize] items from [_allPokemon] into [state.pokemon].
  /// No-op when already loading or no more items remain.
  void loadMore() {
    if (state.isLoadingMore || !state.hasMore) return;

    AppLogger.debug(_tag,
        'loadMore , visible=$_visibleCount, total=${_allPokemon.length}');

    /// Signal that the bottom spinner should appear.
    state = state.copyWith(isLoadingMore: true);

    /// Advance the visible window by one page.
    _visibleCount = math.min(_visibleCount + _pageSize, _allPokemon.length);

    AppLogger.info(_tag,
        'loadMore complete , visible=$_visibleCount, hasMore=${_visibleCount < _allPokemon.length}');

    /// Emit new slice , synchronous since data is already in memory.
    state = state.copyWith(
      isLoadingMore: false,
      pokemon: _allPokemon.take(_visibleCount).toList(),
      hasMore: _visibleCount < _allPokemon.length,
    );
  }
}
