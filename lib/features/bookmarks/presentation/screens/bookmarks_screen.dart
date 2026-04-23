/// Bookmarks screen — shows all saved Pokémon with images.
/// Tapping a row opens the same detail view as the search screen.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pok_dex_field_assistant/features/bookmarks/presentation/providers/bookmark_providers.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/presentation/widgets/pokemon_list_tile.dart';

/// Screen that lists bookmarked Pokémon.
/// Reads [bookmarkNotifierProvider] — rebuilds when the list changes.
class BookmarksScreen extends ConsumerWidget {
  /// Creates a [BookmarksScreen].
  const BookmarksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    /// Watch the full bookmark list — rebuilds on add/remove.
    final bookmarks = ref.watch(bookmarkNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        title: const Text('Saved Pokémon'),
        centerTitle: false,
      ),
      body: bookmarks.isEmpty
          ? const _EmptyState()
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 16),
              itemCount: bookmarks.length,
              /// Reuses PokemonListTile — same look as the search screen.
              itemBuilder: (context, index) =>
                  PokemonListTile(item: bookmarks[index]),
            ),
    );
  }
}

/// Shown when no Pokémon have been bookmarked yet.
class _EmptyState extends StatelessWidget {
  /// Creates an [_EmptyState].
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.bookmark_border,
            size: 72,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'No saved Pokémon yet.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the bookmark icon on any Pokémon to save it.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
