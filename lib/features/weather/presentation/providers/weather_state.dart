/// Immutable state for the weather suggestion feature.
/// Managed by [WeatherController] and consumed by [WeatherPokemonScreen].
import 'package:pok_dex_field_assistant/features/pokemon_search/data/models/pokemon_models.dart';
import 'package:pok_dex_field_assistant/features/weather/data/models/weather_models.dart';

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
  /// Passing `error: null` explicitly clears a previous error.
  WeatherState copyWith({
    bool? isLoading,
    String? error,
    WeatherData? weather,
    List<PokemonSummary>? pokemon,
    bool? hasMore,
    bool? isLoadingMore,
    double? lat,
    double? lon,
  }) {
    return WeatherState(
      isLoading: isLoading ?? this.isLoading,
      /// `error` is intentionally not defaulted — caller must pass null to clear it.
      error: error,
      weather: weather ?? this.weather,
      pokemon: pokemon ?? this.pokemon,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      lat: lat ?? this.lat,
      lon: lon ?? this.lon,
    );
  }
}
