/// Domain entity for a current weather snapshot.
///
/// Pure Dart — no JSON parsing, no framework imports.
/// JSON ↔ entity conversion lives in [WeatherDataMapper] (data layer).
/// Business rules (type mapping, condition labels) belong here because they
/// express domain logic, not infrastructure concerns.

/// Snapshot of current weather conditions used to suggest a Pokémon type.
class WeatherData {
  /// Current air temperature in degrees Celsius.
  final double temperature;

  /// Current wind speed in km/h.
  final double windspeed;

  /// WMO weather interpretation code (see open-meteo docs).
  final int weathercode;

  /// True when the query time falls within daylight hours.
  final bool isDay;

  /// Creates an immutable [WeatherData].
  const WeatherData({
    required this.temperature,
    required this.windspeed,
    required this.weathercode,
    required this.isDay,
  });

  /// Human-readable label for the current condition based on WMO weathercode.
  /// Priority: thunderstorm > snow > rain > fog > clear > cloudy.
  String get conditionLabel {
    /// WMO 95+: thunderstorm with or without hail.
    if (weathercode >= 95) return 'Thunderstorm';

    /// WMO 71-77: snowfall of varying intensity.
    if (weathercode >= 71 && weathercode <= 77) return 'Snow';

    /// WMO 51-67: drizzle and rain; 80-82: rain showers.
    if ((weathercode >= 51 && weathercode <= 67) ||
        (weathercode >= 80 && weathercode <= 82)) return 'Rain';

    /// WMO 45-49: foggy conditions.
    if (weathercode >= 45 && weathercode <= 49) return 'Fog';

    /// WMO 0-2: clear sky or mainly clear.
    if (weathercode <= 2) return 'Clear';

    /// WMO 3-44: partly to overcast cloudy.
    return 'Cloudy';
  }

  /// Maps current weather to a PokéAPI type name for Pokémon suggestions.
  ///
  /// Priority order (most specific first):
  /// 1. Thunderstorm → electric
  /// 2. Snow        → ice
  /// 3. Rain        → water
  /// 4. Fog         → ghost
  /// 5. Windy       → flying
  /// 6. Hot >30°C   → fire
  /// 7. Warm >20°C  → grass
  /// 8. Cool >10°C  → water
  /// 9. Cold ≤10°C  → ice
  String get suggestedPokemonType {
    /// Thunderstorm, electric type thrives in storms.
    if (weathercode >= 95) return 'electric';

    /// Snowfall, ice type matches cold snowy weather.
    if (weathercode >= 71 && weathercode <= 77) return 'ice';

    /// Rain or drizzle, water type fits rainy conditions.
    if ((weathercode >= 51 && weathercode <= 67) ||
        (weathercode >= 80 && weathercode <= 82)) return 'water';

    /// Fog, ghost type evokes misty, eerie atmosphere.
    if (weathercode >= 45 && weathercode <= 49) return 'ghost';

    /// Strong wind, flying type suits breezy conditions.
    if (windspeed > 30) return 'flying';

    /// Very hot temperature, fire type loves the heat.
    if (temperature > 30) return 'fire';

    /// Warm temperature, grass type thrives in mild warmth.
    if (temperature > 20) return 'grass';

    /// Cool temperature, water type prefers cooler climates.
    if (temperature > 10) return 'water';

    /// Cold temperature, ice type for near-freezing conditions.
    return 'ice';
  }

  /// Emoji icon used on the weather card to represent current conditions visually.
  String get conditionIcon {
    switch (conditionLabel) {
      case 'Thunderstorm':
        return '⛈️';
      case 'Snow':
        return '❄️';
      case 'Rain':
        return '🌧️';
      case 'Fog':
        return '🌫️';
      case 'Clear':
        return isDay ? '☀️' : '🌙';
      default:
        return '☁️';
    }
  }
}
