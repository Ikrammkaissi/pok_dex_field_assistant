/// Search screen controller — owns async logic and state transitions.
///
/// The UI layer reads [PokemonSearchState] from Riverpod and calls methods here;
/// it never imports repositories or use cases directly.
/// The controller depends only on [GetPokemonList] (domain use case), keeping
/// the presentation layer decoupled from the data layer.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pok_dex_field_assistant/core/error/exceptions.dart';
import 'package:pok_dex_field_assistant/core/logging/app_logger.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/domain/entities/pokemon_summary.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/domain/usecases/get_pokemon_list.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/presentation/providers/pokemon_search_state.dart';

/// Number of Pokémon fetched on the first load.
const _initialPageSize = 100;

/// Number of Pokémon fetched on each subsequent pagination step.
const _pageSize = 30;

/// Minimum filtered results before auto-fetch stops trying to find more.
const _minSearchResults = 20;

/// Manages [PokemonSearchState] in response to user interactions.
/// Items accumulate in memory as the user scrolls — no eviction.
/// During search, results are loaded from offset 0; clearing search reloads
/// browse mode from scratch.
class PokemonSearchController extends StateNotifier<PokemonSearchState> {
  /// Logger tag used for all log lines emitted by this class.
  static const _tag = 'SearchController';

  /// Use case that fetches one paginated page of Pokémon from PokéAPI.
  final GetPokemonList _getPokemonList;

  /// All Pokémon loaded so far. Grows on scroll; cleared on reload.
  final List<PokemonSummary> _items = [];

  /// Tracks the in-flight init future so concurrent callers share one request.
  Future<void>? _ongoingInit;

  /// Creates [PokemonSearchController] and fires the initial load immediately
  /// so the search screen is populated as soon as the provider is first read.
  PokemonSearchController(this._getPokemonList)
      : super(PokemonSearchState.initial()) {
    init();
  }

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Loads the first page and resets all accumulated state.
  /// Concurrent callers share the same in-flight future to prevent double-load.
  Future<void> init() {
    _ongoingInit ??= _doInit().whenComplete(() => _ongoingInit = null);
    return _ongoingInit!;
  }

  /// Fetches the next page and appends it to the list.
  /// No-op when: a load is in progress or no more pages exist.
  Future<void> loadMore() async {
    if (state.isLoadingMore || state.isLoading || !state.hasMore) return;

    final query = state.query;
    final previousVisibleCount = state.items.length;
    final nextOffset = _items.length;
    AppLogger.debug(_tag, 'loadMore , offset=$nextOffset, query="${state.query}"');
    state = state.copyWith(isLoadingMore: true);
    try {
      final page = await _getPokemonList(
          limit: _pageSize, offset: nextOffset);

      _items.addAll(page.items);

      final items = _applyFilter(state.query);
      AppLogger.info(_tag,
          'loadMore , raw=${_items.length}, visible=${items.length}, hasMore=${page.hasMore}');
      state = state.copyWith(
        items: items,
        isLoadingMore: false,
        hasMore: page.hasMore,
        clearError: true,
      );

      /// In search mode, keep paging forward until this fetch yields at least
      /// one additional visible result or the API is exhausted.
      if (query.isNotEmpty &&
          state.query == query &&
          state.items.length == previousVisibleCount &&
          state.hasMore) {
        await _autoFetchUntilVisibleCountExceeds(query, previousVisibleCount);
      }
    } catch (e, s) {
      AppLogger.error(_tag, 'loadMore failed at offset=$nextOffset',
          error: e, stackTrace: s);
      state = state.copyWith(isLoadingMore: false, error: _errorMessage(e));
    }
  }

  /// Filters the already-loaded list by [query] — no API call.
  ///
  /// When [query] is non-empty, auto-fetches additional pages only if the
  /// current list yields fewer than [_minSearchResults] matching items.
  ///
  /// When [query] is cleared, shows all items already in memory.
  Future<void> search(String query) async {
    AppLogger.debug(_tag, 'search , query: "$query"');

    state = state.copyWith(
      query: query,
      items: _applyFilter(query),
      isLoadingMore: false,
      clearError: true,
    );

    if (query.isNotEmpty) {
      await _autoFetchIfNeeded(query);
    }
  }

  /// Resets to the initial state and re-runs [init].
  Future<void> retry() {
    AppLogger.info(_tag, 'retry triggered');
    _ongoingInit = null;
    return init();
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  Future<void> _doInit() async {
    AppLogger.debug(
        _tag, 'init , loading first batch (limit=$_initialPageSize, offset=0)');
    _items.clear();
    state = PokemonSearchState.initial();
    try {
      final page = await _getPokemonList(
          limit: _initialPageSize, offset: 0);
      _items.addAll(page.items);
      state = state.copyWith(
        items: List.unmodifiable(_items),
        isLoading: false,
        hasMore: page.hasMore,
        clearError: true,
      );
      AppLogger.info(_tag, 'init complete , ${_items.length} items loaded');
    } catch (e, s) {
      AppLogger.error(_tag, 'init failed', error: e, stackTrace: s);
      state = state.copyWith(isLoading: false, error: _errorMessage(e));
    }
  }

  /// Keeps fetching pages until [_minSearchResults] filtered items are found,
  /// no more pages exist, or the query changes mid-loop.
  Future<void> _autoFetchIfNeeded(String query) async {
    while (mounted &&
        state.query == query &&
        state.query.isNotEmpty &&
        state.items.length < _minSearchResults &&
        state.hasMore &&
        !state.isLoadingMore &&
        state.error == null) {
      AppLogger.debug(_tag,
          'autoFetch , only ${state.items.length} results, fetching more');
      await loadMore();
    }
  }

  /// Keeps fetching additional search pages until at least one more filtered
  /// result appears beyond [minimumVisibleCount], or no more data exists.
  Future<void> _autoFetchUntilVisibleCountExceeds(
    String query,
    int minimumVisibleCount,
  ) async {
    while (mounted &&
        state.query == query &&
        state.query.isNotEmpty &&
        state.items.length <= minimumVisibleCount &&
        state.hasMore &&
        !state.isLoadingMore &&
        state.error == null) {
      AppLogger.debug(_tag,
          'autoFetchVisibleHit , still at ${state.items.length} results, fetching more');
      await loadMore();
    }
  }

  /// Returns the list filtered by [query], or all items when [query] is empty.
  List<PokemonSummary> _applyFilter(String query) {
    if (query.isEmpty) return List.unmodifiable(_items);
    final lower = query.toLowerCase();
    return _items.where((p) => p.name.contains(lower)).toList();
  }

  /// Translates typed exceptions into short user-facing strings.
  String _errorMessage(Object e) {
    if (e is NetworkException) return 'No internet connection.';
    if (e is ServerException) return 'Server error (${e.statusCode}).';
    if (e is ParseException) return 'Data error , please try again.';
    return 'Something went wrong.';
  }
}
