/// Declarative route table for the app.
/// All routes are defined here — widgets never reference path strings directly.
import 'package:go_router/go_router.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/presentation/screens/search_screen.dart';

/// Route path constants — prevents magic strings in widgets.
class AppRoutes {
  /// Path for the Pokémon search screen (app root).
  static const String search = '/';
}

/// App-level [GoRouter] instance wired into [App].
/// [initialLocation] is [AppRoutes.search] so the search screen loads first.
final appRouter = GoRouter(
  /// Start at the search screen.
  initialLocation: AppRoutes.search,
  routes: [
    /// Search screen — the only route in phase 1.
    GoRoute(
      path: AppRoutes.search,
      /// Builder returns the search screen widget.
      builder: (context, state) => const SearchScreen(),
    ),
  ],
);
