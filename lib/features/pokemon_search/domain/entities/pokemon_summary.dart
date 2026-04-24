/// Domain entity for a single Pokémon list row.
///
/// Pure Dart — no JSON parsing, no framework imports.
/// JSON ↔ entity conversion lives in [PokemonSummaryMapper] (data layer).
/// Bookmark JSON serialisation also lives in [PokemonSummaryMapper].

/// Lightweight snapshot used in lists, bookmarks, and weather suggestions.
class PokemonSummary {
  /// National Pokédex number.
  final int id;

  /// Lowercase hyphenated name (e.g. 'bulbasaur').
  final String name;

  /// Front-default sprite URL used as the row thumbnail.
  final String spriteUrl;

  /// Primary Pokémon type (first item in the API `types` array).
  final String primaryType;

  /// Creates an immutable [PokemonSummary].
  const PokemonSummary({
    required this.id,
    required this.name,
    required this.spriteUrl,
    this.primaryType = '',
  });
}
