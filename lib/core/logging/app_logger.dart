/// Centralised logging utility for the app.
///
/// ## Design decisions
///
/// **Static API with a tag parameter** , `AppLogger.debug('HttpClient', 'msg')`
/// Tags make it easy to grep logs by layer without injecting a logger instance
/// into every class. No DI wiring needed.
///
/// **Wraps `logger` package** , decouples the rest of the codebase from the
/// package. If we swap the package later, only this file changes.
///
/// **Build-mode aware** , `kDebugMode` switches between pretty console output
/// (debug) and silent / warning-only output (release). No manual flags needed.
///
/// **`MultiOutput` for extensibility** , adding a remote sink (Sentry,
/// Firebase Crashlytics, Datadog) requires only adding one line inside
/// [_buildOutput]. Nothing else in the codebase changes.
///
/// ## Adding a remote sink (future)
/// ```dart
/// // 1. Extend LogOutput:
/// class SentryLogOutput extends LogOutput {
///   @override
///   void output(OutputEvent event) {
///     if (event.level.index >= Level.error.index) {
///       Sentry.captureMessage(event.lines.join('\n'));
///     }
///   }
/// }
///
/// // 2. Register in _buildOutput():
/// return MultiOutput([ConsoleOutput(), SentryLogOutput()]);
/// ```
library;

import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

/// App-wide logger. Call static methods from any layer , no instance needed.
///
/// Usage:
/// ```dart
/// AppLogger.debug('HttpClient', 'GET /pokemon?limit=100');
/// AppLogger.error('SearchController', 'init failed', error: e, stackTrace: s);
/// ```
class AppLogger {
  /// Private singleton [Logger] , configured once at startup.
  static final Logger _logger = Logger(
    /// Simple single-line output.
    printer: SimplePrinter(colors: true),
    /// Fan out to multiple sinks; add remote outputs here in future.
    output: _buildOutput(),
    /// Debug: show everything. Release: only warnings and above.
    level: kDebugMode ? Level.debug : Level.warning,
  );

  /// Builds the [LogOutput] pipeline.
  /// Returns [MultiOutput] so a remote sink can be appended without touching
  /// any other code (see file-level doc for the pattern).
  static LogOutput _buildOutput() {
    return MultiOutput([
      ConsoleOutput(),
      /// Add remote outputs here, e.g.:
      /// SentryLogOutput(),
      /// CrashlyticsLogOutput(),
    ]);
  }

  // Prevent instantiation , all members are static.
  AppLogger._();

  /// Logs a [message] at debug level under [tag].
  /// Only emitted in debug builds; no-op in release.
  static void debug(String tag, String message) =>
      _logger.d('[$tag] $message');

  /// Logs a [message] at info level under [tag].
  /// Only emitted in debug builds; no-op in release.
  static void info(String tag, String message) =>
      _logger.i('[$tag] $message');

  /// Logs a [message] at warning level under [tag].
  /// Emitted in both debug and release builds.
  static void warning(String tag, String message) =>
      _logger.w('[$tag] $message');

  /// Logs a [message] at error level under [tag].
  /// Emitted in both debug and release builds.
  /// Pass [error] and [stackTrace] for full diagnostics.
  static void error(
    String tag,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) =>
      _logger.e(
        '[$tag] $message',
        error: error,
        stackTrace: stackTrace,
      );
}
