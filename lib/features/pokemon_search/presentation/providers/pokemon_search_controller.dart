/// Search screen controller , owns async logic and state transitions.
/// The UI layer reads state from Riverpod and calls methods here; it never
/// talks to the repository directly.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pok_dex_field_assistant/core/error/exceptions.dart';
import 'package:pok_dex_field_assistant/core/logging/app_logger.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/data/models/pokemon_models.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/data/pokemon_repository.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/presentation/providers/pokemon_search_state.dart';

/// Number of Pokémon fetched on the first load.
const _initialPageSize = 100;

/// Number of Pokémon fetched on each subsequent pagination step.
const _pageSize = 30;

/// Maximum raw items kept in the window during browse mode.
const _maxWindow = 180;

/// Minimum filtered results before auto-fetch stops trying to find more.
const _minSearchResults = 20;

/// Manages [PokemonSearchState] in response to user interactions.
/// Implements a sliding window for browse mode (max [_maxWindow] raw items).
/// During search, results are reloaded from offset 0 and clearing the search
/// reloads browse mode from scratch.
class PokemonSearchController extends StateNotifier<PokemonSearchState> {
  /// Logger tag for this class.
  static const _tag = 'SearchController';

  /// Repository injected by the Riverpod provider , mockable in tests.
  final PokemonRepository _repository;

  /// The current raw window of Pokémon.
  /// Browse mode: capped at [_maxWindow] with sliding.
  /// Search mode: grows beyond [_maxWindow] until search is cleared.
  final List<PokemonSummary> _window = [];

  /// API offset of the first item in [_window].
  int _windowStartOffset = 0;

  /// Tracks the in-flight init so concurrent callers share one future.
  Future<void>? _ongoingInit;

  /// Creates [PokemonSearchController] and fires the initial load immediately.
  PokemonSearchController(this._repository)
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

