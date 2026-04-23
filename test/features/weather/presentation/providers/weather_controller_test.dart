/// Unit tests for [WeatherController].
/// Uses a hand-written fake [WeatherRepository] and [ProviderContainer] overrides
/// — no real network calls, no Flutter widgets needed.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/data/models/pokemon_models.dart';
import 'package:pok_dex_field_assistant/features/weather/data/models/weather_models.dart';
import 'package:pok_dex_field_assistant/features/weather/data/weather_repository.dart';
import 'package:pok_dex_field_assistant/features/weather/presentation/providers/weather_controller.dart';
import 'package:pok_dex_field_assistant/features/weather/presentation/providers/weather_providers.dart';
import 'package:pok_dex_field_assistant/features/weather/presentation/providers/weather_state.dart';

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

/// A [WeatherData] snapshot representing a clear, warm day → grass type.
final _warmClearWeather = WeatherData.fromJson({
  'current_weather': {
    'temperature': 25.0,
    'windspeed': 8.0,
    'weathercode': 0,
    'is_day': 1,
  },
});

/// Builds [count] dummy [PokemonSummary] items named `pokemon-0`, `pokemon-1`, …
List<PokemonSummary> _dummyPokemon(int count) => List.generate(
      count,
      (i) => PokemonSummary(
        id: i + 1,
        name: 'pokemon-$i',
        spriteUrl: 'https://example.com/$i.png',
      ),
    );

// ---------------------------------------------------------------------------
// Fake repository
// ---------------------------------------------------------------------------

/// Configurable fake — controls happy-path responses and whether to throw.
class _FakeWeatherRepository implements WeatherRepository {
  /// Returned by [getCurrentWeather] on success.
  final WeatherData weatherResult;

  /// Returned by [getPokemonByType] on success.
  final List<PokemonSummary> pokemonResult;

  /// When non-null, [getCurrentWeather] throws this instead of returning.
  final Exception? weatherError;

  /// When non-null, [getPokemonByType] throws this instead of returning.
  final Exception? pokemonError;

  /// Records the last type name passed to [getPokemonByType].
  String? lastRequestedType;

  /// Records every lat value passed to [getCurrentWeather].
  final List<double> latHistory = [];

  _FakeWeatherRepository({
    WeatherData? weatherResult,
    List<PokemonSummary>? pokemonResult,
    this.weatherError,
    this.pokemonError,
  })  : weatherResult = weatherResult ?? _warmClearWeather,
        pokemonResult = pokemonResult ?? _dummyPokemon(5);

  @override
  Future<WeatherData> getCurrentWeather({
    required double lat,
    required double lon,
  }) async {
    latHistory.add(lat);
    if (weatherError != null) throw weatherError!;
    return weatherResult;
  }

