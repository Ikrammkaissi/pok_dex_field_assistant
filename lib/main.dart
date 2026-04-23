/// App entry point.
/// Wraps the widget tree in [ProviderScope] so Riverpod providers are
/// accessible throughout the app.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pok_dex_field_assistant/app/app.dart';

/// Starts the Flutter app with Riverpod's [ProviderScope] at the root.
void main() {
  /// [ProviderScope] must wrap the entire widget tree for Riverpod to work.
  runApp(const ProviderScope(child: App()));
}
