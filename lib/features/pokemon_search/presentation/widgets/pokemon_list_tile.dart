/// A single row in the Pokémon search/bookmarks list.
/// Shows the sprite thumbnail, name, dex number, and a bookmark toggle icon.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pok_dex_field_assistant/app/router.dart';
import 'package:pok_dex_field_assistant/features/bookmarks/presentation/providers/bookmark_providers.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/data/models/pokemon_models.dart';

/// Card row for one [PokemonSummary] with an inline bookmark toggle.
/// Uses [ConsumerWidget] to watch [isBookmarkedProvider] without lifting state.
class PokemonListTile extends ConsumerWidget {
  /// The Pokémon data to display.
  final PokemonSummary item;

  /// Creates a [PokemonListTile] for [item].
  const PokemonListTile({super.key, required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    /// Watch per-pokemon bookmark state — rebuilds only when this entry changes.
    final bookmarked = ref.watch(isBookmarkedProvider(item.name));

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        /// Navigate to the detail screen for this Pokémon.
        /// push preserves the previous screen in the stack so back button works.
        onTap: () => context.push(AppRoutes.detailFor(item.name)),
        /// Sprite thumbnail — fixed 56×56 box; fallback icon on load failure.
        leading: SizedBox(
          width: 56,
          height: 56,
          child: Image.network(
            item.spriteUrl,
            fit: BoxFit.contain,
            /// Show a pokéball placeholder while the image loads.
            loadingBuilder: (context, child, progress) =>
                progress == null ? child : const Icon(Icons.catching_pokemon),
            /// Show a broken-image icon if the URL is empty or fails.
            errorBuilder: (context, error, stack) =>
                const Icon(Icons.broken_image_outlined),
          ),
        ),
        /// Title-cased display name.
        title: Text(
          _displayName(item.name),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        /// Dex number in subdued text.
        subtitle: Text(
          item.primaryType.isEmpty
              ? '#${item.id.toString().padLeft(3, '0')}'
              : '#${item.id.toString().padLeft(3, '0')} • ${_displayType(item.primaryType)}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        /// Bookmark toggle button — filled icon when saved, outline when not.
        trailing: IconButton(
          tooltip: bookmarked ? 'Remove bookmark' : 'Bookmark',
          icon: Icon(
            bookmarked ? Icons.bookmark : Icons.bookmark_border,
            color: bookmarked
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outline,
          ),
          onPressed: () =>
              ref.read(bookmarkNotifierProvider.notifier).toggle(item),
        ),
      ),
    );
  }

  /// Converts a hyphenated API name to a title-cased display name.
  /// e.g. 'mr-mime' → 'Mr Mime', 'bulbasaur' → 'Bulbasaur'.
  String _displayName(String name) => name
      .split('-')
      .map((w) => w.isEmpty ? '' : w[0].toUpperCase() + w.substring(1))
      .join(' ');

  /// Converts a hyphenated type name to title-cased display text.
  String _displayType(String type) => type
      .split('-')
      .map((w) => w.isEmpty ? '' : w[0].toUpperCase() + w.substring(1))
      .join(' ');
}
