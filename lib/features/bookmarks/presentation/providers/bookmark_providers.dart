/// Riverpod provider declarations for the bookmarks feature.
/// Dependency graph:
///   sharedPreferencesProvider → bookmarkRepositoryProvider → bookmarkNotifierProvider
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pok_dex_field_assistant/features/bookmarks/data/bookmark_repository.dart';
import 'package:pok_dex_field_assistant/features/bookmarks/presentation/providers/bookmark_notifier.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/data/models/pokemon_models.dart';

/// Holds the [SharedPreferences] instance initialised in [main].
/// Overridden via [ProviderScope] before [runApp] so no async gap at startup.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  /// This provider is always overridden in main.dart — throw if it isn't.
  throw UnimplementedError(
    'sharedPreferencesProvider must be overridden in ProviderScope.',
  );
});

/// Provides the [BookmarkRepository] implementation.
/// Declared as abstract type so tests can inject a fake.
final bookmarkRepositoryProvider = Provider<BookmarkRepository>((ref) {
  return BookmarkRepositoryImpl(ref.watch(sharedPreferencesProvider));
});

/// Provides [BookmarkNotifier] and exposes [List<PokemonSummary>] state.
/// Use [bookmarkNotifierProvider.notifier] to call [toggle].
final bookmarkNotifierProvider =
    StateNotifierProvider<BookmarkNotifier, List<PokemonSummary>>((ref) {
  return BookmarkNotifier(ref.watch(bookmarkRepositoryProvider));
});

/// Derived Set of bookmarked Pokémon names — O(1) containment check.
/// Recomputed only when the bookmark list changes; shared across all callers.
final bookmarkedNamesProvider = Provider<Set<String>>((ref) {
  return ref
      .watch(bookmarkNotifierProvider)
      .map((p) => p.name)
      .toSet();
});

/// Derived provider — true if the named Pokémon is currently bookmarked.
/// Uses [bookmarkedNamesProvider] for O(1) lookup instead of O(n) linear scan.
/// Each family instance rebuilds only when its own bool value changes.
final isBookmarkedProvider = Provider.family<bool, String>((ref, pokemonName) {
  return ref.watch(bookmarkedNamesProvider).contains(pokemonName);
});
