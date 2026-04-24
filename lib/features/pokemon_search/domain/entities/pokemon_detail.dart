/// Domain entity for full Pokémon detail.
///
/// Pure Dart — no JSON parsing, no framework imports.
/// JSON ↔ entity conversion lives in [PokemonDetailMapper] (data layer).
import 'package:pok_dex_field_assistant/features/pokemon_search/domain/entities/move_entry.dart';

/// All data shown on the Pokémon detail screen.
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

  /// Official artwork URL, high-resolution image shown on the detail screen.
  final String officialArtworkUrl;

  /// Shiny official artwork URL, shown when the shiny toggle is active.
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

  /// Ability entries in slot order with `isHidden` flag.
  final List<({String name, bool isHidden})> abilities;

  /// Base stat values keyed by stat name (e.g. {'hp': 78, 'attack': 84}).
  final Map<String, int> stats;

  /// Game version names this Pokémon appears in (e.g. ['red', 'blue']).
  final List<String> gameIndices;

  /// Latest cry audio URL (OGG), modern sound used in recent games.
  final String cryLatestUrl;

  /// Legacy cry audio URL (OGG), original 8-bit sound from older games.
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
}
