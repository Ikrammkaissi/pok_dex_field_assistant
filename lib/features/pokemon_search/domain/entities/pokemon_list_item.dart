/// Lightweight entity for each row in the Pokémon search list.
/// Contains only the fields the list UI needs — avoids loading full
/// detail data for every Pokémon before the user requests it.

/// Represents one row in the Pokémon search list.
class PokemonListItem {
  /// National Pokédex number (e.g. 1 for Bulbasaur).
  final int id;

  /// Lowercase hyphenated name as returned by PokéAPI (e.g. 'bulbasaur').
  final String name;

  /// URL of the front-default sprite used as the list thumbnail.
  final String spriteUrl;

  /// Name of the primary type (slot 1) in lowercase (e.g. 'grass', 'fire').
  final String primaryType;

  /// Creates an immutable [PokemonListItem].
  const PokemonListItem({
    required this.id,
    required this.name,
    required this.spriteUrl,
    required this.primaryType,
  });
}
