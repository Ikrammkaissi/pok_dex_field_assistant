/// Abstract contract and concrete implementation for weather-based Pokémon suggestions.
/// [WeatherRepository] is the interface callers depend on — swap impl in tests.
/// [WeatherRepositoryImpl] uses [WeatherHttpClient] for weather and [PokeApiHttpClient]
/// for the type endpoint, building [PokemonSummary] without N+1 detail calls.
import 'package:pok_dex_field_assistant/core/logging/app_logger.dart';
import 'package:pok_dex_field_assistant/core/network/http_client.dart';
import 'package:pok_dex_field_assistant/core/network/weather_http_client.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/data/models/pokemon_models.dart';
import 'package:pok_dex_field_assistant/features/weather/data/models/weather_models.dart';

/// Interface for weather data and type-based Pokémon retrieval.
/// Declare dependency on this abstraction so the real impl can be swapped for a fake in tests.
abstract class WeatherRepository {
  /// Fetches current weather conditions for the given [lat]/[lon] coordinates.
  /// Returns a [WeatherData] with temperature, windspeed, and weathercode.
  Future<WeatherData> getCurrentWeather({
    required double lat,
    required double lon,
  });

  /// Returns all [PokemonSummary] items of the given [typeName].
  /// Uses the PokéAPI `/type/{name}` endpoint — no extra detail calls needed.
  Future<List<PokemonSummary>> getPokemonByType(String typeName);
}

/// Implements [WeatherRepository] using open-meteo and PokéAPI.
/// Builds [PokemonSummary] from the type endpoint response by extracting the
/// Pokémon ID from the URL and constructing a sprite URL directly — zero N+1 calls.
class WeatherRepositoryImpl implements WeatherRepository {
  /// Logger tag for this class.
  static const _tag = 'WeatherRepository';

  /// Base URL for raw PokeAPI sprites — used to build sprite URLs from IDs.
  static const _spriteBase =
      'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon';

  /// HTTP client for open-meteo weather calls — injected for testability.
  final WeatherHttpClient _weatherClient;

  /// HTTP client for PokéAPI type calls — injected for testability.
  final PokeApiHttpClient _pokeClient;

  /// Creates a [WeatherRepositoryImpl] backed by the two HTTP clients.
  WeatherRepositoryImpl(this._weatherClient, this._pokeClient);

  /// Fetches current weather from open-meteo for [lat]/[lon].
  /// Returns a parsed [WeatherData] with all fields needed for type mapping.
  @override
  Future<WeatherData> getCurrentWeather({
    required double lat,
    required double lon,
  }) async {
    AppLogger.info(_tag, 'Fetching weather — lat=$lat lon=$lon');
    try {
      /// open-meteo path includes query params directly in the path string.
      final json = await _weatherClient
          .get('/forecast?latitude=$lat&longitude=$lon&current_weather=true');
      return WeatherData.fromJson(json);
    } catch (e, s) {
      AppLogger.error(_tag, 'Failed to fetch weather', error: e, stackTrace: s);
      rethrow;
    }
  }

  /// Fetches all Pokémon of [typeName] from the PokéAPI type endpoint.
  ///
  /// Strategy to avoid N+1 calls:
  /// - The `/type/{name}` response contains a `pokemon` array where each entry
  ///   has a `url` like `https://pokeapi.co/api/v2/pokemon/16/`.
  /// - Extract the numeric ID from the URL path segments.
  /// - Build the sprite URL directly: `{_spriteBase}/{id}.png`.
  /// - Construct [PokemonSummary] with no additional network calls.
  @override
  Future<List<PokemonSummary>> getPokemonByType(String typeName) async {
    AppLogger.info(_tag, 'Fetching type "$typeName" Pokémon — all');
    try {
      /// Fetch the type detail which includes a full pokemon list.
      final json = await _pokeClient.get('/type/$typeName');

      /// `pokemon` is an array of {pokemon: {name, url}, slot} objects.
      final pokemonList = json['pokemon'] as List<dynamic>;

      /// Build summaries for all entries without extra calls.
      final summaries = pokemonList
          .map((entry) {
            /// Each entry wraps the pokemon under a `pokemon` key.
            final data =
                (entry as Map<String, dynamic>)['pokemon'] as Map<String, dynamic>;

            /// Lowercase hyphenated name from the type endpoint.
            final name = data['name'] as String;

            /// URL like "https://pokeapi.co/api/v2/pokemon/16/" — extract id.
            final url = data['url'] as String;

            /// Split on `/`, drop empties, take the last segment as the id string.
            final idStr =
                url.split('/').where((s) => s.isNotEmpty).last;
            final id = int.parse(idStr);

            /// Construct sprite URL from the known GitHub raw sprites path.
            final spriteUrl = '$_spriteBase/$id.png';

            return PokemonSummary(
              id: id,
              name: name,
              spriteUrl: spriteUrl,
              primaryType: typeName,
            );
          })
          .toList();

      AppLogger.info(_tag,
          'Loaded ${summaries.length} "$typeName"-type Pokémon');
      return summaries;
    } catch (e, s) {
      AppLogger.error(_tag, 'Failed to fetch "$typeName" type Pokémon',
          error: e, stackTrace: s);
      rethrow;
    }
  }
}
