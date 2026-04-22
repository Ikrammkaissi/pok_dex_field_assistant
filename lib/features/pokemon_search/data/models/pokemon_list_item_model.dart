/// Data-layer DTO for a single Pokémon list row.
/// Parsed from the `/pokemon/{nameOrId}` detail response because the bare
/// list endpoint (`/pokemon?limit=N`) returns only name + url — no types
/// or sprites.
import 'package:pok_dex_field_assistant/core/error/exceptions.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/domain/entities/pokemon_list_item.dart';

/// DTO carrying only the fields needed to render one row in the search list.
class PokemonListItemModel {
  /// National Pokédex number.
  final int id;

  /// Lowercase hyphenated name (e.g. 'bulbasaur').
  final String name;

  /// Front-default sprite URL used as the row thumbnail.
  final String spriteUrl;

  /// Primary type name (slot 1, e.g. 'grass', 'fire').
  final String primaryType;

  /// Creates an immutable [PokemonListItemModel].
  const PokemonListItemModel({
    required this.id,
    required this.name,
    required this.spriteUrl,
    required this.primaryType,
  });

  /// Parses a [PokemonListItemModel] from a `/pokemon/{nameOrId}` JSON map.
  ///
  /// Expected shape (abbreviated):
  /// ```json
  /// {
  ///   "id": 1,
  ///   "name": "bulbasaur",
  ///   "sprites": { "front_default": "https://..." },
  ///   "types": [ { "type": { "name": "grass" } } ]
  /// }
  /// ```
  ///
  /// Throws [ParseException] if required fields are missing or have the wrong type.
  factory PokemonListItemModel.fromJson(Map<String, dynamic> json) {
    try {
      /// Extract the nested sprites object to get the thumbnail URL.
      final sprites = json['sprites'] as Map<String, dynamic>;
      /// `front_default` can be null for some Pokémon forms — use empty string.
      final spriteUrl = sprites['front_default'] as String? ?? '';

      /// The types array is ordered by slot; first element is the primary type.
      final types = json['types'] as List<dynamic>;
      /// Navigate types[0]['type']['name'] to get the type string.
      final primaryType =
          (types.first as Map<String, dynamic>)['type']['name'] as String;

      return PokemonListItemModel(
        /// Pokédex number from the top-level id field.
        id: json['id'] as int,
        /// Lowercase hyphenated name.
        name: json['name'] as String,
        spriteUrl: spriteUrl,
        primaryType: primaryType,
      );
    } catch (e) {
      /// Wrap any cast / null error in a typed ParseException.
      throw ParseException('Failed to parse PokemonListItemModel: $e');
    }
  }

  /// Converts this DTO to the domain [PokemonListItem] entity.
  PokemonListItem toEntity() => PokemonListItem(
        id: id,
        name: name,
        spriteUrl: spriteUrl,
        primaryType: primaryType,
      );
}