  /// Fetches the next page and appends it to the window.
  ///
  /// Browse mode: drops the leading page when the window exceeds [_maxWindow].
  /// Search mode: never drops items (window grows to find more matching results).
  ///
  /// No-op when: a load is in progress or no more pages exist.
  Future<void> loadMore() async {
    if (state.isLoadingMore || state.isLoading || !state.hasMore) return;

    final query = state.query;
    final previousVisibleCount = state.items.length;
    final nextOffset = _windowStartOffset + _window.length;
    AppLogger.debug(_tag, 'loadMore , offset=$nextOffset, query="${state.query}"');
    state = state.copyWith(isLoadingMore: true);
    try {
      final page = await _repository.getPokemonList(
          limit: _pageSize, offset: nextOffset);

      _window.addAll(page.items);

      /// Only slide the window in browse mode to cap memory usage.
      if (state.query.isEmpty && _window.length > _maxWindow) {
        _window.removeRange(0, _pageSize);
        _windowStartOffset += _pageSize;
      }

      final items = _applyFilter(state.query);
      AppLogger.info(_tag,
          'loadMore , raw=${_window.length}, visible=${items.length}, start=$_windowStartOffset, hasMore=${page.hasMore}');
      state = state.copyWith(
        items: items,
        isLoadingMore: false,
        windowStartOffset: _windowStartOffset,
        hasMore: page.hasMore,
        hasPrevious: _windowStartOffset > 0,
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

  /// Fetches the previous page and prepends it to the window.
  /// Drops the trailing page when the window exceeds [_maxWindow].
  /// No-op when search is active, a load is in progress, or at offset 0.
  Future<void> loadPrevious() async {
    if (state.isLoadingPrevious ||
        state.isLoading ||
        !state.hasPrevious ||
        state.query.isNotEmpty) {
      return;
    }

    final prevOffset = _windowStartOffset - _pageSize;
    AppLogger.debug(_tag, 'loadPrevious , offset=$prevOffset');
    state = state.copyWith(isLoadingPrevious: true);
    try {
      final page = await _repository.getPokemonList(
          limit: _pageSize, offset: prevOffset);

      _window.insertAll(0, page.items);
      _windowStartOffset = prevOffset;

      if (_window.length > _maxWindow) {
        _window.removeRange(_maxWindow, _window.length);
      }

      AppLogger.info(_tag,
          'loadPrevious , window=${_window.length} items, start=$_windowStartOffset');
      state = state.copyWith(
        items: List.unmodifiable(_window),
        isLoadingPrevious: false,
        windowStartOffset: _windowStartOffset,
        hasMore: true,
        hasPrevious: _windowStartOffset > 0,
        clearError: true,
      );
    } catch (e, s) {
      AppLogger.error(_tag, 'loadPrevious failed at offset=$prevOffset',
          error: e, stackTrace: s);
      state = state.copyWith(isLoadingPrevious: false, error: _errorMessage(e));
    }
  }

  /// Filters the current window by [query] and updates [state.items].
  ///
  /// When [query] is non-empty, auto-fetches additional pages until at least
  /// [_minSearchResults] matching items are found or no more data exists.
  ///
  /// When [query] is cleared, reloads browse mode from the first page.
  Future<void> search(String query) async {
    AppLogger.debug(_tag, 'search , query: "$query"');
    if (query.isEmpty) {
      await _reloadBrowseFromScratch();
      return;
    }

    state = state.copyWith(
      query: query,
      items: const [],
      isLoading: true,
      isLoadingMore: false,
      isLoadingPrevious: false,
      windowStartOffset: 0,
      hasPrevious: false,
      clearError: true,
    );

    final requestQuery = query;
    try {
      final page =
          await _repository.getPokemonList(limit: _initialPageSize, offset: 0);

      if (!mounted || state.query != requestQuery) return;

      _window
        ..clear()
        ..addAll(page.items);
      _windowStartOffset = 0;

      final filtered = _applyFilter(requestQuery);
      state = state.copyWith(
        items: filtered,
        isLoading: false,
        windowStartOffset: 0,
        hasMore: page.hasMore,
        hasPrevious: false,
        clearError: true,
      );
    } catch (e, s) {
      if (!mounted || state.query != requestQuery) return;
      AppLogger.error(_tag, 'search failed for query="$requestQuery"',
          error: e, stackTrace: s);
      state = state.copyWith(isLoading: false, error: _errorMessage(e));
      return;
    }

    /// Auto-fetch more pages if we don't have enough matching results yet.
    await _autoFetchIfNeeded(requestQuery);
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
    _resetWindow();
    state = PokemonSearchState.initial();
    try {
      final page = await _fetchInitialPage();
      _applyInitialPageToState(page);
      AppLogger.info(_tag, 'init complete , ${_window.length} items loaded');
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

  /// Clears search results and reloads browse mode from offset 0.
  Future<void> _reloadBrowseFromScratch() async {
    state = state.copyWith(
      query: '',
      items: const [],
      isLoading: true,
      isLoadingMore: false,
      isLoadingPrevious: false,
      windowStartOffset: 0,
      hasPrevious: false,
      clearError: true,
    );

    _resetWindow();

    try {
      final page = await _fetchInitialPage();

      if (!mounted || state.query.isNotEmpty) return;

      _applyInitialPageToState(page);
    } catch (e, s) {
      if (!mounted || state.query.isNotEmpty) return;
      AppLogger.error(_tag, 'browse reload failed', error: e, stackTrace: s);
      state = state.copyWith(isLoading: false, error: _errorMessage(e));
    }
  }

  /// Shared first-page fetch used by [init] and browse reload.
  Future<PokemonListPage> _fetchInitialPage() {
    return _repository.getPokemonList(limit: _initialPageSize, offset: 0);
  }

  /// Clears the raw in-memory window and resets its offset.
  void _resetWindow() {
    _window.clear();
    _windowStartOffset = 0;
  }

  /// Applies the freshly fetched first page to browse state.
  void _applyInitialPageToState(PokemonListPage page) {
    _window.addAll(page.items);
    state = state.copyWith(
      items: List.unmodifiable(_window),
      isLoading: false,
      windowStartOffset: 0,
      hasMore: page.hasMore,
      hasPrevious: false,
      clearError: true,
    );
  }

  /// Returns the window filtered by [query], or all items when [query] is empty.
  List<PokemonSummary> _applyFilter(String query) {
    if (query.isEmpty) return List.unmodifiable(_window);
    final lower = query.toLowerCase();
    return _window.where((p) => p.name.contains(lower)).toList();
  }

  /// Translates typed exceptions into short user-facing strings.
  String _errorMessage(Object e) {
    if (e is NetworkException) return 'No internet connection.';
    if (e is ServerException) return 'Server error (${e.statusCode}).';
    if (e is ParseException) return 'Data error , please try again.';
    return 'Something went wrong.';
  }
}
