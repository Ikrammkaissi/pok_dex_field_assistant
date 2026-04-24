/// Riverpod provider declarations for the bookmarks feature.
///
/// Dependency graph (left → right = depends on):
///   sharedPreferencesProvider → bookmarkRepositoryProvider
///   bookmarkRepositoryProvider → getBookmarksProvider, setBookmarksProvider
///   getBookmarksProvider + setBookmarksProvider → bookmarkNotifierProvider
///   bookmarkNotifierProvider → bookmarkedNamesProvider → isBookmarkedProvider
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pok_dex_field_assistant/features/bookmarks/data/repositories/bookmark_repository_impl.dart';
import 'package:pok_dex_field_assistant/features/bookmarks/domain/repositories/bookmark_repository.dart';
import 'package:pok_dex_field_assistant/features/bookmarks/domain/usecases/get_bookmarks.dart';
import 'package:pok_dex_field_assistant/features/bookmarks/domain/usecases/set_bookmarks.dart';
import 'package:pok_dex_field_assistant/features/bookmarks/presentation/providers/bookmark_notifier.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/data/models/pokemon_models.dart';

/// Holds the [SharedPreferences] instance initialised synchronously in [main].
/// Always overridden before [runApp] so there is no async gap at startup.
/// Throws [UnimplementedError] if accessed without an override — prevents
/// silent failures in tests that forget to provide it.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'sharedPreferencesProvider must be overridden in ProviderScope.',
  );
});

/// Provides the [BookmarkRepository] implementation.
/// Declared as the abstract type so tests can inject a fake.
final bookmarkRepositoryProvider = Provider<BookmarkRepository>((ref) {
  /// Wire the pre-initialised SharedPreferences instance into the impl.
  return BookmarkRepositoryImpl(ref.watch(sharedPreferencesProvider));
});

/// Provides the [GetBookmarks] use case.
/// [BookmarkNotifier] calls this on construction to hydrate its state from storage.
final getBookmarksProvider = Provider<GetBookmarks>((ref) {
  return GetBookmarks(ref.watch(bookmarkRepositoryProvider));
});

/// Provides the [SetBookmarks] use case.
/// [BookmarkNotifier] calls this after every toggle to persist the full list.
final setBookmarksProvider = Provider<SetBookmarks>((ref) {
  return SetBookmarks(ref.watch(bookmarkRepositoryProvider));
});

/// Provides [BookmarkNotifier] and exposes [List<PokemonSummary>] state.
/// Use [bookmarkNotifierProvider.notifier] to call [BookmarkNotifier.toggle].
final bookmarkNotifierProvider =
    StateNotifierProvider<BookmarkNotifier, List<PokemonSummary>>((ref) {
  /// Inject both use cases so the notifier never imports data-layer types.
  return BookmarkNotifier(
    ref.watch(getBookmarksProvider),
    ref.watch(setBookmarksProvider),
  );
});

/// Derived provider — a [Set] of bookmarked Pokémon names for O(1) lookup.
/// Recomputed only when the notifier's list changes; shared across all callers.
final bookmarkedNamesProvider = Provider<Set<String>>((ref) {
  return ref
      .watch(bookmarkNotifierProvider)
      .map((p) => p.name)
      .toSet();
});

/// Derived family provider — true if the named Pokémon is currently bookmarked.
/// Uses [bookmarkedNamesProvider] for O(1) lookup instead of an O(n) linear scan.
/// Each family instance rebuilds only when its own bool value changes, preventing
/// full-list rebuilds when an unrelated Pokémon is toggled.
final isBookmarkedProvider = Provider.family<bool, String>((ref, pokemonName) {
  return ref.watch(bookmarkedNamesProvider).contains(pokemonName);
});
