/// Declarative route table for the app.
/// All routes are defined here — widgets never reference path strings directly.
import 'package:go_router/go_router.dart';
import 'package:pok_dex_field_assistant/features/bookmarks/presentation/screens/bookmarks_screen.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/presentation/screens/detail_screen.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/presentation/screens/search_screen.dart';

/// Route path constants — prevents magic strings in widgets.
class AppRoutes {
  /// Path for the Pokémon search screen (app root).
  static const String search = '/';

  /// Path pattern for the Pokémon detail screen.
  /// Use [detailFor] to build a concrete path.
  static const String detail = '/pokemon/:name';

  /// Path for the saved/bookmarked Pokémon screen.
  static const String bookmarks = '/bookmarks';

  /// Returns the concrete detail path for [pokemonName].
  static String detailFor(String pokemonName) => '/pokemon/$pokemonName';
}

/// App-level [GoRouter] instance wired into [App].
/// [initialLocation] is [AppRoutes.search] so the search screen loads first.
final appRouter = GoRouter(
  /// Start at the search screen.
  initialLocation: AppRoutes.search,
  routes: [
    /// Search screen — root of the app.
    GoRoute(
      path: AppRoutes.search,
      /// Builder returns the search screen widget.
      builder: (context, state) => const SearchScreen(),
    ),

    /// Detail screen — navigated to when a list tile is tapped.
    GoRoute(
      path: AppRoutes.detail,
      /// Extract the :name path parameter and pass it to the screen.
      builder: (context, state) => DetailScreen(
        pokemonName: state.pathParameters['name']!,
      ),
    ),

    /// Bookmarks screen — shows saved Pokémon.
    GoRoute(
      path: AppRoutes.bookmarks,
      builder: (context, state) => const BookmarksScreen(),
    ),
  ],
);
