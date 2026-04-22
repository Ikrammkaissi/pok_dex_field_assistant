/// Full Pokémon search screen.
/// Displays a search bar, loading spinner, error state with retry,
/// empty state, and a list of results.
/// All data logic lives in [PokemonSearchController]; this file is pure UI.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/presentation/providers/pokemon_providers.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/presentation/providers/pokemon_search_state.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/presentation/widgets/pokemon_list_tile.dart';

/// Root search screen widget — reads [pokemonSearchControllerProvider].
/// Uses [ConsumerStatefulWidget] to manage the [TextEditingController] lifecycle.
class SearchScreen extends ConsumerStatefulWidget {
  /// Creates a [SearchScreen].
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

/// State for [SearchScreen] — owns the [TextEditingController] and
/// forwards text changes to [PokemonSearchController].
class _SearchScreenState extends ConsumerState<SearchScreen> {
  /// Controls the search text field value and cursor.
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    /// Create the controller here so it is tied to this widget's lifecycle.
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    /// Always dispose to prevent memory leaks.
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    /// Watch causes the widget to rebuild whenever state changes.
    final state = ref.watch(pokemonSearchControllerProvider);
    /// Read (not watch) the notifier so callbacks don't trigger extra rebuilds.
    final controller = ref.read(pokemonSearchControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        /// Pokéball-red background from the seeded theme.
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        title: const Text('Pokédex'),
        centerTitle: false,
      ),
      body: Column(
        children: [
          /// Search bar section.
          _SearchBar(
            controller: _searchController,
            onChanged: controller.search,
          ),
          /// Content section fills remaining vertical space.
          Expanded(child: _Content(state: state, onRetry: controller.retry)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Private sub-widgets — split out to keep build() readable.
// ---------------------------------------------------------------------------

/// Search input field with a clear button.
class _SearchBar extends StatelessWidget {
  /// Controls the text field value.
  final TextEditingController controller;

  /// Called with the new query string on every keystroke.
  final ValueChanged<String> onChanged;

  /// Creates a [_SearchBar].
  const _SearchBar({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: TextField(
        controller: controller,
        /// Fire [onChanged] on every character change.
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: 'Search Pokémon…',
          prefixIcon: const Icon(Icons.search),
          /// Show a clear button only when there is text.
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (_, value, __) => value.text.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    icon: const Icon(Icons.clear),
                    tooltip: 'Clear search',
                    onPressed: () {
                      /// Clear text field and reset the search results.
                      controller.clear();
                      onChanged('');
                    },
                  ),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }
}

/// Switches between loading, error, empty, and list based on [state].
class _Content extends StatelessWidget {
  /// Current search state.
  final PokemonSearchState state;

  /// Called when the user taps Retry in the error view.
  final VoidCallback onRetry;

  /// Creates a [_Content] widget.
  const _Content({required this.state, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    /// Show spinner while loading.
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    /// Show error message with retry button.
    if (state.error != null) {
      return _ErrorView(message: state.error!, onRetry: onRetry);
    }

    /// Show empty state when search returns no results.
    if (state.items.isEmpty) {
      return _EmptyView(query: state.query);
    }

    /// Show the list of Pokémon tiles.
    return ListView.builder(
      /// Add bottom padding so the last item isn't hidden behind system nav.
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: state.items.length,
      itemBuilder: (context, index) =>
          PokemonListTile(item: state.items[index]),
    );
  }
}

/// Full-screen error message with a Retry button.
class _ErrorView extends StatelessWidget {
  /// User-facing error description.
  final String message;

  /// Called when the user taps the Retry button.
  final VoidCallback onRetry;

  /// Creates an [_ErrorView].
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-screen empty state shown when a search returns no results.
class _EmptyView extends StatelessWidget {
  /// The query that produced no results — shown in the message.
  final String query;

  /// Creates an [_EmptyView].
  const _EmptyView({required this.query});

  @override
  Widget build(BuildContext context) {
    /// Personalise the message when a specific query was entered.
    final message = query.isEmpty
        ? 'No Pokémon found.'
        : 'No results for "$query".';

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.search_off, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(message, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }
}
