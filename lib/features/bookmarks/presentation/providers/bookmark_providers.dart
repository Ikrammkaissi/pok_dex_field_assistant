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

/// Derived provider — true if the named Pokémon is currently bookmarked.
/// Rebuilds only when the bookmark list changes, keeping callers efficient.
final isBookmarkedProvider = Provider.family<bool, String>((ref, pokemonName) {
  final bookmarks = ref.watch(bookmarkNotifierProvider);
  return bookmarks.any((p) => p.name == pokemonName);
});
