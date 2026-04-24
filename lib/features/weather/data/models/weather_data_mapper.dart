/// Data-layer mapper: JSON → [WeatherData] domain entity.
///
/// All JSON parsing lives here so the domain entity stays pure Dart.
/// Used by [WeatherRepositoryImpl] when deserialising open-meteo `/forecast` responses.
import 'package:pok_dex_field_assistant/core/error/exceptions.dart';
import 'package:pok_dex_field_assistant/features/weather/domain/entities/weather_data.dart';

/// Converts raw open-meteo JSON into a [WeatherData] domain entity.
/// Static-only class — no instances needed.
class WeatherDataMapper {
  WeatherDataMapper._();

  /// Parses a [WeatherData] from an open-meteo `/forecast` JSON response.
  /// Reads the nested `current_weather` object.
  /// Throws [ParseException] if required fields are missing or have the wrong type.
  static WeatherData fromJson(Map<String, dynamic> json) {
    try {
      /// open-meteo wraps current conditions under `current_weather`.
      final cw = json['current_weather'] as Map<String, dynamic>;

      return WeatherData(
        /// Temperature is a double (e.g. 20.0).
        temperature: (cw['temperature'] as num).toDouble(),

        /// Windspeed is a double in km/h.
        windspeed: (cw['windspeed'] as num).toDouble(),

        /// WMO code as an integer.
        weathercode: cw['weathercode'] as int,

        /// is_day is 1 for day, 0 for night.
        isDay: (cw['is_day'] as int) == 1,
      );
    } catch (e) {
      throw ParseException('Failed to parse WeatherData from JSON: $e');
    }
  }
}
