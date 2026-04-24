/// Widget tests for [WeatherPokemonScreen].
/// Uses a hand-written fake [WeatherRepository] and [ProviderScope] overrides.
/// SharedPreferences is mocked because [PokemonListTile] (reused in the list)
/// watches [isBookmarkedProvider] which depends on [sharedPreferencesProvider].
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pok_dex_field_assistant/features/bookmarks/presentation/providers/bookmark_providers.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/data/models/pokemon_models.dart';
import 'package:pok_dex_field_assistant/features/weather/data/models/weather_models.dart';
import 'package:pok_dex_field_assistant/features/weather/domain/repositories/weather_repository.dart';
import 'package:pok_dex_field_assistant/features/weather/presentation/providers/weather_providers.dart';
import 'package:pok_dex_field_assistant/features/weather/presentation/screens/weather_pokemon_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

/// Clear-sky warm weather fixture → grass type suggestion.
final _testWeather = WeatherData.fromJson({
  'current_weather': {
    'temperature': 25.0,
    'windspeed': 8.0,
    'weathercode': 0,
    'is_day': 1,
  },
});

/// Builds [count] dummy [PokemonSummary] items.
List<PokemonSummary> _dummyPokemon(int count) => List.generate(
      count,
      (i) => PokemonSummary(id: i + 1, name: 'poke-$i', spriteUrl: ''),
    );

// ---------------------------------------------------------------------------
// Fake repository
// ---------------------------------------------------------------------------

/// Configurable fake [WeatherRepository].
/// Pass [pauseWeather] to stall the weather fetch (simulates in-flight loading).
class _FakeWeatherRepository implements WeatherRepository {
  /// Returned by [getCurrentWeather] on success.
  final WeatherData weatherResult;

  /// Returned by [getPokemonByType] on success.
  final List<PokemonSummary> pokemonResult;

  /// When non-null, [getCurrentWeather] throws this instead of returning.
  final Exception? weatherError;

  /// When set, [getCurrentWeather] suspends until this completer resolves.
  final Completer<WeatherData>? pauseWeather;

  _FakeWeatherRepository({
    WeatherData? weatherResult,
    List<PokemonSummary>? pokemonResult,
    this.weatherError,
    this.pauseWeather,
  })  : weatherResult = weatherResult ?? _testWeather,
        pokemonResult = pokemonResult ?? _dummyPokemon(3);

  @override
  Future<WeatherData> getCurrentWeather({
    required double lat,
    required double lon,
  }) async {
    if (pauseWeather != null) return pauseWeather!.future;
    if (weatherError != null) throw weatherError!;
    return weatherResult;
  }

