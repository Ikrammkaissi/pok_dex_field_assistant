/// Domain value object for one page of paginated Pokémon results.
///
/// Pure Dart — no JSON parsing, no framework imports.
import 'package:pok_dex_field_assistant/features/pokemon_search/domain/entities/pokemon_summary.dart';

/// Wraps one page of [PokemonSummary] items with a continuation flag.
class PokemonListPage {
  /// Pokémon summaries in this page.
  final List<PokemonSummary> items;

  /// True when the API response indicates a next page exists.
  final bool hasMore;

  /// Creates an immutable [PokemonListPage].
  const PokemonListPage({required this.items, required this.hasMore});
}
