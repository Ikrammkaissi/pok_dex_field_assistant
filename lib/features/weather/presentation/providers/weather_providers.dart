/// Presentation-layer provider declarations for the weather feature.
///
/// Infrastructure providers (HTTP clients, repository, use cases) live in
/// [lib/app/di/weather_di.dart] — this file only wires the controller.
///
/// Re-exports weather DI providers so screens only need to import this file.
export 'package:pok_dex_field_assistant/app/di/weather_di.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pok_dex_field_assistant/app/di/weather_di.dart';
import 'package:pok_dex_field_assistant/features/weather/presentation/providers/weather_controller.dart';
import 'package:pok_dex_field_assistant/features/weather/presentation/providers/weather_state.dart';

/// Provides [WeatherController] and exposes [WeatherState].
/// [autoDispose] ensures the controller is recreated each time the weather screen
/// opens — always shows fresh weather data, no stale state from a previous visit.
final weatherControllerProvider =
    StateNotifierProvider.autoDispose<WeatherController, WeatherState>((ref) {
  /// Inject both use cases so the controller never imports data-layer types.
  return WeatherController(
    ref.watch(getCurrentWeatherProvider),
    ref.watch(getPokemonByTypeProvider),
  );
});