  @override
  Future<List<PokemonSummary>> getPokemonByType(String typeName) async =>
      pokemonResult;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Wraps [screen] in [ProviderScope] + [MaterialApp] with all required overrides.
/// [sharedPreferencesProvider] override is always included because
/// [PokemonListTile] → [isBookmarkedProvider] → [bookmarkNotifierProvider].
Widget _wrap(
  Widget screen,
  WeatherRepository repo,
  SharedPreferences prefs,
) {
  return ProviderScope(
    overrides: [
      weatherRepositoryProvider.overrideWithValue(repo),
      sharedPreferencesProvider.overrideWithValue(prefs),
    ],
    child: MaterialApp(home: screen),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  // -------------------------------------------------------------------------
  // Loading state
  // -------------------------------------------------------------------------

  group('WeatherPokemonScreen , loading state', () {
    testWidgets('loading indicator visible while fetch in flight',
        (tester) async {
      final repo = _FakeWeatherRepository(
        pauseWeather: Completer<WeatherData>(),
      );

      await tester.pumpWidget(_wrap(const WeatherPokemonScreen(), repo, prefs));
      await tester.pump(); // allow controller init, fetch starts but not done

      expect(find.byKey(WeatherScreenKeys.loadingIndicator), findsOneWidget);
    });

    testWidgets('Go button disabled while loading', (tester) async {
      final repo = _FakeWeatherRepository(
        pauseWeather: Completer<WeatherData>(),
      );

      await tester.pumpWidget(_wrap(const WeatherPokemonScreen(), repo, prefs));
      await tester.pump();

      final button = tester.widget<FilledButton>(
        find.byKey(WeatherScreenKeys.goButton),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('shuffle button disabled while loading', (tester) async {
      final repo = _FakeWeatherRepository(
        pauseWeather: Completer<WeatherData>(),
      );

      await tester.pumpWidget(_wrap(const WeatherPokemonScreen(), repo, prefs));
      await tester.pump();

      final button = tester.widget<IconButton>(
        find.byKey(WeatherScreenKeys.shuffleButton),
      );
      expect(button.onPressed, isNull);
    });
  });

  // -------------------------------------------------------------------------
  // Success state
  // -------------------------------------------------------------------------

  group('WeatherPokemonScreen , success state', () {
    testWidgets('loading indicator gone after fetch completes', (tester) async {
      final repo = _FakeWeatherRepository();

      await tester.pumpWidget(_wrap(const WeatherPokemonScreen(), repo, prefs));
      await tester.pumpAndSettle();

      expect(find.byKey(WeatherScreenKeys.loadingIndicator), findsNothing);
    });

    testWidgets('weather card visible after fetch completes', (tester) async {
      final repo = _FakeWeatherRepository();

      await tester.pumpWidget(_wrap(const WeatherPokemonScreen(), repo, prefs));
      await tester.pumpAndSettle();

      expect(find.byKey(WeatherScreenKeys.weatherCard), findsOneWidget);
    });

    testWidgets('weather card shows temperature text', (tester) async {
      final repo = _FakeWeatherRepository();

      await tester.pumpWidget(_wrap(const WeatherPokemonScreen(), repo, prefs));
      await tester.pumpAndSettle();

      /// _testWeather has 25.0°C , expect truncated display somewhere in card.
      expect(find.textContaining('25.0'), findsWidgets);
    });

    testWidgets('weather card shows suggested type chip', (tester) async {
      final repo = _FakeWeatherRepository();

      await tester.pumpWidget(_wrap(const WeatherPokemonScreen(), repo, prefs));
      await tester.pumpAndSettle();

      /// _testWeather (25°C, clear) → grass type. Chip capitalises first letter.
      expect(find.text('Grass'), findsOneWidget);
    });

    testWidgets('pokemon list visible after fetch completes', (tester) async {
      final repo = _FakeWeatherRepository(pokemonResult: _dummyPokemon(3));

      await tester.pumpWidget(_wrap(const WeatherPokemonScreen(), repo, prefs));
      await tester.pumpAndSettle();

      expect(find.byKey(WeatherScreenKeys.pokemonList), findsOneWidget);
    });

    testWidgets('pokemon names rendered in list', (tester) async {
      final repo = _FakeWeatherRepository(pokemonResult: _dummyPokemon(2));

      await tester.pumpWidget(_wrap(const WeatherPokemonScreen(), repo, prefs));
      await tester.pumpAndSettle();

      /// _dummyPokemon generates names like 'poke-0', 'poke-1'.
      /// PokemonListTile capitalises and replaces hyphens with spaces.
      expect(find.text('Poke 0'), findsOneWidget);
      expect(find.text('Poke 1'), findsOneWidget);
    });

    testWidgets('error view not shown in success state', (tester) async {
      final repo = _FakeWeatherRepository();

      await tester.pumpWidget(_wrap(const WeatherPokemonScreen(), repo, prefs));
      await tester.pumpAndSettle();

      expect(find.byKey(WeatherScreenKeys.errorView), findsNothing);
    });

    testWidgets('Go button enabled after fetch completes', (tester) async {
      final repo = _FakeWeatherRepository();

      await tester.pumpWidget(_wrap(const WeatherPokemonScreen(), repo, prefs));
      await tester.pumpAndSettle();

      final button = tester.widget<FilledButton>(
        find.byKey(WeatherScreenKeys.goButton),
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets('shuffle button enabled after fetch completes', (tester) async {
      final repo = _FakeWeatherRepository();

      await tester.pumpWidget(_wrap(const WeatherPokemonScreen(), repo, prefs));
      await tester.pumpAndSettle();

      final button = tester.widget<IconButton>(
        find.byKey(WeatherScreenKeys.shuffleButton),
      );
      expect(button.onPressed, isNotNull);
    });
  });

  // -------------------------------------------------------------------------
  // Error state
  // -------------------------------------------------------------------------

  group('WeatherPokemonScreen , error state', () {
    testWidgets('error view visible when fetch fails', (tester) async {
      final repo = _FakeWeatherRepository(
        weatherError: Exception('network down'),
      );

      await tester.pumpWidget(_wrap(const WeatherPokemonScreen(), repo, prefs));
      await tester.pumpAndSettle();

      expect(find.byKey(WeatherScreenKeys.errorView), findsOneWidget);
    });

    testWidgets('retry button present in error state', (tester) async {
      final repo = _FakeWeatherRepository(
        weatherError: Exception('network down'),
      );

      await tester.pumpWidget(_wrap(const WeatherPokemonScreen(), repo, prefs));
      await tester.pumpAndSettle();

      expect(find.byKey(WeatherScreenKeys.retryButton), findsOneWidget);
    });

    testWidgets('loading indicator not shown in error state', (tester) async {
      final repo = _FakeWeatherRepository(
        weatherError: Exception('network down'),
      );

      await tester.pumpWidget(_wrap(const WeatherPokemonScreen(), repo, prefs));
      await tester.pumpAndSettle();

      expect(find.byKey(WeatherScreenKeys.loadingIndicator), findsNothing);
    });

    testWidgets('pokemon list not shown in error state', (tester) async {
      final repo = _FakeWeatherRepository(
        weatherError: Exception('network down'),
      );

      await tester.pumpWidget(_wrap(const WeatherPokemonScreen(), repo, prefs));
      await tester.pumpAndSettle();

      expect(find.byKey(WeatherScreenKeys.pokemonList), findsNothing);
    });

    testWidgets('weather card not shown in error state', (tester) async {
      final repo = _FakeWeatherRepository(
        weatherError: Exception('network down'),
      );

      await tester.pumpWidget(_wrap(const WeatherPokemonScreen(), repo, prefs));
      await tester.pumpAndSettle();

      expect(find.byKey(WeatherScreenKeys.weatherCard), findsNothing);
    });

    testWidgets('tapping retry triggers a new fetch', (tester) async {
      /// First fetch fails; after tapping Retry the fake succeeds.
      int callCount = 0;
      final repo = _ToggleFakeRepository(onCall: () => ++callCount);

      await tester.pumpWidget(_wrap(const WeatherPokemonScreen(), repo, prefs));
      await tester.pumpAndSettle(); // first fetch (fails)

      expect(find.byKey(WeatherScreenKeys.retryButton), findsOneWidget);
      final countBeforeRetry = callCount;

      await tester.tap(find.byKey(WeatherScreenKeys.retryButton));
      await tester.pumpAndSettle();

      expect(callCount, greaterThan(countBeforeRetry));
    });
  });

  // -------------------------------------------------------------------------
  // Coordinate fields
  // -------------------------------------------------------------------------

  group('WeatherPokemonScreen , coordinate fields', () {
    testWidgets('lat field is visible', (tester) async {
      final repo = _FakeWeatherRepository();

      await tester.pumpWidget(_wrap(const WeatherPokemonScreen(), repo, prefs));
      await tester.pump();

      expect(find.byKey(WeatherScreenKeys.latField), findsOneWidget);
    });

    testWidgets('lon field is visible', (tester) async {
      final repo = _FakeWeatherRepository();

      await tester.pumpWidget(_wrap(const WeatherPokemonScreen(), repo, prefs));
      await tester.pump();

      expect(find.byKey(WeatherScreenKeys.lonField), findsOneWidget);
    });

    testWidgets('Go button is visible', (tester) async {
      final repo = _FakeWeatherRepository();

      await tester.pumpWidget(_wrap(const WeatherPokemonScreen(), repo, prefs));
      await tester.pump();

      expect(find.byKey(WeatherScreenKeys.goButton), findsOneWidget);
    });

    testWidgets('lat field pre-populated with generated coordinate',
        (tester) async {
      final repo = _FakeWeatherRepository();

      await tester.pumpWidget(_wrap(const WeatherPokemonScreen(), repo, prefs));
      await tester.pump();

      /// Field should contain a non-empty numeric string after controller init.
      final field = tester.widget<TextField>(
        find.byKey(WeatherScreenKeys.latField),
      );
      final text = field.controller?.text ?? '';
      expect(text, isNotEmpty);
      expect(double.tryParse(text), isNotNull);
    });

    testWidgets('invalid lat text shows controller error view', (tester) async {
      final repo = _FakeWeatherRepository();

      await tester.pumpWidget(_wrap(const WeatherPokemonScreen(), repo, prefs));
      await tester.pumpAndSettle();

      /// Type non-numeric text into the lat field.
      await tester.enterText(find.byKey(WeatherScreenKeys.latField), 'abc');
      await tester.tap(find.byKey(WeatherScreenKeys.goButton));
      await tester.pumpAndSettle();

      expect(find.byKey(WeatherScreenKeys.errorView), findsOneWidget);
      expect(find.text('Enter valid numbers for lat and lon.'), findsOneWidget);
    });

    testWidgets('out-of-range lat shows controller error view', (tester) async {
      final repo = _FakeWeatherRepository();

      await tester.pumpWidget(_wrap(const WeatherPokemonScreen(), repo, prefs));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(WeatherScreenKeys.latField), '999');
      await tester.tap(find.byKey(WeatherScreenKeys.goButton));
      await tester.pumpAndSettle();

      expect(find.byKey(WeatherScreenKeys.errorView), findsOneWidget);
      expect(find.text('Latitude must be between -90 and 90.'), findsOneWidget);
    });

    testWidgets('out-of-range lon shows controller error view', (tester) async {
      final repo = _FakeWeatherRepository();

      await tester.pumpWidget(_wrap(const WeatherPokemonScreen(), repo, prefs));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(WeatherScreenKeys.lonField), '999');
      await tester.tap(find.byKey(WeatherScreenKeys.goButton));
      await tester.pumpAndSettle();

      expect(find.byKey(WeatherScreenKeys.errorView), findsOneWidget);
      expect(find.text('Longitude must be between -180 and 180.'), findsOneWidget);
    });

    testWidgets('valid coords , Go button triggers fetch and shows results',
        (tester) async {
      final repo = _FakeWeatherRepository(pokemonResult: _dummyPokemon(2));

      await tester.pumpWidget(_wrap(const WeatherPokemonScreen(), repo, prefs));
      await tester.pumpAndSettle(); // initial fetch

      /// Enter new valid coordinates and tap Go.
      await tester.enterText(find.byKey(WeatherScreenKeys.latField), '48.8');
      await tester.enterText(find.byKey(WeatherScreenKeys.lonField), '2.35');
      await tester.tap(find.byKey(WeatherScreenKeys.goButton));
      await tester.pumpAndSettle();

      /// Results still visible , fetch succeeded with new coords.
      expect(find.byKey(WeatherScreenKeys.weatherCard), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // Shuffle button
  // -------------------------------------------------------------------------

  group('WeatherPokemonScreen , shuffle button', () {
    testWidgets('shuffle button present in AppBar', (tester) async {
      final repo = _FakeWeatherRepository();

      await tester.pumpWidget(_wrap(const WeatherPokemonScreen(), repo, prefs));
      await tester.pump();

      expect(find.byKey(WeatherScreenKeys.shuffleButton), findsOneWidget);
    });

    testWidgets('tapping shuffle triggers a new fetch', (tester) async {
      int weatherCallCount = 0;
      final repo = _CountingFakeRepository(onWeatherCall: () => ++weatherCallCount);

      await tester.pumpWidget(_wrap(const WeatherPokemonScreen(), repo, prefs));
      await tester.pumpAndSettle(); // initial fetch

      final countAfterInit = weatherCallCount;
      await tester.tap(find.byKey(WeatherScreenKeys.shuffleButton));
      await tester.pumpAndSettle();

      expect(weatherCallCount, greaterThan(countAfterInit));
    });
  });
}

// ---------------------------------------------------------------------------
// Additional fakes for retry / counting tests
// ---------------------------------------------------------------------------

/// Fake that fails the first weather call then succeeds on subsequent calls.
/// Used to test the Retry flow.
class _ToggleFakeRepository implements WeatherRepository {
  /// Called on every [getCurrentWeather] invocation.
  final void Function() onCall;
  int _callCount = 0;

  _ToggleFakeRepository({required this.onCall});

  @override
  Future<WeatherData> getCurrentWeather({
    required double lat,
    required double lon,
  }) async {
    onCall();
    _callCount++;
    if (_callCount == 1) throw Exception('first call fails');
    return _testWeather;
  }

  @override
  Future<List<PokemonSummary>> getPokemonByType(String typeName) async =>
      _dummyPokemon(2);
}

/// Fake that always succeeds and invokes [onWeatherCall] on every weather call.
class _CountingFakeRepository implements WeatherRepository {
  /// Called on every [getCurrentWeather] invocation.
  final void Function() onWeatherCall;

  _CountingFakeRepository({required this.onWeatherCall});

  @override
  Future<WeatherData> getCurrentWeather({
    required double lat,
    required double lon,
  }) async {
    onWeatherCall();
    return _testWeather;
  }

  @override
  Future<List<PokemonSummary>> getPokemonByType(String typeName) async =>
      _dummyPokemon(2);
}
