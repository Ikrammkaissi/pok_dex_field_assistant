/// StateNotifier that manages the in-memory list of bookmarked Pokémon.
///
/// Loads from [GetBookmarks] on construction; persists every mutation via
/// [SetBookmarks].  Both use cases are injected so the notifier depends only
/// on the domain layer — never on SharedPreferences or other data types.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pok_dex_field_assistant/core/logging/app_logger.dart';
import 'package:pok_dex_field_assistant/features/bookmarks/domain/usecases/get_bookmarks.dart';
import 'package:pok_dex_field_assistant/features/bookmarks/domain/usecases/set_bookmarks.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/domain/entities/pokemon_summary.dart';

/// Manages the bookmark list as Riverpod state.
/// State is a plain list ordered by insertion time.
class BookmarkNotifier extends StateNotifier<List<PokemonSummary>> {
  /// Logger tag used for all log lines emitted by this class.
  static const _tag = 'BookmarkNotifier';

  /// Use case that reads the persisted bookmark list from storage.
  final GetBookmarks _getBookmarks;

  /// Use case that writes the full bookmark list to storage.
  final SetBookmarks _setBookmarks;

  /// Initialises with an empty list and immediately triggers [_load] to hydrate
  /// state from the persisted store before the first widget frame.
  BookmarkNotifier(this._getBookmarks, this._setBookmarks) : super([]) {
    AppLogger.debug(_tag, 'init , loading persisted bookmarks');
    _load();
  }

  /// Replaces the in-memory state with the full persisted list.
  Future<void> _load() async {
    state = await _getBookmarks();
    AppLogger.info(_tag, 'loaded ${state.length} bookmarks from repository');
  }

  /// Adds [pokemon] if not already bookmarked; removes it if it is.
  ///
  /// Derives the next state from the current in-memory list (avoids a
  /// read-before-write race), then persists the result via [_setBookmarks]
  /// before updating [state] so storage and memory stay in sync.
  Future<void> toggle(PokemonSummary pokemon) async {
    final bookmarked = state.any((p) => p.name == pokemon.name);
    AppLogger.debug(_tag,
        'toggle "${pokemon.name}" , ${bookmarked ? "removing" : "adding"}');

    /// Build the new list from current state without a round-trip to storage.
    final nextState = bookmarked
        ? state.where((p) => p.name != pokemon.name).toList()
        : [...state, pokemon];

    /// Persist first — if storage fails, state is not updated (consistency).
    await _setBookmarks(nextState);

    state = nextState;
    AppLogger.info(_tag,
        'toggle complete , "${pokemon.name}" ${bookmarked ? "removed" : "added"}, total=${state.length}');
  }

  /// Returns true if a Pokémon named [pokemonName] is in the current list.
  /// O(n) scan — use [isBookmarkedProvider] in widgets for an O(1) derived check.
  bool isBookmarked(String pokemonName) =>
      state.any((p) => p.name == pokemonName);
}
