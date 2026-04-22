/// Data-layer DTO for full Pokémon detail.
/// Parsed from the `/pokemon/{nameOrId}` JSON response.
import 'package:pok_dex_field_assistant/core/error/exceptions.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/domain/entities/pokemon_detail.dart';

/// DTO carrying all fields shown on the detail screen.
class PokemonDetailModel {
  /// National Pokédex number.
  final int id;

  /// Lowercase hyphenated name (e.g. 'charizard').
  final String name;

  /// Front-default sprite URL used as the hero image.
  final String spriteUrl;

  /// All type names in slot order (e.g. ['fire', 'flying']).
  final List<String> types;

  /// Height in decimetres as returned by PokéAPI.
  final int height;

  /// Weight in hectograms as returned by PokéAPI.
  final int weight;

  /// Ability names in slot order (non-hidden first, hidden last).
  final List<String> abilities;

  /// Base stat values keyed by stat name (e.g. {'hp': 78, 'attack': 84}).
  final Map<String, int> stats;

  /// Creates an immutable [PokemonDetailModel].
  const PokemonDetailModel({
    required this.id,
    required this.name,
    required this.spriteUrl,
    required this.types,
    required this.height,
    required this.weight,
    required this.abilities,
    required this.stats,
  });

  /// Parses a [PokemonDetailModel] from a `/pokemon/{nameOrId}` JSON map.
  ///
  /// Expected shape (abbreviated):
  /// ```json
  /// {
  ///   "id": 6, "name": "charizard", "height": 17, "weight": 905,
  ///   "sprites": { "front_default": "https://..." },
  ///   "types":     [ { "type":    { "name": "fire"  } }, ... ],
  ///   "abilities":  [ { "ability": { "name": "blaze" } }, ... ],
  ///   "stats":     [ { "stat": { "name": "hp" }, "base_stat": 78 }, ... ]
  /// }
  /// ```
  ///
  /// Throws [ParseException] if required fields are missing or have the wrong type.
  factory PokemonDetailModel.fromJson(Map<String, dynamic> json) {
    try {
      /// Extract the nested sprites object for the hero image URL.
      final sprites = json['sprites'] as Map<String, dynamic>;
      /// Null-safe: some forms have no front_default sprite.
      final spriteUrl = sprites['front_default'] as String? ?? '';

      /// Map each types array entry to its type name string.
      final typesRaw = json['types'] as List<dynamic>;
      final types = typesRaw
          .map((t) => (t as Map<String, dynamic>)['type']['name'] as String)
          .toList();

      /// Map each abilities array entry to its ability name string.
      final abilitiesRaw = json['abilities'] as List<dynamic>;
      final abilities = abilitiesRaw
          .map((a) => (a as Map<String, dynamic>)['ability']['name'] as String)
          .toList();

      /// Build stat map: stat-name → base_stat integer value.
      final statsRaw = json['stats'] as List<dynamic>;
      final stats = <String, int>{
        for (final s in statsRaw)
          (s as Map<String, dynamic>)['stat']['name'] as String:
              s['base_stat'] as int,
      };

      return PokemonDetailModel(
        id: json['id'] as int,
        name: json['name'] as String,
        spriteUrl: spriteUrl,
        types: types,
        /// height and weight are top-level integer fields.
        height: json['height'] as int,
        weight: json['weight'] as int,
        abilities: abilities,
        stats: stats,
      );
    } catch (e) {
      /// Wrap any cast / null error in a typed ParseException.
      throw ParseException('Failed to parse PokemonDetailModel: $e');
    }
  }

  /// Converts this DTO to the domain [PokemonDetail] entity.
  PokemonDetail toEntity() => PokemonDetail(
        id: id,
        name: name,
        spriteUrl: spriteUrl,
        types: types,
        height: height,
        weight: weight,
        abilities: abilities,
        stats: stats,
      );
}
