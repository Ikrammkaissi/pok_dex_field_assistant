/// Full Pokémon search screen.
/// Displays a search bar, loading spinner, error state with retry,
/// empty state, and a windowed list (max 300 items) that loads more on scroll
/// in both directions and discards out-of-window pages.
/// All data logic lives in [PokemonSearchController]; this file is pure UI.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/presentation/providers/pokemon_providers.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/presentation/providers/pokemon_search_state.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/presentation/widgets/pokemon_list_tile.dart';

/// Root search screen widget — reads [pokemonSearchControllerProvider].
/// Uses [ConsumerStatefulWidget] to manage the [TextEditingController] and
/// [ScrollController] lifecycles.
class SearchScreen extends ConsumerStatefulWidget {
  /// Creates a [SearchScreen].
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  /// Controls the search text field value and cursor.
  late final TextEditingController _searchController;

  /// Attached to the list to detect scroll position for pagination.
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _scrollController = ScrollController()..addListener(_onScroll);
  }

  /// Triggers forward or backward page loads based on scroll proximity to
  /// the list edges.
  void _onScroll() {
    final pos = _scrollController.position;
    final controller =
        ref.read(pokemonSearchControllerProvider.notifier);

    /// Exact bottom edge -> load next page.
    if (pos.extentAfter == 0) {
      controller.loadMore();
    }

    /// Exact top edge -> load previous page.
    if (pos.extentBefore == 0) {
      controller.loadPrevious();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pokemonSearchControllerProvider);
    final controller = ref.read(pokemonSearchControllerProvider.notifier);

    /// When the window slides forward (top items dropped), jump scroll up so
    /// extentAfter > 0 and _onScroll doesn't immediately re-trigger loadMore.
    /// When the window slides backward (bottom items dropped), jump scroll down
    /// so extentBefore > 0 and _onScroll doesn't immediately re-trigger loadPrevious.
    ref.listen<int>(
      pokemonSearchControllerProvider.select((s) => s.windowStartOffset),
      (prev, next) {
        if (prev == null || next == prev) return;
        if (!_scrollController.hasClients) return;
        final pos = _scrollController.position;
        final itemCount = ref.read(pokemonSearchControllerProvider).items.length;
        if (itemCount == 0 || pos.maxScrollExtent <= 0) return;
        final estimatedItemHeight = pos.maxScrollExtent / itemCount;
        final delta = (next - prev).abs();
        final newOffset = next > prev
            // Slid forward: items dropped from top → jump up.
            ? (pos.pixels - delta * estimatedItemHeight).clamp(
                0.0, pos.maxScrollExtent)
            // Slid backward: items dropped from bottom → jump down.
            : (pos.pixels + delta * estimatedItemHeight).clamp(
                0.0, pos.maxScrollExtent);
        _scrollController.jumpTo(newOffset);
      },
    );

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        title: const Text('Pokédex'),
        centerTitle: false,
      ),
      body: Column(
        children: [
          _SearchBar(
            controller: _searchController,
            onChanged: controller.search,
          ),
          Expanded(
            child: _Content(
              state: state,
              scrollController: _scrollController,
              onRetry: controller.retry,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Private sub-widgets
// ---------------------------------------------------------------------------

/// Search input field with a clear button.
class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _SearchBar({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: 'Search Pokémon…',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (_, value, __) => value.text.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    icon: const Icon(Icons.clear),
                    tooltip: 'Clear search',
                    onPressed: () {
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

/// Switches between loading, error, empty, and the windowed list.
class _Content extends StatelessWidget {
  final PokemonSearchState state;
  final ScrollController scrollController;
  final VoidCallback onRetry;

  const _Content({
    required this.state,
    required this.scrollController,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null) {
      return _ErrorView(message: state.error!, onRetry: onRetry);
    }

    if (state.items.isEmpty) {
      return _EmptyView(query: state.query);
    }

    /// Sentinel slots at index 0 (previous spinner) and end (next spinner).
    final topSlot = state.isLoadingPrevious ? 1 : 0;
    final bottomSlot = state.isLoadingMore ? 1 : 0;
    final total = topSlot + state.items.length + bottomSlot;

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: total,
      itemBuilder: (context, index) {
        /// Top spinner while fetching the previous page.
        if (state.isLoadingPrevious && index == 0) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final itemIndex = index - topSlot;

        /// Bottom spinner while fetching the next page.
        if (itemIndex >= state.items.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        return PokemonListTile(item: state.items[itemIndex]);
      },
    );
  }
}

/// Full-screen error message with a Retry button.
class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

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
  final String query;

  const _EmptyView({required this.query});

  @override
  Widget build(BuildContext context) {
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
