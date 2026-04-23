/// Bookmark persistence layer.
/// [BookmarkRepository] defines the contract; [BookmarkRepositoryImpl]
/// stores bookmarks as a JSON list in [SharedPreferences].
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:pok_dex_field_assistant/core/logging/app_logger.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/data/models/pokemon_models.dart';

/// Contract for reading and writing persisted bookmarks.
abstract class BookmarkRepository {
  /// Returns all bookmarked Pokémon in insertion order.
  Future<List<PokemonSummary>> getBookmarks();

  /// Persists the full bookmark list in one write operation.
  Future<void> setBookmarks(List<PokemonSummary> bookmarks);

  /// Persists [pokemon] as a bookmark; no-op if already bookmarked.
  Future<void> addBookmark(PokemonSummary pokemon);

  /// Removes the bookmark for [pokemonName]; no-op if not bookmarked.
  Future<void> removeBookmark(String pokemonName);
}

/// [SharedPreferences]-backed implementation.
/// Bookmarks are stored as a JSON string list under [_key].
class BookmarkRepositoryImpl implements BookmarkRepository {
  /// Logger tag for this class.
  static const _tag = 'BookmarkRepository';

  /// SharedPreferences key used for the stored list.
  static const _key = 'pokemon_bookmarks';

  /// The injected prefs instance — supplied from main.dart at startup.
  final SharedPreferences _prefs;

  /// Creates a [BookmarkRepositoryImpl] backed by [prefs].
  const BookmarkRepositoryImpl(this._prefs);

  @override
  Future<List<PokemonSummary>> getBookmarks() async {
    /// Read raw JSON strings; return empty list if key is absent.
    final raw = _prefs.getStringList(_key) ?? [];
    AppLogger.debug(_tag, 'getBookmarks — ${raw.length} entries in prefs');
    final result = raw.map((s) {
      /// Decode each stored JSON string back to a PokemonSummary.
      final json = jsonDecode(s) as Map<String, dynamic>;
      return PokemonSummary.fromBookmarkJson(json);
    }).toList();
    AppLogger.info(_tag, 'Loaded ${result.length} bookmarks');
    return result;
  }

  @override
  Future<void> setBookmarks(List<PokemonSummary> bookmarks) async {
    AppLogger.debug(_tag, 'setBookmarks — persisting ${bookmarks.length} entries');
    await _persist(bookmarks);
  }

  @override
  Future<void> addBookmark(PokemonSummary pokemon) async {
    final current = await getBookmarks();
    /// Skip if already present — name is the stable identifier.
    if (current.any((p) => p.name == pokemon.name)) {
      AppLogger.debug(_tag, 'addBookmark — "${pokemon.name}" already bookmarked, skipping');
      return;
    }
    current.add(pokemon);
    await _persist(current);
    AppLogger.info(_tag, 'addBookmark — added "${pokemon.name}", total=${current.length}');
  }

  @override
  Future<void> removeBookmark(String pokemonName) async {
    final current = await getBookmarks();
    final before = current.length;
    current.removeWhere((p) => p.name == pokemonName);
    if (current.length == before) {
      AppLogger.warning(_tag, 'removeBookmark — "$pokemonName" not found, no-op');
    } else {
      AppLogger.info(_tag, 'removeBookmark — removed "$pokemonName", total=${current.length}');
    }
    await _persist(current);
  }

  /// Serialises [bookmarks] and writes them to SharedPreferences.
  Future<void> _persist(List<PokemonSummary> bookmarks) async {
    final encoded = bookmarks.map((p) => jsonEncode(p.toJson())).toList();
    await _prefs.setStringList(_key, encoded);
    AppLogger.debug(_tag, '_persist — wrote ${encoded.length} entries to prefs');
  }
}
