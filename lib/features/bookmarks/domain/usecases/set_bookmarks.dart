/// Use case: persist the full bookmark list.
///
/// Single-responsibility class that wraps [BookmarkRepository.setBookmarks].
/// [BookmarkNotifier] calls this after every toggle so the notifier depends on
/// the domain layer, not the data layer.
import 'package:pok_dex_field_assistant/features/bookmarks/domain/repositories/bookmark_repository.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/data/models/pokemon_models.dart';

/// Encapsulates the "write all bookmarks" operation.
/// Injected via [setBookmarksProvider] so tests can replace it without
/// touching the provider graph.
class SetBookmarks {
  /// Repository that writes to SharedPreferences.
  final BookmarkRepository _repository;

  /// Creates [SetBookmarks] backed by [repository].
  SetBookmarks(this._repository);

  /// Persists [bookmarks] as the authoritative stored list.
  /// Overwrites any previously stored data.
  /// Delegates to [BookmarkRepository.setBookmarks].
  Future<void> call(List<PokemonSummary> bookmarks) =>
      _repository.setBookmarks(bookmarks);
}
