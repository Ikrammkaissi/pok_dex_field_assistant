/// Weather Pokémon suggestion screen.
/// Shows current weather conditions and a list of Pokémon matching the
/// weather-derived type. Reuses [PokemonListTile] so navigation to detail
/// works exactly the same as from the search screen.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/presentation/widgets/pokemon_list_tile.dart';
import 'package:pok_dex_field_assistant/features/weather/data/models/weather_models.dart';
import 'package:pok_dex_field_assistant/features/weather/presentation/providers/weather_providers.dart';
import 'package:pok_dex_field_assistant/features/weather/presentation/providers/weather_state.dart';

/// Root screen for weather-based Pokémon suggestions.
/// Reads [weatherControllerProvider] and delegates layout to private sub-widgets.
class WeatherPokemonScreen extends ConsumerWidget {
  /// Creates a [WeatherPokemonScreen].
  const WeatherPokemonScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    /// Watch state so the screen rebuilds when loading/error/data changes.
    final state = ref.watch(weatherControllerProvider);

    /// Read notifier once — stable ref for callbacks (no rebuild on read).
    final controller = ref.read(weatherControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        title: const Text('Suggest by Weather'),
        centerTitle: false,
        actions: [
          /// Refresh button re-triggers weather fetch and updates suggestions.
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh weather',
            onPressed: controller.fetchWeatherSuggestions,
          ),
        ],
      ),
      body: _WeatherContent(
        state: state,
        onRetry: controller.fetchWeatherSuggestions,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Private sub-widgets
// ---------------------------------------------------------------------------

/// Switches between loading, error, and the weather card + Pokémon list.
class _WeatherContent extends StatelessWidget {
  /// Current state from [WeatherController].
  final WeatherState state;

  /// Called when the user taps Retry after an error.
  final VoidCallback onRetry;

  const _WeatherContent({required this.state, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    /// Full-screen spinner while fetching weather and Pokémon list.
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    /// Full-screen error view with retry button.
    if (state.error != null) {
      return _ErrorView(message: state.error!, onRetry: onRetry);
    }

    final weather = state.weather;

    /// Fallback — shown briefly before the first auto-fetch completes.
    if (weather == null) {
      return const Center(child: Text('Fetching weather…'));
    }

    return Column(
      children: [
        /// Weather summary card showing conditions and suggested type.
        _WeatherCard(weather: weather),

        /// Pokémon list takes remaining vertical space.
        Expanded(
          child: state.pokemon.isEmpty
              ? const Center(child: Text('No Pokémon found for this weather.'))
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: state.pokemon.length,
                  /// Reuse the same list tile as the search screen for consistency.
                  itemBuilder: (context, i) =>
                      PokemonListTile(item: state.pokemon[i]),
                ),
        ),
      ],
    );
  }
}

/// Compact card showing temperature, windspeed, condition, and suggested type.
class _WeatherCard extends StatelessWidget {
  /// Weather snapshot to display.
  final WeatherData weather;

  const _WeatherCard({required this.weather});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    /// Suggested type shown as a highlighted chip.
    final type = weather.suggestedPokemonType;

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// Condition row: emoji icon + label.
            Row(
              children: [
                Text(
                  weather.conditionIcon,
                  style: const TextStyle(fontSize: 24),
                ),
                const SizedBox(width: 8),
                Text(
                  weather.conditionLabel,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),

            const SizedBox(height: 8),

            /// Temperature and wind stats in a compact row.
            Row(
              children: [
                const Icon(Icons.thermostat_outlined, size: 16),
                const SizedBox(width: 4),
                Text('${weather.temperature.toStringAsFixed(1)}°C'),
                const SizedBox(width: 16),
                const Icon(Icons.air_outlined, size: 16),
                const SizedBox(width: 4),
                Text('${weather.windspeed.toStringAsFixed(1)} km/h'),
              ],
            ),

            const SizedBox(height: 12),

            /// Type suggestion row — chip highlights the mapped Pokémon type.
            Row(
              children: [
                Text(
                  'Suggested type:',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(width: 8),
                Chip(
                  /// Capitalise the type name for display.
                  label: Text(
                    type[0].toUpperCase() + type.substring(1),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  backgroundColor:
                      theme.colorScheme.primaryContainer,
                  labelStyle: TextStyle(
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-screen error message with a Retry button.
class _ErrorView extends StatelessWidget {
  /// Human-readable error description.
  final String message;

  /// Called when the user taps Retry.
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            /// Cloud-off icon signals a connectivity or fetch failure.
            const Icon(Icons.cloud_off_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
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
