/// Immutable state for the weather suggestion feature.
/// Managed by [WeatherController] and consumed by [WeatherPokemonScreen].
import 'package:pok_dex_field_assistant/features/pokemon_search/data/models/pokemon_models.dart';
import 'package:pok_dex_field_assistant/features/weather/data/models/weather_models.dart';

/// Sentinel object used by [WeatherState.copyWith] to distinguish
/// "caller did not pass error" from "caller explicitly passed null to clear it".
/// Using `Object()` as a default prevents the nullable [String?] parameter from
/// silently wiping the previous error on every [copyWith] call that omits it.
const _keep = _Sentinel();

/// Private sentinel type — not exported; used only for [_keep].
class _Sentinel {
  const _Sentinel();
}

/// Holds all UI-relevant state for the weather Pokémon suggestion flow.
/// All fields are immutable — use [copyWith] to produce updated copies.
class WeatherState {
  /// True while the weather or Pokémon list is being fetched.
  final bool isLoading;

  /// Non-null when the last fetch failed; contains a human-readable message.
  final String? error;

  /// Current weather snapshot — null until the first successful fetch.
  final WeatherData? weather;

  /// Currently visible Pokémon slice — grows as user loads more pages.
  final List<PokemonSummary> pokemon;

  /// True when more Pokémon remain in the full type list beyond [pokemon].
  final bool hasMore;

  /// True while the next page is being appended (shows bottom spinner).
  final bool isLoadingMore;

  /// Latitude used for the current (or pending) weather fetch.
  final double lat;

  /// Longitude used for the current (or pending) weather fetch.
  final double lon;

  /// Creates an immutable [WeatherState].
  const WeatherState({
    this.isLoading = false,
    this.error,
    this.weather,
    this.pokemon = const [],
    this.hasMore = false,
    this.isLoadingMore = false,
    required this.lat,
    required this.lon,
  });

  /// Returns a copy of this state with the given fields overridden.
  ///
  /// The [error] parameter uses a sentinel default ([_keep]) so that callers
  /// who do not pass [error] preserve the existing value.
  /// Pass `error: null` explicitly to clear a previous error.
  ///
  /// Example — preserve error while setting isLoadingMore:
  /// ```dart
  /// state = state.copyWith(isLoadingMore: true); // error unchanged
  /// ```
  /// Example — clear error on success:
  /// ```dart
  /// state = state.copyWith(error: null, pokemon: items);
  /// ```
  WeatherState copyWith({
    bool? isLoading,
    Object? error = _keep,  // sentinel: omitting preserves current value
    WeatherData? weather,
    List<PokemonSummary>? pokemon,
    bool? hasMore,
    bool? isLoadingMore,
    double? lat,
    double? lon,
  }) {
    return WeatherState(
      isLoading: isLoading ?? this.isLoading,
      /// Preserve current error when sentinel is passed; otherwise use new value.
      error: error == _keep ? this.error : error as String?,
      weather: weather ?? this.weather,
      pokemon: pokemon ?? this.pokemon,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      lat: lat ?? this.lat,
      lon: lon ?? this.lon,
    );
  }
}
