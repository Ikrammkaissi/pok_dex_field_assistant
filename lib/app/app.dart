/// Root widget for the Pokédex Field Assistant app.
/// Wires [appTheme] and [appRouter] into a [MaterialApp.router].
import 'package:flutter/material.dart';
import 'package:pok_dex_field_assistant/app/router.dart';
import 'package:pok_dex_field_assistant/app/theme.dart';

/// Top-level app widget — stateless, holds no business logic.
class App extends StatelessWidget {
  /// Creates an [App] widget.
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    /// Use [MaterialApp.router] so go_router controls navigation.
    return MaterialApp.router(
      /// Displayed in the OS task switcher.
      title: 'Pokédex Field Assistant',
      /// Material 3 theme with Pokéball-red seed colour.
      theme: appTheme,
      /// Delegate routing to the [appRouter] go_router instance.
      routerConfig: appRouter,
    );
  }
}
