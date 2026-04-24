/// Concrete implementation of [WeatherRepository] backed by Open-Meteo and PokéAPI.
///
/// Lives in the data layer — the only layer allowed to import HTTP clients and
/// JSON parsing mappers.  The domain layer depends on the abstract
/// [WeatherRepository] interface, not this class, so either API can be swapped
/// without touching use cases or the controller.
import 'package:pok_dex_field_assistant/core/logging/app_logger.dart';
import 'package:pok_dex_field_assistant/core/network/http_client.dart';
import 'package:pok_dex_field_assistant/core/network/weather_http_client.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/domain/entities/pokemon_summary.dart';
import 'package:pok_dex_field_assistant/features/weather/data/models/weather_data_mapper.dart';
import 'package:pok_dex_field_assistant/features/weather/domain/entities/weather_data.dart';
import 'package:pok_dex_field_assistant/features/weather/domain/repositories/weather_repository.dart';

/// Implements [WeatherRepository] using Open-Meteo (weather) and PokéAPI (types).
///
/// Sprite URL strategy — avoids N+1 calls:
/// The `/type/{name}` response includes a `pokemon` array where each entry has
/// a canonical URL like `https://pokeapi.co/api/v2/pokemon/16/`.
/// Extracting the trailing numeric ID and inserting it into the GitHub CDN path
/// gives the sprite URL without any extra requests.
class WeatherRepositoryImpl implements WeatherRepository {
  /// Logger tag used for all log lines emitted by this class.
  static const _tag = 'WeatherRepository';

  /// GitHub raw sprites CDN path, used to construct sprite URLs from Pokémon IDs.
  static const _spriteBase =
      'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon';

  /// HTTP client for Open-Meteo weather calls, injected for testability.
  final WeatherHttpClient _weatherClient;

  /// HTTP client for PokéAPI type-endpoint calls, injected for testability.
  final PokeApiHttpClient _pokeClient;

  /// Creates a [WeatherRepositoryImpl] backed by the two HTTP clients.
  WeatherRepositoryImpl(this._weatherClient, this._pokeClient);

  /// Fetches current weather from Open-Meteo for the position at [lat] / [lon].
  /// [WeatherDataMapper] converts the raw JSON to a [WeatherData] entity.
  @override
  Future<WeatherData> getCurrentWeather({
    required double lat,
    required double lon,
  }) async {
    AppLogger.info(_tag, 'Fetching weather , lat=$lat lon=$lon');
    try {
      /// Open-Meteo query params are embedded directly in the path string.
      final json = await _weatherClient
          .get('/forecast?latitude=$lat&longitude=$lon&current_weather=true');
      return WeatherDataMapper.fromJson(json);
    } catch (e, s) {
      AppLogger.error(_tag, 'Failed to fetch weather', error: e, stackTrace: s);
      rethrow;
    }
  }

  /// Fetches all Pokémon of [typeName] from the PokéAPI `/type/{name}` endpoint.
  ///
  /// Each entry in the `pokemon` array has a `url` field with the Pokémon ID
  /// embedded in the path (e.g. `.../pokemon/16/`).  Parsing that ID and
  /// constructing `_spriteBase/{id}.png` gives the sprite without extra calls.
  /// Non-numeric IDs (e.g. for alternate forms) are skipped with a warning log.
  @override
  Future<List<PokemonSummary>> getPokemonByType(String typeName) async {
    AppLogger.info(_tag, 'Fetching type "$typeName" Pokémon , all');
    try {
      /// Fetch the type detail, which includes the full pokemon list for that type.
      final json = await _pokeClient.get('/type/$typeName');

      /// `pokemon` is an array of {pokemon: {name, url}, slot} objects.
      final pokemonList = json['pokemon'] as List<dynamic>;

      /// Map each entry to a [PokemonSummary] entity without extra network calls.
      final summaries = pokemonList
          .map<PokemonSummary?>((entry) {
            /// Each item nests the pokemon data under a `pokemon` key.
            final data = (entry as Map<String, dynamic>)['pokemon']
                as Map<String, dynamic>;

            /// Lowercase hyphenated name from the type endpoint response.
            final name = data['name'] as String;

            /// Canonical URL like "https://pokeapi.co/api/v2/pokemon/16/".
            final url = data['url'] as String;

            /// Split on `/`, drop empty segments, take the last — always the numeric ID.
            final idStr = url.split('/').where((s) => s.isNotEmpty).last;
            final id = int.tryParse(idStr);
            if (id == null) {
              /// Skip alternate-form entries whose IDs are non-numeric.
              AppLogger.warning(
                _tag,
                'Skipping entry with non-numeric pokemon ID: $idStr',
              );
              return null;
            }

            /// Construct the front-default sprite URL from the GitHub CDN path.
            return PokemonSummary(
              id: id,
              name: name,
              spriteUrl: '$_spriteBase/$id.png',
              /// All Pokémon from a type endpoint share that type as primary.
              primaryType: typeName,
            );
          })
          .whereType<PokemonSummary>()
          .toList();

      AppLogger.info(
          _tag, 'Loaded ${summaries.length} "$typeName"-type Pokémon');
      return summaries;
    } catch (e, s) {
      AppLogger.error(_tag, 'Failed to fetch "$typeName" type Pokémon',
          error: e, stackTrace: s);
      rethrow;
    }
  }
}
