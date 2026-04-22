/// Immutable state for the Pokémon search screen.
/// All mutations go through [PokemonSearchController.copyWith] — never mutated in place.
import 'package:pok_dex_field_assistant/features/pokemon_search/data/models/pokemon_models.dart';

/// Represents every possible state the search screen can be in.
class PokemonSearchState {
  /// The Pokémon rows currently displayed (filtered or full list).
  final List<PokemonSummary> items;

  /// True while an async operation (initial load or search) is in progress.
  final bool isLoading;

  /// Non-null when the last operation failed; null on success.
  final String? error;

  /// The current search query — empty string means "show all".
  final String query;

  /// Creates an immutable [PokemonSearchState].
  const PokemonSearchState({
    required this.items,
    required this.isLoading,
    this.error,
    required this.query,
  });

  /// Initial state before the first load: loading spinner, no items, no error.
  factory PokemonSearchState.initial() => const PokemonSearchState(
        items: [],
        isLoading: true,
        query: '',
      );

  /// Returns a copy of this state with the specified fields replaced.
  /// Pass [clearError] to explicitly reset [error] to null.
  PokemonSearchState copyWith({
    List<PokemonSummary>? items,
    bool? isLoading,
    String? error,
    String? query,
    bool clearError = false,
  }) =>
      PokemonSearchState(
        items: items ?? this.items,
        isLoading: isLoading ?? this.isLoading,
        /// [clearError] takes precedence over an incoming [error] value.
        error: clearError ? null : (error ?? this.error),
        query: query ?? this.query,
      );
}
