/// Unit tests for [WeatherData].
/// Pure logic , no network, no Riverpod, no Flutter widgets.
import 'package:flutter_test/flutter_test.dart';
import 'package:pok_dex_field_assistant/core/error/exceptions.dart';
import 'package:pok_dex_field_assistant/features/weather/data/models/weather_models.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Builds a minimal open-meteo `/forecast` JSON map with overridable fields.
Map<String, dynamic> _weatherJson({
  double temperature = 20.0,
  double windspeed = 10.0,
  int weathercode = 0,
  int isDay = 1,
}) =>
    {
      'current_weather': {
        'temperature': temperature,
        'windspeed': windspeed,
        'weathercode': weathercode,
        'is_day': isDay,
        'time': '2026-04-23T10:15',
        'interval': 900,
        'winddirection': 0,
      },
    };

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // -------------------------------------------------------------------------
  // fromJson
  // -------------------------------------------------------------------------

  group('WeatherData.fromJson', () {
    test('parses temperature as double', () {
      final data = WeatherData.fromJson(_weatherJson(temperature: 22.5));
      expect(data.temperature, 22.5);
    });

    test('parses windspeed as double', () {
      final data = WeatherData.fromJson(_weatherJson(windspeed: 18.3));
      expect(data.windspeed, 18.3);
    });

    test('parses weathercode as int', () {
      final data = WeatherData.fromJson(_weatherJson(weathercode: 95));
      expect(data.weathercode, 95);
    });

    test('isDay is true when is_day is 1', () {
      final data = WeatherData.fromJson(_weatherJson(isDay: 1));
      expect(data.isDay, isTrue);
    });

    test('isDay is false when is_day is 0', () {
      final data = WeatherData.fromJson(_weatherJson(isDay: 0));
      expect(data.isDay, isFalse);
    });

    test('accepts integer temperature (num cast)', () {
      /// open-meteo can return temperature as int (e.g. 20 not 20.0).
      final data = WeatherData.fromJson({
        'current_weather': {
          'temperature': 20,
          'windspeed': 10,
          'weathercode': 0,
          'is_day': 1,
        },
      });
      expect(data.temperature, 20.0);
    });

    test('throws ParseException when current_weather key is missing', () {
      expect(
        () => WeatherData.fromJson({}),
        throwsA(isA<ParseException>()),
      );
    });

    test('throws ParseException when current_weather is not a map', () {
      expect(
        () => WeatherData.fromJson({'current_weather': 'bad'}),
        throwsA(isA<ParseException>()),
      );
    });

    test('throws ParseException when temperature is missing', () {
      expect(
        () => WeatherData.fromJson({
          'current_weather': {
            'windspeed': 10,
            'weathercode': 0,
            'is_day': 1,
          },
        }),
        throwsA(isA<ParseException>()),
      );
    });
  });

  // -------------------------------------------------------------------------
  // conditionLabel
  // -------------------------------------------------------------------------

  group('WeatherData.conditionLabel', () {
    test('thunderstorm for weathercode 95', () {
      expect(
        WeatherData.fromJson(_weatherJson(weathercode: 95)).conditionLabel,
        'Thunderstorm',
      );
    });

    test('thunderstorm for weathercode 99 (upper bound)', () {
      expect(
        WeatherData.fromJson(_weatherJson(weathercode: 99)).conditionLabel,
        'Thunderstorm',
      );
    });

    test('snow for weathercode 71 (lower bound)', () {
      expect(
        WeatherData.fromJson(_weatherJson(weathercode: 71)).conditionLabel,
        'Snow',
      );
    });

    test('snow for weathercode 77 (upper bound)', () {
      expect(
        WeatherData.fromJson(_weatherJson(weathercode: 77)).conditionLabel,
        'Snow',
      );
    });

    test('rain for drizzle code 51 (lower bound)', () {
      expect(
        WeatherData.fromJson(_weatherJson(weathercode: 51)).conditionLabel,
        'Rain',
      );
    });

    test('rain for drizzle code 67 (upper bound)', () {
      expect(
        WeatherData.fromJson(_weatherJson(weathercode: 67)).conditionLabel,
        'Rain',
      );
    });

    test('rain for shower code 80 (lower bound)', () {
      expect(
        WeatherData.fromJson(_weatherJson(weathercode: 80)).conditionLabel,
        'Rain',
      );
    });

    test('rain for shower code 82 (upper bound)', () {
      expect(
        WeatherData.fromJson(_weatherJson(weathercode: 82)).conditionLabel,
        'Rain',
      );
    });

    test('fog for weathercode 45 (lower bound)', () {
      expect(
        WeatherData.fromJson(_weatherJson(weathercode: 45)).conditionLabel,
        'Fog',
      );
    });

    test('fog for weathercode 49 (upper bound)', () {
      expect(
        WeatherData.fromJson(_weatherJson(weathercode: 49)).conditionLabel,
        'Fog',
      );
    });

    test('clear for weathercode 0', () {
      expect(
        WeatherData.fromJson(_weatherJson(weathercode: 0)).conditionLabel,
        'Clear',
      );
    });

    test('clear for weathercode 2 (upper bound)', () {
      expect(
        WeatherData.fromJson(_weatherJson(weathercode: 2)).conditionLabel,
        'Clear',
      );
    });

    test('cloudy for weathercode 3 (just above clear)', () {
      expect(
        WeatherData.fromJson(_weatherJson(weathercode: 3)).conditionLabel,
        'Cloudy',
      );
    });

    test('cloudy for weathercode 44 (gap before fog)', () {
      expect(
        WeatherData.fromJson(_weatherJson(weathercode: 44)).conditionLabel,
        'Cloudy',
      );
    });
  });

  // -------------------------------------------------------------------------
  // suggestedPokemonType
  // -------------------------------------------------------------------------

  group('WeatherData.suggestedPokemonType', () {
    test('electric for thunderstorm code 95', () {
      expect(
        WeatherData.fromJson(_weatherJson(weathercode: 95))
            .suggestedPokemonType,
        'electric',
      );
    });

    test('ice for snow code 71', () {
      expect(
        WeatherData.fromJson(_weatherJson(weathercode: 71))
            .suggestedPokemonType,
        'ice',
      );
    });

    test('water for drizzle code 55', () {
      expect(
        WeatherData.fromJson(_weatherJson(weathercode: 55))
            .suggestedPokemonType,
        'water',
      );
    });

    test('water for shower code 81', () {
      expect(
        WeatherData.fromJson(_weatherJson(weathercode: 81))
            .suggestedPokemonType,
        'water',
      );
    });

    test('ghost for fog code 45', () {
      expect(
        WeatherData.fromJson(_weatherJson(weathercode: 45))
            .suggestedPokemonType,
        'ghost',
      );
    });

    test('flying when windspeed > 30 and clear sky', () {
      final data = WeatherData.fromJson(
          _weatherJson(weathercode: 0, windspeed: 31.0, temperature: 20.0));
      expect(data.suggestedPokemonType, 'flying');
    });

    test('fire when temperature > 30 and calm wind', () {
      final data = WeatherData.fromJson(
          _weatherJson(weathercode: 0, windspeed: 5.0, temperature: 31.0));
      expect(data.suggestedPokemonType, 'fire');
    });

    test('grass when temperature > 20 and calm wind', () {
      final data = WeatherData.fromJson(
          _weatherJson(weathercode: 0, windspeed: 5.0, temperature: 25.0));
      expect(data.suggestedPokemonType, 'grass');
    });

    test('water when temperature > 10 and calm wind', () {
      final data = WeatherData.fromJson(
          _weatherJson(weathercode: 0, windspeed: 5.0, temperature: 15.0));
      expect(data.suggestedPokemonType, 'water');
    });

    test('ice when temperature exactly 10 (boundary, not > 10)', () {
      final data = WeatherData.fromJson(
          _weatherJson(weathercode: 0, windspeed: 5.0, temperature: 10.0));
      expect(data.suggestedPokemonType, 'ice');
    });

    test('ice when temperature below 10', () {
      final data = WeatherData.fromJson(
          _weatherJson(weathercode: 0, windspeed: 5.0, temperature: -5.0));
      expect(data.suggestedPokemonType, 'ice');
    });

    test('weathercode priority beats temperature , rain code with hot temp', () {
      /// Drizzle code 55 should yield water even though temperature is 35°C.
      final data = WeatherData.fromJson(
          _weatherJson(weathercode: 55, windspeed: 5.0, temperature: 35.0));
      expect(data.suggestedPokemonType, 'water');
    });

    test('weathercode priority beats wind , thunderstorm with high wind', () {
      /// Code 95 beats windspeed > 30.
      final data = WeatherData.fromJson(
          _weatherJson(weathercode: 95, windspeed: 40.0, temperature: 20.0));
      expect(data.suggestedPokemonType, 'electric');
    });

    test('wind priority beats temperature when sky is clear', () {
      /// No weathercode match → check wind before temp.
      final data = WeatherData.fromJson(
          _weatherJson(weathercode: 0, windspeed: 35.0, temperature: 32.0));
      expect(data.suggestedPokemonType, 'flying');
    });
  });

  // -------------------------------------------------------------------------
  // conditionIcon
  // -------------------------------------------------------------------------

  group('WeatherData.conditionIcon', () {
    test('sun emoji for clear day', () {
      final data = WeatherData.fromJson(_weatherJson(weathercode: 0, isDay: 1));
      expect(data.conditionIcon, '☀️');
    });

    test('moon emoji for clear night', () {
      final data = WeatherData.fromJson(_weatherJson(weathercode: 0, isDay: 0));
      expect(data.conditionIcon, '🌙');
    });

    test('thunderstorm emoji', () {
      final data = WeatherData.fromJson(_weatherJson(weathercode: 95));
      expect(data.conditionIcon, '⛈️');
    });

    test('snow emoji', () {
      final data = WeatherData.fromJson(_weatherJson(weathercode: 71));
      expect(data.conditionIcon, '❄️');
    });

    test('rain emoji', () {
      final data = WeatherData.fromJson(_weatherJson(weathercode: 55));
      expect(data.conditionIcon, '🌧️');
    });

    test('fog emoji', () {
      final data = WeatherData.fromJson(_weatherJson(weathercode: 45));
      expect(data.conditionIcon, '🌫️');
    });

    test('cloud emoji for cloudy', () {
      final data = WeatherData.fromJson(_weatherJson(weathercode: 3));
      expect(data.conditionIcon, '☁️');
    });
  });
}
