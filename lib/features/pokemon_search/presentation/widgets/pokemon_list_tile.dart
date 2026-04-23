/// A single row in the Pokémon search list.
/// Shows the sprite thumbnail, name, and dex number.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pok_dex_field_assistant/app/router.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/data/models/pokemon_models.dart';

/// Stateless card row for one [PokemonSummary].
/// Pure UI — no state, no providers.
class PokemonListTile extends StatelessWidget {
  /// The Pokémon data to display.
  final PokemonSummary item;

  /// Creates a [PokemonListTile] for [item].
  const PokemonListTile({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        /// Navigate to the detail screen for this Pokémon.
        onTap: () => context.go(AppRoutes.detailFor(item.name)),
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
          '#${item.id.toString().padLeft(3, '0')}',
          style: Theme.of(context).textTheme.bodySmall,
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
}
