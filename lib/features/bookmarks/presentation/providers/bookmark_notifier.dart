/// StateNotifier that manages the in-memory list of bookmarked Pokémon.
/// Loads from [BookmarkRepository] on construction; persists every mutation.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pok_dex_field_assistant/core/logging/app_logger.dart';
import 'package:pok_dex_field_assistant/features/bookmarks/data/bookmark_repository.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/data/models/pokemon_models.dart';

/// Manages the bookmark list as Riverpod state.
/// State is a plain list — ordered by insertion time.
class BookmarkNotifier extends StateNotifier<List<PokemonSummary>> {
  /// Logger tag for this class.
  static const _tag = 'BookmarkNotifier';

  /// Repository that handles persistence.
  final BookmarkRepository _repository;

  /// Initialises with empty state and immediately loads persisted bookmarks.
  BookmarkNotifier(this._repository) : super([]) {
    AppLogger.debug(_tag, 'init — loading persisted bookmarks');
    _load();
  }

  /// Replaces state with the persisted bookmark list.
  Future<void> _load() async {
    state = await _repository.getBookmarks();
    AppLogger.info(_tag, 'loaded ${state.length} bookmarks from repository');
  }

  /// Adds [pokemon] if not already bookmarked; removes it if it is.
  Future<void> toggle(PokemonSummary pokemon) async {
    final bookmarked = state.any((p) => p.name == pokemon.name);
    AppLogger.debug(_tag,
        'toggle "${pokemon.name}" — ${bookmarked ? "removing" : "adding"}');
    final nextState = bookmarked
        ? state.where((p) => p.name != pokemon.name).toList()
        : [...state, pokemon];

    /// Persist authoritative in-memory state directly to avoid read-before-write.
    await _repository.setBookmarks(nextState);

    state = nextState;
    AppLogger.info(_tag,
        'toggle complete — "${pokemon.name}" ${bookmarked ? "removed" : "added"}, total=${state.length}');
  }

  /// Returns true if [pokemonName] is in the current bookmark list.
  bool isBookmarked(String pokemonName) =>
      state.any((p) => p.name == pokemonName);
}
