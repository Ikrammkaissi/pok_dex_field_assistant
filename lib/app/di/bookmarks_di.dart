/// Composition root for the bookmarks feature.
///
/// All infrastructure providers (SharedPreferences, repository impl) and
/// domain use-case providers live here — never in presentation or domain layers.
///
/// Dependency graph:
///   sharedPreferencesProvider → bookmarkRepositoryProvider
///   bookmarkRepositoryProvider → getBookmarksProvider, setBookmarksProvider
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pok_dex_field_assistant/features/bookmarks/data/repositories/bookmark_repository_impl.dart';
import 'package:pok_dex_field_assistant/features/bookmarks/domain/repositories/bookmark_repository.dart';
import 'package:pok_dex_field_assistant/features/bookmarks/domain/usecases/get_bookmarks.dart';
import 'package:pok_dex_field_assistant/features/bookmarks/domain/usecases/set_bookmarks.dart';

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
/// Declared as the abstract domain type so tests can inject a fake.
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
