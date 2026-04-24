/// Domain contract for bookmark persistence.
///
/// Lives in the domain layer so use cases and the notifier depend on this
/// abstraction, not on the SharedPreferences implementation.
/// Swap [BookmarkRepositoryImpl] for a fake in tests via Riverpod overrides.
///
/// Imports only domain entities — zero data-layer or framework dependencies.
import 'package:pok_dex_field_assistant/features/pokemon_search/domain/entities/pokemon_summary.dart';

/// Interface that defines how bookmarks are read and written.
/// Concrete implementations (e.g. [BookmarkRepositoryImpl]) live in the data layer.
abstract class BookmarkRepository {
  /// Returns all bookmarked Pokémon in insertion order.
  Future<List<PokemonSummary>> getBookmarks();

  /// Persists the full bookmark list in one atomic write.
  /// Replaces whatever was stored previously.
  Future<void> setBookmarks(List<PokemonSummary> bookmarks);

  /// Appends [pokemon] to the stored list; no-op if already bookmarked by name.
  Future<void> addBookmark(PokemonSummary pokemon);

  /// Removes the bookmark matching [pokemonName]; no-op if not present.
  Future<void> removeBookmark(String pokemonName);
}