  @override
  Future<List<PokemonSummary>> getPokemonByType(String typeName) async {
    lastRequestedType = typeName;
    if (pokemonError != null) throw pokemonError!;
    return pokemonResult;
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Creates a [ProviderContainer] with [WeatherRepositoryImpl] overridden by [repo].
/// Returns the container — caller must call [container.dispose] when done.
ProviderContainer _makeContainer(_FakeWeatherRepository repo) {
  return ProviderContainer(
    overrides: [
      weatherRepositoryProvider.overrideWithValue(repo),
    ],
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // -------------------------------------------------------------------------
  // Initialisation
  // -------------------------------------------------------------------------

  group('WeatherController — init', () {
    test('starts in loading state', () {
      final repo = _FakeWeatherRepository();
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      /// Read state before the async fetch resolves.
      final state = container.read(weatherControllerProvider);

      expect(state.isLoading, isTrue);
      expect(state.weather, isNull);
      expect(state.pokemon, isEmpty);
    });

    test('lat and lon are set (random) on construction', () {
      final repo = _FakeWeatherRepository();
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      final state = container.read(weatherControllerProvider);

      /// Coordinates must be within valid inhabited ranges.
      expect(state.lat, inInclusiveRange(-60, 70));
      expect(state.lon, inInclusiveRange(-180, 180));
    });

    test('emits success state after fetch completes', () async {
      final repo = _FakeWeatherRepository(pokemonResult: _dummyPokemon(5));
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      /// Wait for both weather and pokemon fetches to finish.
      await container
          .read(weatherControllerProvider.notifier)
          .fetchWeatherSuggestions();

      final state = container.read(weatherControllerProvider);

      expect(state.isLoading, isFalse);
      expect(state.error, isNull);
      expect(state.weather, isNotNull);
      expect(state.pokemon, isNotEmpty);
    });

    test('calls repository with suggested type derived from weather', () async {
      final repo = _FakeWeatherRepository();
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      await container
          .read(weatherControllerProvider.notifier)
          .fetchWeatherSuggestions();

      /// _warmClearWeather at 25°C → grass type.
      expect(repo.lastRequestedType, 'grass');
    });
  });

  // -------------------------------------------------------------------------
  // Success state
  // -------------------------------------------------------------------------

  group('WeatherController — success state', () {
    test('shows first page (20 items) when total > 20', () async {
      final repo = _FakeWeatherRepository(pokemonResult: _dummyPokemon(25));
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      await container
          .read(weatherControllerProvider.notifier)
          .fetchWeatherSuggestions();

      expect(container.read(weatherControllerProvider).pokemon.length, 20);
    });

    test('hasMore is true when total > page size', () async {
      final repo = _FakeWeatherRepository(pokemonResult: _dummyPokemon(25));
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      await container
          .read(weatherControllerProvider.notifier)
          .fetchWeatherSuggestions();

      expect(container.read(weatherControllerProvider).hasMore, isTrue);
    });

    test('hasMore is false when total <= page size', () async {
      final repo = _FakeWeatherRepository(pokemonResult: _dummyPokemon(10));
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      await container
          .read(weatherControllerProvider.notifier)
          .fetchWeatherSuggestions();

      expect(container.read(weatherControllerProvider).hasMore, isFalse);
    });

    test('shows all items when total < page size', () async {
      final repo = _FakeWeatherRepository(pokemonResult: _dummyPokemon(7));
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      await container
          .read(weatherControllerProvider.notifier)
          .fetchWeatherSuggestions();

      expect(container.read(weatherControllerProvider).pokemon.length, 7);
    });
  });

  // -------------------------------------------------------------------------
  // Error states
  // -------------------------------------------------------------------------

  group('WeatherController — error states', () {
    test('emits error state when weather fetch fails', () async {
      final repo = _FakeWeatherRepository(
        weatherError: Exception('network down'),
      );
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      await container
          .read(weatherControllerProvider.notifier)
          .fetchWeatherSuggestions();

      final state = container.read(weatherControllerProvider);
      expect(state.isLoading, isFalse);
      expect(state.error, isNotNull);
      expect(state.pokemon, isEmpty);
    });

    test('emits error state when Pokémon fetch fails', () async {
      final repo = _FakeWeatherRepository(
        pokemonError: Exception('type endpoint down'),
      );
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      await container
          .read(weatherControllerProvider.notifier)
          .fetchWeatherSuggestions();

      final state = container.read(weatherControllerProvider);
      expect(state.isLoading, isFalse);
      expect(state.error, isNotNull);
    });

    test('error state preserves lat and lon', () async {
      final repo = _FakeWeatherRepository(
        weatherError: Exception('fail'),
      );
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      final controller =
          container.read(weatherControllerProvider.notifier);
      await controller.fetchWeatherSuggestions(lat: 10.0, lon: 20.0);

      final state = container.read(weatherControllerProvider);
      expect(state.lat, 10.0);
      expect(state.lon, 20.0);
    });
  });

  // -------------------------------------------------------------------------
  // Pagination — loadMore
  // -------------------------------------------------------------------------

  group('WeatherController — loadMore', () {
    test('appends next page on loadMore', () async {
      final repo = _FakeWeatherRepository(pokemonResult: _dummyPokemon(25));
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      final controller = container.read(weatherControllerProvider.notifier);
      await controller.fetchWeatherSuggestions();

      /// First page = 20 items. loadMore should append 5 more.
      controller.loadMore();

      expect(container.read(weatherControllerProvider).pokemon.length, 25);
    });

    test('hasMore becomes false after last page loaded', () async {
      final repo = _FakeWeatherRepository(pokemonResult: _dummyPokemon(25));
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      final controller = container.read(weatherControllerProvider.notifier);
      await controller.fetchWeatherSuggestions();
      controller.loadMore();

      expect(container.read(weatherControllerProvider).hasMore, isFalse);
    });

    test('loadMore is no-op when hasMore is false', () async {
      final repo = _FakeWeatherRepository(pokemonResult: _dummyPokemon(10));
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      final controller = container.read(weatherControllerProvider.notifier);
      await controller.fetchWeatherSuggestions();

      final countBefore =
          container.read(weatherControllerProvider).pokemon.length;
      controller.loadMore();

      expect(
          container.read(weatherControllerProvider).pokemon.length,
          countBefore);
    });

    test('multiple loadMore calls page through all items', () async {
      /// 55 items → first page 20, then 20, then 15.
      final repo = _FakeWeatherRepository(pokemonResult: _dummyPokemon(55));
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      final controller = container.read(weatherControllerProvider.notifier);
      await controller.fetchWeatherSuggestions();

      controller.loadMore(); // 40
      controller.loadMore(); // 55

      final state = container.read(weatherControllerProvider);
      expect(state.pokemon.length, 55);
      expect(state.hasMore, isFalse);
    });
  });

  // -------------------------------------------------------------------------
  // Coordinate handling
  // -------------------------------------------------------------------------

  group('WeatherController — coordinates', () {
    test('fetchWeatherSuggestions uses provided lat/lon', () async {
      final repo = _FakeWeatherRepository();
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      await container
          .read(weatherControllerProvider.notifier)
          .fetchWeatherSuggestions(lat: 36.8, lon: 10.1);

      final state = container.read(weatherControllerProvider);
      expect(state.lat, 36.8);
      expect(state.lon, 10.1);
    });

    test('fetchWeatherSuggestions passes provided coords to repository', () async {
      final repo = _FakeWeatherRepository();
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      await container
          .read(weatherControllerProvider.notifier)
          .fetchWeatherSuggestions(lat: 36.8, lon: 10.1);

      /// Repository should have been called with exactly these coordinates.
      expect(repo.latHistory.last, 36.8);
    });

    test('randomise: true generates different coords each call', () async {
      final repo = _FakeWeatherRepository();
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      final controller = container.read(weatherControllerProvider.notifier);
      await controller.fetchWeatherSuggestions(randomise: true);
      final lat1 = container.read(weatherControllerProvider).lat;

      await controller.fetchWeatherSuggestions(randomise: true);
      final lat2 = container.read(weatherControllerProvider).lat;

      /// Extremely unlikely to be equal across two independent Random calls.
      expect(lat1, isNot(equals(lat2)));
    });

    test('retry with no args reuses existing coords', () async {
      final repo = _FakeWeatherRepository();
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      final controller = container.read(weatherControllerProvider.notifier);
      await controller.fetchWeatherSuggestions(lat: 51.5, lon: -0.1);

      /// Retry — no lat/lon/randomise args.
      await controller.fetchWeatherSuggestions();

      final state = container.read(weatherControllerProvider);
      expect(state.lat, 51.5);
      expect(state.lon, -0.1);
    });
  });
}
