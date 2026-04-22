/// Search screen controller — owns async logic and state transitions.
/// The UI layer reads state from Riverpod and calls methods here; it never
/// talks to the repository directly.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pok_dex_field_assistant/core/error/exceptions.dart';
import 'package:pok_dex_field_assistant/core/logging/app_logger.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/data/models/pokemon_models.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/data/pokemon_repository.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/presentation/providers/pokemon_search_state.dart';

/// Number of Pokémon fetched per page.
const _pageSize = 100;

/// Maximum items kept in memory at once (3 pages).
const _maxWindow = 300;

/// Manages [PokemonSearchState] in response to user interactions.
/// Implements a sliding window: at most [_maxWindow] items are held in memory.
/// Scrolling forward drops the leading page; scrolling back drops the trailing page.
class PokemonSearchController extends StateNotifier<PokemonSearchState> {
  /// Logger tag for this class.
  static const _tag = 'SearchController';

  /// Repository injected by the Riverpod provider — mockable in tests.
  final PokemonRepository _repository;

  /// The current in-memory window of Pokémon (max [_maxWindow] items).
  /// [_window] is the authoritative source; [state.items] mirrors it unless
  /// a search query is active.
  final List<PokemonSummary> _window = [];

  /// API offset of the first item in [_window].
  int _windowStartOffset = 0;

  /// Tracks the in-flight init so concurrent callers share one future.
  /// Cleared after init settles so retry() can start fresh.
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
  /// Called automatically on construction and by [retry].
  /// Concurrent callers share the same in-flight future to prevent double-load.
  Future<void> init() {
    _ongoingInit ??= _doInit().whenComplete(() => _ongoingInit = null);
    return _ongoingInit!;
  }

  /// Fetches the next page and appends it to the window.
  /// Drops the leading page when the window exceeds [_maxWindow].
  /// No-op when: a load is in progress, no more pages ahead, or search is active.
  Future<void> loadMore() async {
    if (state.isLoadingMore ||
        state.isLoading ||
        !state.hasMore ||
        state.query.isNotEmpty) {
      return;
    }

    final nextOffset = _windowStartOffset + _window.length;
    AppLogger.debug(_tag, 'loadMore — offset=$nextOffset');
    state = state.copyWith(isLoadingMore: true);
    try {
      final page = await _repository.getPokemonList(
          limit: _pageSize, offset: nextOffset);

      _window.addAll(page.items);

      /// Drop the leading page if the window would exceed the max.
      if (_window.length > _maxWindow) {
        _window.removeRange(0, _pageSize);
        _windowStartOffset += _pageSize;
      }

      AppLogger.info(_tag,
          'loadMore — window=${_window.length} items, start=$_windowStartOffset, hasMore=${page.hasMore}');
      state = state.copyWith(
        items: List.unmodifiable(_window),
        isLoadingMore: false,
        windowStartOffset: _windowStartOffset,
        hasMore: page.hasMore,
        hasPrevious: _windowStartOffset > 0,
        clearError: true,
      );
    } catch (e, s) {
      AppLogger.error(_tag, 'loadMore failed at offset=$nextOffset',
          error: e, stackTrace: s);
      state = state.copyWith(isLoadingMore: false, error: _errorMessage(e));
    }
  }

  /// Fetches the previous page and prepends it to the window.
  /// Drops the trailing page when the window exceeds [_maxWindow].
  /// No-op when: a load is in progress, no previous pages, or search is active.
  Future<void> loadPrevious() async {
    if (state.isLoadingPrevious ||
        state.isLoading ||
        !state.hasPrevious ||
        state.query.isNotEmpty) {
      return;
    }

    final prevOffset = _windowStartOffset - _pageSize;
    AppLogger.debug(_tag, 'loadPrevious — offset=$prevOffset');
    state = state.copyWith(isLoadingPrevious: true);
    try {
      final page = await _repository.getPokemonList(
          limit: _pageSize, offset: prevOffset);

      /// Prepend and update start offset only after successful fetch.
      _window.insertAll(0, page.items);
      _windowStartOffset = prevOffset;

      /// Drop the trailing page if the window would exceed the max.
      if (_window.length > _maxWindow) {
        _window.removeRange(_maxWindow, _window.length);
      }

      AppLogger.info(_tag,
          'loadPrevious — window=${_window.length} items, start=$_windowStartOffset');
      state = state.copyWith(
        items: List.unmodifiable(_window),
        isLoadingPrevious: false,
        windowStartOffset: _windowStartOffset,
        hasMore: true, // going backward means there is definitely content ahead
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
  /// Filtering is client-side on the window (max [_maxWindow] items).
  /// Restores the full window when [query] is cleared.
  Future<void> search(String query) async {
    AppLogger.debug(_tag, 'search — query: "$query"');
    state = state.copyWith(query: query, clearError: true);
    if (query.isEmpty) {
      state = state.copyWith(items: List.unmodifiable(_window));
      return;
    }
    final lower = query.toLowerCase();
    final filtered = _window.where((p) => p.name.contains(lower)).toList();
    AppLogger.debug(_tag, 'search "$query" → ${filtered.length} result(s)');
    state = state.copyWith(items: List.unmodifiable(filtered));
  }

  /// Resets to the initial state and re-runs [init].
  /// Clears any in-flight init so a fresh load always starts.
  Future<void> retry() {
    AppLogger.info(_tag, 'retry triggered');
    _ongoingInit = null;
    return init();
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  Future<void> _doInit() async {
    AppLogger.debug(_tag, 'init — loading first page (offset=0)');
    _window.clear();
    _windowStartOffset = 0;
    state = PokemonSearchState.initial();
    try {
      final page =
          await _repository.getPokemonList(limit: _pageSize, offset: 0);
      _window.addAll(page.items);
      AppLogger.info(_tag, 'init complete — ${_window.length} items loaded');
      state = state.copyWith(
        items: List.unmodifiable(_window),
        isLoading: false,
        windowStartOffset: 0,
        hasMore: page.hasMore,
        hasPrevious: false,
        clearError: true,
      );
    } catch (e, s) {
      AppLogger.error(_tag, 'init failed', error: e, stackTrace: s);
      state = state.copyWith(isLoading: false, error: _errorMessage(e));
    }
  }

  /// Translates typed exceptions into short user-facing strings.
  String _errorMessage(Object e) {
    if (e is NetworkException) return 'No internet connection.';
    if (e is ServerException) return 'Server error (${e.statusCode}).';
    if (e is ParseException) return 'Data error — please try again.';
    return 'Something went wrong.';
  }
}
