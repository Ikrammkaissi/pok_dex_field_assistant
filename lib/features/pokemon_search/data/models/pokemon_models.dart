/// Data models for the Pokémon search feature.
/// [PokemonSummary] is for list rows; [PokemonDetail] is for full detail.
/// Both parse directly from PokéAPI JSON — no separate domain entities needed.
import 'package:pok_dex_field_assistant/core/error/exceptions.dart';

/// Lightweight model for one row in the search list.
/// Parsed from `/pokemon/{nameOrId}` detail response because the bare
/// list endpoint returns only name + url — no sprites.
class PokemonSummary {
  /// National Pokédex number.
  final int id;

  /// Lowercase hyphenated name (e.g. 'bulbasaur').
  final String name;

  /// Front-default sprite URL used as the row thumbnail.
  final String spriteUrl;

  /// Creates an immutable [PokemonSummary].
  const PokemonSummary({
    required this.id,
    required this.name,
    required this.spriteUrl,
  });

  /// Parses from a `/pokemon/{nameOrId}` JSON map.
  /// Throws [ParseException] if required fields are missing or wrong type.
  factory PokemonSummary.fromJson(Map<String, dynamic> json) {
    try {
      /// Extract sprites object for the thumbnail URL.
      final sprites = json['sprites'] as Map<String, dynamic>;

      /// front_default can be null for some forms — fall back to empty string.
      final spriteUrl = sprites['front_default'] as String? ?? '';

      return PokemonSummary(
        /// Pokédex number from the top-level id field.
        id: json['id'] as int,

        /// Lowercase hyphenated name.
        name: json['name'] as String,
        spriteUrl: spriteUrl,
      );
    } catch (e) {
      /// Wrap any cast or null error in a typed ParseException.
      throw ParseException('Failed to parse PokemonSummary: $e');
    }
  }
}

/// One page of results from the paginated list endpoint.
/// [hasMore] is true when [next] in the API response is non-null.
class PokemonListPage {
  /// Pokémon summaries in this page.
  final List<PokemonSummary> items;

  /// True when there are more pages to load.
  final bool hasMore;

  /// Creates an immutable [PokemonListPage].
  const PokemonListPage({required this.items, required this.hasMore});
}

/// Full Pokémon detail model — all fields shown on the detail screen.
/// Parsed from the `/pokemon/{nameOrId}` JSON response.
class PokemonDetail {
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

  /// Creates an immutable [PokemonDetail].
  const PokemonDetail({
    required this.id,
    required this.name,
    required this.spriteUrl,
    required this.types,
    required this.height,
    required this.weight,
    required this.abilities,
    required this.stats,
  });

  /// Parses from a `/pokemon/{nameOrId}` JSON map.
  /// Throws [ParseException] if required fields are missing or wrong type.
  factory PokemonDetail.fromJson(Map<String, dynamic> json) {
    try {
      /// Extract sprites object for the hero image URL.
      final sprites = json['sprites'] as Map<String, dynamic>;

      /// Null-safe: some forms have no front_default sprite.
      final spriteUrl = sprites['front_default'] as String? ?? '';

      /// Map each types entry to its type name string.
      final typesRaw = json['types'] as List<dynamic>;
      final types = typesRaw
          .map((t) => (t as Map<String, dynamic>)['type']['name'] as String)
          .toList();

      /// Map each abilities entry to its ability name string.
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

      return PokemonDetail(
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
      /// Wrap any cast or null error in a typed ParseException.
      throw ParseException('Failed to parse PokemonDetail: $e');
    }
  }
}
