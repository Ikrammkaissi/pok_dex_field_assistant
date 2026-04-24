/// Presentation-layer provider declarations for the bookmarks feature.
///
/// Infrastructure providers (SharedPreferences, repository, use cases) live in
/// [lib/app/di/bookmarks_di.dart] — this file only wires the notifier and
/// derived lookup providers.
///
/// Dependency graph (left → right = depends on):
///   (app/di) getBookmarksProvider + setBookmarksProvider → bookmarkNotifierProvider
///   bookmarkNotifierProvider → bookmarkedNamesProvider → isBookmarkedProvider
export 'package:pok_dex_field_assistant/app/di/bookmarks_di.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pok_dex_field_assistant/app/di/bookmarks_di.dart';
import 'package:pok_dex_field_assistant/features/bookmarks/presentation/providers/bookmark_notifier.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/domain/entities/pokemon_summary.dart';

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
  return ref.watch(bookmarkNotifierProvider).map((p) => p.name).toSet();
});

/// Derived family provider — true if the named Pokémon is currently bookmarked.
/// Uses [bookmarkedNamesProvider] for O(1) lookup instead of an O(n) linear scan.
/// Each family instance rebuilds only when its own bool value changes, preventing
/// full-list rebuilds when an unrelated Pokémon is toggled.
final isBookmarkedProvider = Provider.family<bool, String>((ref, pokemonName) {
  return ref.watch(bookmarkedNamesProvider).contains(pokemonName);
});
