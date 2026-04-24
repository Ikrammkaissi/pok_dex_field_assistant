/// Data-layer mapper: JSON ↔ [PokemonSummary] domain entity.
///
/// All serialisation lives here so the domain entity stays pure Dart.
/// Two JSON formats are handled:
///   - PokéAPI `/pokemon/{name}` wire format (fromApiJson)
///   - Local bookmark storage format (fromBookmarkJson / toBookmarkJson)
import 'package:pok_dex_field_assistant/core/error/exceptions.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/domain/entities/pokemon_summary.dart';

/// Converts between raw JSON maps and [PokemonSummary] domain entities.
/// Static-only class — no instances needed.
class PokemonSummaryMapper {
  PokemonSummaryMapper._();

  /// Parses a [PokemonSummary] from a `/pokemon/{nameOrId}` JSON response.
  /// Throws [ParseException] if required fields are missing or have the wrong type.
  static PokemonSummary fromApiJson(Map<String, dynamic> json) {
    try {
      /// Extract sprites object for the thumbnail URL.
      final sprites = json['sprites'] as Map<String, dynamic>;

      /// front_default can be null for some forms — fall back to empty string.
      final spriteUrl = sprites['front_default'] as String? ?? '';

      /// Primary type is the first type entry by slot order.
      final types = json['types'] as List<dynamic>? ?? const [];
      final primaryType = types.isNotEmpty
          ? ((types.first as Map<String, dynamic>)['type']
                  as Map<String, dynamic>)['name'] as String? ??
              ''
          : '';

      return PokemonSummary(
        /// Pokédex number from the top-level id field.
        id: json['id'] as int,

        /// Lowercase hyphenated name.
        name: json['name'] as String,
        spriteUrl: spriteUrl,
        primaryType: primaryType,
      );
    } catch (e) {
      /// Wrap any cast or null error in a typed ParseException.
      throw ParseException('Failed to parse PokemonSummary from API JSON: $e');
    }
  }

  /// Deserialises a [PokemonSummary] from the flat bookmark JSON format stored
  /// in SharedPreferences. Fields are written by [toBookmarkJson].
  static PokemonSummary fromBookmarkJson(Map<String, dynamic> json) =>
      PokemonSummary(
        id: json['id'] as int,
        name: json['name'] as String,
        spriteUrl: json['spriteUrl'] as String,
        primaryType: json['primaryType'] as String? ?? '',
      );

  /// Serialises [entity] to a flat JSON map suitable for local storage.
  /// The shape is intentionally simpler than PokéAPI wire format.
  static Map<String, dynamic> toBookmarkJson(PokemonSummary entity) => {
        'id': entity.id,
        'name': entity.name,
        'spriteUrl': entity.spriteUrl,
        'primaryType': entity.primaryType,
      };
}
