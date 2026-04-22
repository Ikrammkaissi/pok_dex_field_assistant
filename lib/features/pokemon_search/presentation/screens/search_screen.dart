/// Placeholder search screen.
/// Full implementation (search bar, list, states) added in the next phase.
import 'package:flutter/material.dart';

/// Root screen for Pokémon search — currently a placeholder scaffold.
class SearchScreen extends StatelessWidget {
  /// Creates a [SearchScreen].
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    /// Render a centred placeholder message until the real UI is wired up.
    return const Scaffold(
      body: Center(
        child: Text('Search Screen — coming soon'),
      ),
    );
  }
}
