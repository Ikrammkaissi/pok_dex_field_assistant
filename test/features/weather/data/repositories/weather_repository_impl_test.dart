/// Unit tests for [WeatherRepositoryImpl].
/// Uses hand-written fake [http.BaseClient] subclasses , no external mocking.
/// Both HTTP clients (weather + PokeAPI) are injected with fakes so no real
/// network calls are made.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:pok_dex_field_assistant/core/error/exceptions.dart';
import 'package:pok_dex_field_assistant/core/network/http_client.dart';
import 'package:pok_dex_field_assistant/core/network/weather_http_client.dart';
import 'package:pok_dex_field_assistant/features/weather/data/repositories/weather_repository_impl.dart';
import 'package:pok_dex_field_assistant/features/weather/domain/repositories/weather_repository.dart';

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

/// Minimal open-meteo `/forecast` response.
const _weatherJson = <String, dynamic>{
  'current_weather': {
    'temperature': 22.0,
    'windspeed': 12.0,
    'weathercode': 0,
    'is_day': 1,
    'time': '2026-04-23T10:15',
    'interval': 900,
    'winddirection': 38,
  },
};

/// Minimal PokéAPI `/type/fire` response with two Pokémon entries.
const _fireTypeJson = <String, dynamic>{
  'name': 'fire',
  'id': 10,
  'pokemon': [
    {
      'pokemon': {
        'name': 'charmander',
        'url': 'https://pokeapi.co/api/v2/pokemon/4/',
      },
      'slot': 1,
    },
    {
      'pokemon': {
        'name': 'charmeleon',
        'url': 'https://pokeapi.co/api/v2/pokemon/5/',
      },
      'slot': 1,
    },
  ],
};

/// Type response with an empty pokemon array.
const _emptyTypeJson = <String, dynamic>{
  'name': 'stellar',
  'id': 19,
  'pokemon': <dynamic>[],
};

/// Type response containing one malformed pokemon URL id and one valid entry.
const _mixedTypeJson = <String, dynamic>{
  'name': 'fire',
  'id': 10,
  'pokemon': [
    {
      'pokemon': {
        'name': 'bad-entry',
        'url': 'https://pokeapi.co/api/v2/pokemon/not-a-number/',
      },
      'slot': 1,
    },
    {
      'pokemon': {
        'name': 'charmeleon',
        'url': 'https://pokeapi.co/api/v2/pokemon/5/',
      },
      'slot': 1,
    },
  ],
};

// ---------------------------------------------------------------------------
// Fake HTTP clients
// ---------------------------------------------------------------------------

/// Fake for the open-meteo [WeatherHttpClient] , returns a pre-baked response.
class _FakeWeatherClient extends http.BaseClient {
  /// Fixed JSON body returned for all requests.
  final Map<String, dynamic> body;

  /// HTTP status code to return , use non-2xx to simulate server errors.
  final int statusCode;

  /// Last URI received , lets tests assert on the URL that was called.
  Uri? lastUri;

  _FakeWeatherClient({required this.body, this.statusCode = 200});

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    lastUri = request.url;
    final bytes = utf8.encode(jsonEncode(body));
    return http.StreamedResponse(
      Stream.value(bytes),
      statusCode,
      headers: {'content-type': 'application/json'},
    );
  }
}

/// Fake that always throws [SocketException] to simulate no connectivity.
class _NetworkErrorClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    throw const SocketException('No network');
  }
}

/// Fake for the PokéAPI [PokeApiHttpClient] , returns a pre-baked type response.
class _FakePokeClient extends http.BaseClient {
  /// Fixed JSON body returned for all requests.
  final Map<String, dynamic> body;

  /// Last URI received , lets tests assert on the URL that was called.
  Uri? lastUri;

