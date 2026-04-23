/// Full Pokémon search screen.
/// Displays a search bar, loading spinner, error state with retry,
/// empty state, and a windowed list (max 300 items) that loads more on scroll
/// in both directions and discards out-of-window pages.
/// All data logic lives in [PokemonSearchController]; this file is pure UI.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pok_dex_field_assistant/app/router.dart';

import 'package:pok_dex_field_assistant/features/bookmarks/presentation/providers/bookmark_providers.dart';

import 'package:pok_dex_field_assistant/features/pokemon_search/presentation/providers/pokemon_providers.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/presentation/providers/pokemon_search_state.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/presentation/widgets/pokemon_list_tile.dart';

/// Stable widget keys for [SearchScreen] — used in widget tests.
class SearchScreenKeys {
  static const searchBar = Key('search_bar');
  static const pokemonList = Key('search_pokemon_list');
  static const emptyView = Key('search_empty_view');
  static const errorView = Key('search_error_view');
  static const retryButton = Key('search_retry_button');
}

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

  /// Debounce timer — cancelled and restarted on every keystroke so the
  /// controller's search() is only called 300ms after the user stops typing.
  /// Without this, each character fires getPokemonList(limit:100) which spawns
  /// up to 100 concurrent detail requests per keystroke.
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _scrollController = ScrollController()..addListener(_onScroll);
  }

  /// Triggers forward or backward page loads based on scroll proximity to
  /// the list edges.
  ///
  /// Uses a threshold of 80px rather than exact `== 0` comparison because
  /// Flutter's scroll physics produce fractional pixel extents that may never
  /// equal exactly zero, silently preventing pagination from triggering.
  /// [loadMore] and [loadPrevious] are both no-ops while a load is in flight
  /// so multiple triggers during a slow deceleration are safe.
  void _onScroll() {
    final pos = _scrollController.position;
    final controller =
        ref.read(pokemonSearchControllerProvider.notifier);

    /// Within 80px of the bottom edge → load next page.
    if (pos.extentAfter < 80) {
      controller.loadMore();
    }

    /// Within 80px of the top edge → load previous page.
    if (pos.extentBefore < 80) {
      controller.loadPrevious();
    }
  }

  /// Debounces search input — cancels pending timer and starts a new 300ms one.
  /// Only calls controller.search() after the user stops typing for 300ms,
  /// preventing up to 100 concurrent HTTP requests per keystroke.
  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      ref.read(pokemonSearchControllerProvider.notifier).search(query);
    });
  }

  @override
  void dispose() {
    /// Cancel any pending debounce timer to avoid calling search() after unmount.
    _searchDebounce?.cancel();
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
        actions: [

          /// Navigates to the weather suggestion screen.
          IconButton(
            icon: const Icon(Icons.wb_sunny_outlined),
            tooltip: 'Suggest Pokémon by Weather',
            onPressed: () => context.push(AppRoutes.weather),
          ),

          /// Shows saved count badge when bookmarks exist; navigates to bookmarks screen.
          _BookmarkNavButton(),

        ],
      ),
      body: Column(
        children: [
          _SearchBar(
            controller: _searchController,
            /// Use debounced handler — prevents N concurrent requests per keystroke.
            onChanged: _onSearchChanged,
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

  const _SearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: TextField(
        key: SearchScreenKeys.searchBar,
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
    super.key,
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
      key: SearchScreenKeys.pokemonList,
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

  const _ErrorView({
    super.key,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      key: SearchScreenKeys.errorView,
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
              key: SearchScreenKeys.retryButton,
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

/// AppBar action that navigates to [BookmarksScreen].
/// Shows a count badge when at least one Pokémon is bookmarked.
class _BookmarkNavButton extends ConsumerWidget {
  /// Creates a [_BookmarkNavButton].
  const _BookmarkNavButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    /// Watch bookmark count — rebuilds only when the list length changes.
    final count = ref.watch(bookmarkNotifierProvider).length;

    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          tooltip: 'Saved Pokémon',
          icon: const Icon(Icons.bookmark_outlined),
          onPressed: () => context.push(AppRoutes.bookmarks),
        ),
        /// Badge showing how many Pokémon are saved; hidden when count is 0.
        if (count > 0)
          Positioned(
            top: 8,
            right: 8,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.error,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onError,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Full-screen empty state shown when a search returns no results.
class _EmptyView extends StatelessWidget {
  final String query;

  const _EmptyView({super.key, required this.query});

  @override
  Widget build(BuildContext context) {
    final message = query.isEmpty
        ? 'No Pokémon found.'
        : 'No results for "$query".';

    return Center(
      key: SearchScreenKeys.emptyView,
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
