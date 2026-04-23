/// Immutable state for the Pokémon search screen.
/// All mutations go through [PokemonSearchController] , never mutated in place.
import 'package:pok_dex_field_assistant/features/pokemon_search/data/models/pokemon_models.dart';

/// Represents every possible state the search screen can be in.
class PokemonSearchState {
  /// The Pokémon rows currently displayed (all loaded items or filtered subset).
  final List<PokemonSummary> items;

  /// True while the initial page load is in progress.
  final bool isLoading;

  /// True while the next page is being fetched.
  final bool isLoadingMore;

  /// Non-null when the last operation failed; null on success.
  final String? error;

  /// The current search query , empty string means "show all".
  final String query;

  /// True when the API indicates a next page exists.
  final bool hasMore;

  /// Creates an immutable [PokemonSearchState].
  const PokemonSearchState({
    required this.items,
    required this.isLoading,
    required this.isLoadingMore,
    this.error,
    required this.query,
    required this.hasMore,
  });

  /// Initial state before the first load: loading spinner, no items, no error.
  factory PokemonSearchState.initial() => const PokemonSearchState(
        items: [],
        isLoading: true,
        isLoadingMore: false,
        query: '',
        hasMore: true,
      );

  /// Returns a copy of this state with the specified fields replaced.
  /// Pass [clearError] to explicitly reset [error] to null.
  PokemonSearchState copyWith({
    List<PokemonSummary>? items,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    String? query,
    bool? hasMore,
    bool clearError = false,
  }) =>
      PokemonSearchState(
        items: items ?? this.items,
        isLoading: isLoading ?? this.isLoading,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        error: clearError ? null : (error ?? this.error),
        query: query ?? this.query,
        hasMore: hasMore ?? this.hasMore,
      );
}
