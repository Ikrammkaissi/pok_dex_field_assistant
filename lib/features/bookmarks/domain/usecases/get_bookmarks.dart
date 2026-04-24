/// Use case: load the persisted bookmark list.
///
/// Single-responsibility class that wraps [BookmarkRepository.getBookmarks].
/// [BookmarkNotifier] calls this on construction so the notifier depends on
/// the domain layer, not the data layer.
import 'package:pok_dex_field_assistant/features/bookmarks/domain/repositories/bookmark_repository.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/domain/entities/pokemon_summary.dart';

/// Encapsulates the "read all bookmarks" operation.
/// Injected via [getBookmarksProvider] so tests can replace it without
/// touching the provider graph.
class GetBookmarks {
  /// Repository that reads from SharedPreferences.
  final BookmarkRepository _repository;

  /// Creates [GetBookmarks] backed by [repository].
  GetBookmarks(this._repository);

  /// Returns all bookmarked [PokemonSummary] items in insertion order.
  /// Delegates to [BookmarkRepository.getBookmarks].
  Future<List<PokemonSummary>> call() => _repository.getBookmarks();
}
