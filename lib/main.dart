/// App entry point.
/// Initialises [SharedPreferences] before [runApp] so the bookmark provider
/// has a synchronous value , no loading gap at startup.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pok_dex_field_assistant/app/app.dart';
import 'package:pok_dex_field_assistant/core/logging/app_logger.dart';
import 'package:pok_dex_field_assistant/app/di/bookmarks_di.dart';

/// Starts the Flutter app with SharedPreferences injected into [ProviderScope].
void main() async {
  /// Required before any plugin (SharedPreferences) call in main.
  WidgetsFlutterBinding.ensureInitialized();
  AppLogger.info('App', 'startup , initialising SharedPreferences');

  /// Fetch the platform prefs instance once; pass it to the provider tree.
  final prefs = await SharedPreferences.getInstance();
  AppLogger.info('App', 'SharedPreferences ready , launching app');

  runApp(
    ProviderScope(
      overrides: [
        /// Supply the real SharedPreferences instance to all bookmark providers.
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const App(),
    ),
  );
}
