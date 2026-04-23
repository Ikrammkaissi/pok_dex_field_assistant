/// Data models for the Pokémon search feature.
/// [PokemonSummary] is for list rows; [PokemonDetail] is for full detail.
/// Both parse directly from PokéAPI JSON — no separate domain entities needed.
import 'package:pok_dex_field_assistant/core/error/exceptions.dart';

/// Single learnable move with learn method and level (from latest version group).
class MoveEntry {
  /// Hyphenated API move name (e.g. 'razor-wind').
  final String name;

  /// How the move is learned (e.g. 'level-up', 'machine', 'egg', 'tutor').
  final String learnMethod;

  /// Level at which move is learned; 0 means not level-up (machine/egg/tutor).
  final int levelLearnedAt;

  /// Creates an immutable [MoveEntry].
  const MoveEntry({
    required this.name,
    required this.learnMethod,
    required this.levelLearnedAt,
  });

  /// Parses from a single entry in the `moves` JSON array.
  /// Uses last version_group_details entry (most recently added game).
  factory MoveEntry.fromJson(Map<String, dynamic> json) {
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
}

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

  /// Serialises to a JSON map suitable for local storage (bookmarks).
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'spriteUrl': spriteUrl,
      };

  /// Deserialises from a locally-stored bookmark JSON map.
  /// Distinct from [fromJson] which parses PokéAPI wire format.
  factory PokemonSummary.fromBookmarkJson(Map<String, dynamic> json) =>
      PokemonSummary(
        id: json['id'] as int,
        name: json['name'] as String,
        spriteUrl: json['spriteUrl'] as String,
      );

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

  /// Back-facing default sprite URL.
  final String backSpriteUrl;

  /// Front-facing shiny sprite URL.
  final String frontShinySpriteUrl;

  /// Back-facing shiny sprite URL.
  final String backShinySpriteUrl;

  /// Official artwork URL — high-resolution image shown on the detail screen.
  final String officialArtworkUrl;

  /// Shiny official artwork URL — shown when the shiny toggle is active.
  final String officialArtworkShinyUrl;

  /// Base experience awarded when this Pokémon is defeated.
  final int baseExperience;

  /// Total number of moves this Pokémon can learn.
  final int moveCount;

  /// All learnable moves with learn method and level.
  final List<MoveEntry> moves;

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

  /// Game version names this Pokémon appears in (e.g. ['red', 'blue', 'gold']).
  final List<String> gameIndices;

  /// Latest cry audio URL (OGG) — modern sound used in recent games.
  final String cryLatestUrl;

  /// Legacy cry audio URL (OGG) — original 8-bit sound from older games.
  final String cryLegacyUrl;

  /// Creates an immutable [PokemonDetail].
  const PokemonDetail({
    required this.id,
    required this.name,
    required this.spriteUrl,
    required this.backSpriteUrl,
    required this.frontShinySpriteUrl,
    required this.backShinySpriteUrl,
    required this.officialArtworkUrl,
    required this.officialArtworkShinyUrl,
    required this.baseExperience,
    required this.moveCount,
    required this.moves,
    required this.types,
    required this.height,
    required this.weight,
    required this.abilities,
    required this.stats,
    required this.gameIndices,
    required this.cryLatestUrl,
    required this.cryLegacyUrl,
  });

  /// Parses from a `/pokemon/{nameOrId}` JSON map.
  /// Throws [ParseException] if required fields are missing or wrong type.
  factory PokemonDetail.fromJson(Map<String, dynamic> json) {
    try {
      /// Extract sprites object for the hero image URL.
      final sprites = json['sprites'] as Map<String, dynamic>;

      /// Null-safe: some forms have no front_default sprite.
      final spriteUrl = sprites['front_default'] as String? ?? '';

      /// Back-facing and shiny sprite variants — may be null for some forms.
      final backSpriteUrl = sprites['back_default'] as String? ?? '';
      final frontShinySpriteUrl = sprites['front_shiny'] as String? ?? '';
      final backShinySpriteUrl = sprites['back_shiny'] as String? ?? '';

      /// Official artwork — higher resolution than front_default sprite.
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

      /// Parse learnable moves — name + learn method + level from latest version.
      final movesRaw = json['moves'] as List<dynamic>? ?? [];
      final moves = movesRaw
          .map((m) => MoveEntry.fromJson(m as Map<String, dynamic>))
          .toList();
      final moveCount = moves.length;

      return PokemonDetail(
        id: json['id'] as int,
        name: json['name'] as String,
        spriteUrl: spriteUrl,
        backSpriteUrl: backSpriteUrl,
        frontShinySpriteUrl: frontShinySpriteUrl,
        backShinySpriteUrl: backShinySpriteUrl,
        officialArtworkUrl: officialArtworkUrl,
        officialArtworkShinyUrl: officialArtworkShinyUrl,
        /// base_experience may be null for some forms — default to 0.
        baseExperience: json['base_experience'] as int? ?? 0,
        moveCount: moveCount,
        moves: moves,
        types: types,
        /// height and weight are top-level integer fields.
        height: json['height'] as int,
        weight: json['weight'] as int,
        abilities: abilities,
        stats: stats,
        /// Extract version name from each game_indices entry.
        gameIndices: (json['game_indices'] as List<dynamic>? ?? [])
            .map((g) =>
                (g as Map<String, dynamic>)['version']['name'] as String)
            .toList(),
        /// Parse cry URLs — null if not present for this Pokémon form.
        cryLatestUrl: (json['cries'] as Map<String, dynamic>?)?['latest']
                as String? ??
            '',
        cryLegacyUrl: (json['cries'] as Map<String, dynamic>?)?['legacy']
                as String? ??
            '',
      );
    } catch (e) {
      /// Wrap any cast or null error in a typed ParseException.
      throw ParseException('Failed to parse PokemonDetail: $e');
    }
  }
}
