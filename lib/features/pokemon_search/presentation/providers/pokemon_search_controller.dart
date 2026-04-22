/// Search screen controller — owns async logic and state transitions.
/// The UI layer reads state from Riverpod and calls methods here; it never
/// talks to the repository directly.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pok_dex_field_assistant/core/error/exceptions.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/domain/repositories/pokemon_repository.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/presentation/providers/pokemon_search_state.dart';

/// Manages [PokemonSearchState] in response to user interactions.
/// Starts the initial load automatically on construction.
class PokemonSearchController extends StateNotifier<PokemonSearchState> {
  /// Repository injected by the Riverpod provider — mockable in tests.
  final PokemonRepository _repository;

  /// Creates [PokemonSearchController] and fires the initial load immediately.
  PokemonSearchController(this._repository)
      : super(PokemonSearchState.initial()) {
    init();
  }

  /// Loads the first 100 Pokémon and stores them in state.
  /// Called automatically on construction and by [retry].
  Future<void> init() async {
    /// Show loading spinner; clear any previous error.
    state = state.copyWith(isLoading: true, clearError: true, query: '');
    try {
      /// Fetch enriched list (name + type + sprite) for 100 Pokémon.
      final items = await _repository.getPokemonList(limit: 100);
      state = state.copyWith(items: items, isLoading: false);
    } catch (e) {
      /// Map typed exceptions to user-readable messages.
      state = state.copyWith(
        isLoading: false,
        error: _errorMessage(e),
      );
    }
  }

  /// Filters the cached list by [query] and updates state.
  /// Called by the search bar's onChanged callback.
  Future<void> search(String query) async {
    /// Update the query field so the UI can reflect it.
    state = state.copyWith(query: query, isLoading: true, clearError: true);
    try {
      /// Repository filters client-side — no extra HTTP calls.
      final items = await _repository.searchPokemon(query);
      state = state.copyWith(items: items, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _errorMessage(e));
    }
  }

  /// Resets to the initial state and re-runs [init].
  /// Exposed so the error screen can show a Retry button.
  Future<void> retry() => init();

  /// Translates typed exceptions into short user-facing strings.
  String _errorMessage(Object e) {
    if (e is NetworkException) return 'No internet connection.';
    if (e is ServerException) return 'Server error (${e.statusCode}).';
    if (e is ParseException) return 'Data error — please try again.';
    return 'Something went wrong.';
  }
}
