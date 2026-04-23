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

  /// Pokémon of the suggested type — empty until fetch completes.
  final List<PokemonSummary> pokemon;

  /// Creates an immutable [WeatherState].
  const WeatherState({
    this.isLoading = false,
    this.error,
    this.weather,
    this.pokemon = const [],
  });

  /// Returns a copy of this state with the given fields overridden.
  /// Passing `error: null` explicitly clears a previous error.
  WeatherState copyWith({
    bool? isLoading,
    String? error,
    WeatherData? weather,
    List<PokemonSummary>? pokemon,
  }) {
    return WeatherState(
      /// Override isLoading or keep current value.
      isLoading: isLoading ?? this.isLoading,

      /// `error` is intentionally not defaulted — caller must pass null to clear it.
      error: error,

      /// Override weather or keep current value.
      weather: weather ?? this.weather,

      /// Override pokemon list or keep current value.
      pokemon: pokemon ?? this.pokemon,
    );
  }
}
