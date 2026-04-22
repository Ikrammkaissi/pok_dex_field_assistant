/// App-wide Material 3 theme.
/// Pokéball red (0xFFCC0000) as the seed colour so the colour scheme
/// derives complementary tones automatically.
import 'package:flutter/material.dart';

/// Shared theme data used by [App].
final appTheme = ThemeData(
  /// Enable Material 3 component styles and colour system.
  useMaterial3: true,
  /// Derive the full colour scheme from a single seed colour.
  colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFCC0000)),
);
