/// Immutable state for the Pokémon search screen.
/// All mutations go through [PokemonSearchController] — never mutated in place.
import 'package:pok_dex_field_assistant/features/pokemon_search/data/models/pokemon_models.dart';

/// Represents every possible state the search screen can be in.
class PokemonSearchState {
  /// The Pokémon rows currently displayed (current window or filtered subset).
  final List<PokemonSummary> items;

  /// True while the initial page load is in progress.
  final bool isLoading;

  /// True while the next (forward) page is being fetched.
  final bool isLoadingMore;

  /// True while the previous (backward) page is being fetched.
  final bool isLoadingPrevious;

  /// Non-null when the last operation failed; null on success.
  final String? error;

  /// The current search query — empty string means "show all".
  final String query;

  /// API offset of the first item currently in the window.
  /// Increases when items are dropped from the top (scroll-down window shift).
  /// Decreases when items are prepended (scroll-up window shift).
  /// The UI uses this to detect prepends and compensate scroll position.
  final int windowStartOffset;

  /// True when the API indicates a next page exists ahead of the window.
  final bool hasMore;

  /// True when the window does not start at offset 0 (previous pages exist).
  final bool hasPrevious;

  /// Creates an immutable [PokemonSearchState].
  const PokemonSearchState({
    required this.items,
    required this.isLoading,
    required this.isLoadingMore,
    required this.isLoadingPrevious,
    this.error,
    required this.query,
    required this.windowStartOffset,
    required this.hasMore,
    required this.hasPrevious,
  });

  /// Initial state before the first load: loading spinner, no items, no error.
  factory PokemonSearchState.initial() => const PokemonSearchState(
        items: [],
        isLoading: true,
        isLoadingMore: false,
        isLoadingPrevious: false,
        query: '',
        windowStartOffset: 0,
        hasMore: true,
        hasPrevious: false,
      );

  /// Returns a copy of this state with the specified fields replaced.
  /// Pass [clearError] to explicitly reset [error] to null.
  PokemonSearchState copyWith({
    List<PokemonSummary>? items,
    bool? isLoading,
    bool? isLoadingMore,
    bool? isLoadingPrevious,
    String? error,
    String? query,
    int? windowStartOffset,
    bool? hasMore,
    bool? hasPrevious,
    bool clearError = false,
  }) =>
      PokemonSearchState(
        items: items ?? this.items,
        isLoading: isLoading ?? this.isLoading,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        isLoadingPrevious: isLoadingPrevious ?? this.isLoadingPrevious,
        error: clearError ? null : (error ?? this.error),
        query: query ?? this.query,
        windowStartOffset: windowStartOffset ?? this.windowStartOffset,
        hasMore: hasMore ?? this.hasMore,
        hasPrevious: hasPrevious ?? this.hasPrevious,
      );
}
