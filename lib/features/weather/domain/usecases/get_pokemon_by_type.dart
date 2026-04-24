/// Use case: fetch all Pokémon of a given type.
///
/// Single-responsibility class that wraps [WeatherRepository.getPokemonByType].
/// [WeatherController] calls this after deriving the suggested type from
/// weather conditions, keeping the presentation layer decoupled from
/// the PokéAPI type-endpoint implementation.
import 'package:pok_dex_field_assistant/features/pokemon_search/data/models/pokemon_models.dart';
import 'package:pok_dex_field_assistant/features/weather/domain/repositories/weather_repository.dart';

/// Encapsulates the "fetch Pokémon of a specific type" operation.
/// Injected via [getPokemonByTypeProvider] so tests can supply a fake
/// without touching the provider graph.
class GetPokemonByType {
  /// Repository that calls the PokéAPI type endpoint.
  final WeatherRepository _repository;

  /// Creates [GetPokemonByType] backed by [repository].
  GetPokemonByType(this._repository);

  /// Returns all [PokemonSummary] items whose primary type matches [typeName].
  /// Sprite URLs are derived from the type-endpoint response — no N+1 calls.
  Future<List<PokemonSummary>> call(String typeName) =>
      _repository.getPokemonByType(typeName);
}
