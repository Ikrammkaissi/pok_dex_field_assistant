/// Full Pokémon detail entity — all fields shown on the detail screen.
/// Pure Dart; no Flutter or HTTP imports.

/// Represents every field the detail screen needs for a single Pokémon.
class PokemonDetail {
  /// National Pokédex number (e.g. 6 for Charizard).
  final int id;

  /// Lowercase hyphenated name as returned by PokéAPI (e.g. 'charizard').
  final String name;

  /// Front-default sprite URL used as the hero image.
  final String spriteUrl;

  /// All type names in slot order (e.g. ['fire', 'flying']).
  /// Always at least one element.
  final List<String> types;

  /// Height in decimetres as returned by PokéAPI.
  final int height;

  /// Weight in hectograms as returned by PokéAPI.
  final int weight;

  /// Ability names in slot order (non-hidden first, hidden last).
  final List<String> abilities;

  /// Base stat values keyed by PokéAPI stat name
  /// (e.g. {'hp': 78, 'attack': 84, 'defense': 78, ...}).
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
}
