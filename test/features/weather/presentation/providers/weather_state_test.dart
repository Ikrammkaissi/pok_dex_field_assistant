import 'package:flutter_test/flutter_test.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/data/models/pokemon_models.dart';
import 'package:pok_dex_field_assistant/features/weather/presentation/providers/weather_state.dart';

void main() {
  group('WeatherState.copyWith sentinel behavior', () {
    test('preserves error when error is omitted', () {
      const state = WeatherState(
        lat: 10,
        lon: 20,
        error: 'fail',
      );

      final next = state.copyWith(isLoadingMore: true);

      expect(next.error, 'fail');
      expect(next.isLoadingMore, isTrue);
    });

    test('clears error when null is passed explicitly', () {
      const state = WeatherState(
        lat: 10,
        lon: 20,
        error: 'fail',
      );

      final next = state.copyWith(error: null);

      expect(next.error, isNull);
    });

    test('replaces error when a new message is passed', () {
      const state = WeatherState(
        lat: 10,
        lon: 20,
        error: 'old',
      );

      final next = state.copyWith(error: 'new');

      expect(next.error, 'new');
    });

    test('keeps other fields unchanged when not overridden', () {
      const pokemon = [
        PokemonSummary(id: 1, name: 'bulbasaur', spriteUrl: ''),
      ];
      const state = WeatherState(
        lat: 10,
        lon: 20,
        isLoading: true,
        hasMore: true,
        pokemon: pokemon,
      );

      final next = state.copyWith(error: null);

      expect(next.lat, 10);
      expect(next.lon, 20);
      expect(next.isLoading, isTrue);
      expect(next.hasMore, isTrue);
      expect(next.pokemon, pokemon);
    });
  });
}
