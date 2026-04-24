/// Domain entity representing one learnable move.
///
/// Pure Dart — no JSON parsing, no framework imports.
/// JSON ↔ entity conversion lives in [PokemonDetailMapper] (data layer).

/// A single learnable move with its learn method and level.
class MoveEntry {
  /// Hyphenated API move name (e.g. 'razor-wind').
  final String name;

  /// How the move is learned (e.g. 'level-up', 'machine', 'egg', 'tutor').
  final String learnMethod;

  /// Level at which the move is learned; 0 means non-level-up method.
  final int levelLearnedAt;

  /// Creates an immutable [MoveEntry].
  const MoveEntry({
    required this.name,
    required this.learnMethod,
    required this.levelLearnedAt,
  });
}
