/// Data-layer mapper: JSON → [PokemonDetail] and [MoveEntry] domain entities.
///
/// All JSON parsing lives here so domain entities stay pure Dart.
/// Used by [PokemonRepositoryImpl] when deserialising `/pokemon/{nameOrId}` responses.
import 'package:pok_dex_field_assistant/core/error/exceptions.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/domain/entities/move_entry.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/domain/entities/pokemon_detail.dart';

/// Converts raw PokéAPI JSON into [PokemonDetail] and [MoveEntry] entities.
/// Static-only class — no instances needed.
class PokemonDetailMapper {
  PokemonDetailMapper._();

  /// Parses a single entry from the `moves` JSON array into a [MoveEntry].
  /// Uses the last version_group_details entry (most recently added game).
  static MoveEntry moveFromJson(Map<String, dynamic> json) {
    final name = json['move']['name'] as String;
    final details = json['version_group_details'] as List<dynamic>;

    /// Last entry tends to be the most recent game version.
    final latest = details.isNotEmpty
        ? details.last as Map<String, dynamic>
        : <String, dynamic>{};
    final learnMethod =
        (latest['move_learn_method'] as Map<String, dynamic>?)?['name']
                as String? ??
            '';
    final levelLearnedAt = latest['level_learned_at'] as int? ?? 0;

    return MoveEntry(
      name: name,
      learnMethod: learnMethod,
      levelLearnedAt: levelLearnedAt,
    );
  }

  /// Parses a [PokemonDetail] from a `/pokemon/{nameOrId}` JSON response.
  /// Throws [ParseException] if required fields are missing or have the wrong type.
  static PokemonDetail fromJson(Map<String, dynamic> json) {
    try {
      /// Extract sprites object for the hero image URL.
      final sprites = json['sprites'] as Map<String, dynamic>;

      /// Null-safe: some forms have no front_default sprite.
      final spriteUrl = sprites['front_default'] as String? ?? '';
      final backSpriteUrl = sprites['back_default'] as String? ?? '';
      final frontShinySpriteUrl = sprites['front_shiny'] as String? ?? '';
      final backShinySpriteUrl = sprites['back_shiny'] as String? ?? '';

      /// Official artwork, higher resolution than front_default sprite.
      final other = sprites['other'] as Map<String, dynamic>? ?? {};
      final artwork = other['official-artwork'] as Map<String, dynamic>? ?? {};
      final officialArtworkUrl =
          artwork['front_default'] as String? ?? spriteUrl;
      final officialArtworkShinyUrl =
          artwork['front_shiny'] as String? ?? spriteUrl;

      /// Map each types entry to its type name string.
      final typesRaw = json['types'] as List<dynamic>;
      final types = typesRaw
          .map((t) => (t as Map<String, dynamic>)['type']['name'] as String)
          .toList();

      /// Map each abilities entry to ability name and hidden flag.
      final abilitiesRaw = json['abilities'] as List<dynamic>;
      final abilities = abilitiesRaw.map((a) {
        final map = a as Map<String, dynamic>;
        return (
          name: (map['ability'] as Map<String, dynamic>)['name'] as String,
          isHidden: map['is_hidden'] as bool? ?? false,
        );
      }).toList();

      /// Build stat map: stat-name → base_stat integer value.
      final statsRaw = json['stats'] as List<dynamic>;
      final stats = <String, int>{
        for (final s in statsRaw)
          (s as Map<String, dynamic>)['stat']['name'] as String:
              s['base_stat'] as int,
      };

      /// Parse learnable moves; name + learn method + level from latest version.
      final movesRaw = json['moves'] as List<dynamic>? ?? [];
      final moves =
          movesRaw.map((m) => moveFromJson(m as Map<String, dynamic>)).toList();

      return PokemonDetail(
        id: json['id'] as int,
        name: json['name'] as String,
        spriteUrl: spriteUrl,
        backSpriteUrl: backSpriteUrl,
        frontShinySpriteUrl: frontShinySpriteUrl,
        backShinySpriteUrl: backShinySpriteUrl,
        officialArtworkUrl: officialArtworkUrl,
        officialArtworkShinyUrl: officialArtworkShinyUrl,
        /// base_experience may be null for some forms; default to 0.
        baseExperience: json['base_experience'] as int? ?? 0,
        moveCount: moves.length,
        moves: moves,
        types: types,
        height: json['height'] as int,
        weight: json['weight'] as int,
        abilities: abilities,
        stats: stats,
        /// Extract version name from each game_indices entry.
        gameIndices: (json['game_indices'] as List<dynamic>? ?? [])
            .map((g) =>
                (g as Map<String, dynamic>)['version']['name'] as String)
            .toList(),
        cryLatestUrl: (json['cries'] as Map<String, dynamic>?)?['latest']
                as String? ??
            '',
        cryLegacyUrl: (json['cries'] as Map<String, dynamic>?)?['legacy']
                as String? ??
            '',
      );
    } catch (e) {
      /// Wrap any cast or null error in a typed ParseException.
      throw ParseException('Failed to parse PokemonDetail from JSON: $e');
    }
  }
}
