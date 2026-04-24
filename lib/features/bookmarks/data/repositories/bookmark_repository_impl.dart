/// Concrete implementation of [BookmarkRepository] backed by [SharedPreferences].
///
/// Lives in the data layer — the only layer allowed to import [SharedPreferences].
/// The domain layer depends on the abstract [BookmarkRepository] interface, not
/// this class, so the storage mechanism can be swapped (e.g. SQLite) without
/// touching use cases or the notifier.
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:pok_dex_field_assistant/core/logging/app_logger.dart';
import 'package:pok_dex_field_assistant/features/bookmarks/domain/repositories/bookmark_repository.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/data/models/pokemon_models.dart';

/// Implements [BookmarkRepository] using SharedPreferences JSON serialisation.
/// Bookmarks are stored as a `List<String>` of JSON-encoded [PokemonSummary]
/// objects under [_key].
class BookmarkRepositoryImpl implements BookmarkRepository {
  /// Logger tag used for all log lines emitted by this class.
  static const _tag = 'BookmarkRepository';

  /// SharedPreferences key that holds the bookmark list.
  static const _key = 'pokemon_bookmarks';

  /// The injected SharedPreferences instance, supplied at startup from main.dart.
  final SharedPreferences _prefs;

  /// Creates a [BookmarkRepositoryImpl] backed by [prefs].
  const BookmarkRepositoryImpl(this._prefs);

  /// Reads the raw JSON string list from SharedPreferences and deserialises
  /// each entry into a [PokemonSummary]. Returns an empty list if the key is absent.
  @override
  Future<List<PokemonSummary>> getBookmarks() async {
    /// Read the stored string list; default to empty when key is absent.
    final raw = _prefs.getStringList(_key) ?? [];
    AppLogger.debug(_tag, 'getBookmarks , ${raw.length} entries in prefs');
    final result = raw.map((s) {
      /// Decode each JSON string back to a map, then parse the summary.
      final json = jsonDecode(s) as Map<String, dynamic>;
      return PokemonSummary.fromBookmarkJson(json);
    }).toList();
    AppLogger.info(_tag, 'Loaded ${result.length} bookmarks');
    return result;
  }

  /// Serialises [bookmarks] and writes them to SharedPreferences in one call.
  /// Replaces the entire stored list — callers are responsible for providing
  /// the complete authoritative state.
  @override
  Future<void> setBookmarks(List<PokemonSummary> bookmarks) async {
    AppLogger.debug(
        _tag, 'setBookmarks , persisting ${bookmarks.length} entries');
    await _persist(bookmarks);
  }

  /// Adds [pokemon] to the persisted list if it is not already present.
  /// Deduplicates by [PokemonSummary.name] — the stable identifier.
  @override
  Future<void> addBookmark(PokemonSummary pokemon) async {
    final current = await getBookmarks();
    /// Skip if already present — name is the stable bookmark identifier.
    if (current.any((p) => p.name == pokemon.name)) {
      AppLogger.debug(_tag,
          'addBookmark , "${pokemon.name}" already bookmarked, skipping');
      return;
    }
    current.add(pokemon);
    await _persist(current);
    AppLogger.info(
        _tag, 'addBookmark , added "${pokemon.name}", total=${current.length}');
  }

  /// Removes the entry matching [pokemonName] from the persisted list.
  /// No-op (with a warning log) if the name is not found.
  @override
  Future<void> removeBookmark(String pokemonName) async {
    final current = await getBookmarks();
    final before = current.length;
    current.removeWhere((p) => p.name == pokemonName);
    if (current.length == before) {
      AppLogger.warning(
          _tag, 'removeBookmark , "$pokemonName" not found, no-op');
    } else {
      AppLogger.info(_tag,
          'removeBookmark , removed "$pokemonName", total=${current.length}');
    }
    await _persist(current);
  }

  /// Serialises [bookmarks] to JSON strings and writes them to SharedPreferences.
  /// Called by both [setBookmarks], [addBookmark], and [removeBookmark].
  Future<void> _persist(List<PokemonSummary> bookmarks) async {
    /// Encode each summary to a JSON string for flat string-list storage.
    final encoded = bookmarks.map((p) => jsonEncode(p.toJson())).toList();
    await _prefs.setStringList(_key, encoded);
    AppLogger.debug(
        _tag, '_persist , wrote ${encoded.length} entries to prefs');
  }
}