  _FakePokeClient(this.body);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    lastUri = request.url;
    final bytes = utf8.encode(jsonEncode(body));
    return http.StreamedResponse(
      Stream.value(bytes),
      200,
      headers: {'content-type': 'application/json'},
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Builds a [WeatherRepositoryImpl] with the given fake clients.
WeatherRepositoryImpl _makeRepo({
  required http.BaseClient weatherClient,
  required http.BaseClient pokeClient,
}) {
  return WeatherRepositoryImpl(
    WeatherHttpClient(weatherClient),
    PokeApiHttpClient(pokeClient),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // -------------------------------------------------------------------------
  // getCurrentWeather
  // -------------------------------------------------------------------------

  group('WeatherRepositoryImpl.getCurrentWeather', () {
    test('calls open-meteo with correct lat and lon in URL', () async {
      final fakeWeather = _FakeWeatherClient(body: _weatherJson);
      final repo = _makeRepo(
        weatherClient: fakeWeather,
        pokeClient: _FakePokeClient(_fireTypeJson),
      );

      await repo.getCurrentWeather(lat: 48.8566, lon: 2.3522);

      expect(fakeWeather.lastUri.toString(), contains('latitude=48.8566'));
      expect(fakeWeather.lastUri.toString(), contains('longitude=2.3522'));
    });

    test('includes current_weather=true query param', () async {
      final fakeWeather = _FakeWeatherClient(body: _weatherJson);
      final repo = _makeRepo(
        weatherClient: fakeWeather,
        pokeClient: _FakePokeClient(_fireTypeJson),
      );

      await repo.getCurrentWeather(lat: 0, lon: 0);

      expect(
          fakeWeather.lastUri.toString(), contains('current_weather=true'));
    });

    test('returns parsed WeatherData with correct fields', () async {
      final repo = _makeRepo(
        weatherClient: _FakeWeatherClient(body: _weatherJson),
        pokeClient: _FakePokeClient(_fireTypeJson),
      );

      final weather =
          await repo.getCurrentWeather(lat: 48.8566, lon: 2.3522);

      expect(weather.temperature, 22.0);
      expect(weather.windspeed, 12.0);
      expect(weather.weathercode, 0);
      expect(weather.isDay, isTrue);
    });

    test('throws NetworkException when HTTP client throws SocketException',
        () async {
      final repo = _makeRepo(
        weatherClient: _NetworkErrorClient(),
        pokeClient: _FakePokeClient(_fireTypeJson),
      );

      expect(
        () => repo.getCurrentWeather(lat: 0, lon: 0),
        throwsA(isA<NetworkException>()),
      );
    });

    test('throws ServerException on non-2xx response', () async {
      final repo = _makeRepo(
        weatherClient:
            _FakeWeatherClient(body: _weatherJson, statusCode: 500),
        pokeClient: _FakePokeClient(_fireTypeJson),
      );

      expect(
        () => repo.getCurrentWeather(lat: 0, lon: 0),
        throwsA(isA<ServerException>()),
      );
    });
  });

  // -------------------------------------------------------------------------
  // getPokemonByType
  // -------------------------------------------------------------------------

  group('WeatherRepositoryImpl.getPokemonByType', () {
    test('calls PokéAPI with correct type path', () async {
      final fakePoke = _FakePokeClient(_fireTypeJson);
      final repo = _makeRepo(
        weatherClient: _FakeWeatherClient(body: _weatherJson),
        pokeClient: fakePoke,
      );

      await repo.getPokemonByType('fire');

      expect(fakePoke.lastUri.toString(), contains('/type/fire'));
    });

    test('returns PokemonSummary list with correct names', () async {
      final repo = _makeRepo(
        weatherClient: _FakeWeatherClient(body: _weatherJson),
        pokeClient: _FakePokeClient(_fireTypeJson),
      );

      final pokemon = await repo.getPokemonByType('fire');

      expect(pokemon.length, 2);
      expect(pokemon.map((p) => p.name), containsAll(['charmander', 'charmeleon']));
    });

    test('extracts correct ID from PokéAPI URL', () async {
      final repo = _makeRepo(
        weatherClient: _FakeWeatherClient(body: _weatherJson),
        pokeClient: _FakePokeClient(_fireTypeJson),
      );

      final pokemon = await repo.getPokemonByType('fire');

      expect(pokemon[0].id, 4); // charmander URL ends with /4/
      expect(pokemon[1].id, 5); // charmeleon URL ends with /5/
    });

    test('builds sprite URL from extracted ID', () async {
      final repo = _makeRepo(
        weatherClient: _FakeWeatherClient(body: _weatherJson),
        pokeClient: _FakePokeClient(_fireTypeJson),
      );

      final pokemon = await repo.getPokemonByType('fire');

      expect(
        pokemon[0].spriteUrl,
        'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/4.png',
      );
    });

    test('sets primaryType from requested type', () async {
      final repo = _makeRepo(
        weatherClient: _FakeWeatherClient(body: _weatherJson),
        pokeClient: _FakePokeClient(_fireTypeJson),
      );

      final pokemon = await repo.getPokemonByType('fire');

      expect(pokemon[0].primaryType, 'fire');
      expect(pokemon[1].primaryType, 'fire');
    });

    test('returns empty list when type has no Pokémon', () async {
      final repo = _makeRepo(
        weatherClient: _FakeWeatherClient(body: _weatherJson),
        pokeClient: _FakePokeClient(_emptyTypeJson),
      );

      final pokemon = await repo.getPokemonByType('stellar');

      expect(pokemon, isEmpty);
    });

    test('skips entries with non-numeric pokemon IDs', () async {
      final repo = _makeRepo(
        weatherClient: _FakeWeatherClient(body: _weatherJson),
        pokeClient: _FakePokeClient(_mixedTypeJson),
      );

      final pokemon = await repo.getPokemonByType('fire');

      expect(pokemon.length, 1);
      expect(pokemon.first.name, 'charmeleon');
      expect(pokemon.first.id, 5);
    });

    test('throws NetworkException on connectivity failure', () async {
      final repo = _makeRepo(
        weatherClient: _FakeWeatherClient(body: _weatherJson),
        pokeClient: _NetworkErrorClient(),
      );

      expect(
        () => repo.getPokemonByType('fire'),
        throwsA(isA<NetworkException>()),
      );
    });
  });
}
