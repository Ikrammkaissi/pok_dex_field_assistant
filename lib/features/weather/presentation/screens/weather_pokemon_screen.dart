/// Weather Pokémon suggestion screen.
/// Shows editable latitude/longitude fields, current weather conditions, and a
/// list of Pokémon matching the weather-derived type. Reuses [PokemonListTile]
/// so navigation to detail works exactly the same as from the search screen.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/presentation/widgets/pokemon_list_tile.dart';
import 'package:pok_dex_field_assistant/features/weather/data/models/weather_models.dart';
import 'package:pok_dex_field_assistant/features/weather/presentation/providers/weather_providers.dart';
import 'package:pok_dex_field_assistant/features/weather/presentation/providers/weather_state.dart';

/// Stable widget keys for [WeatherPokemonScreen] — used in widget tests.
class WeatherScreenKeys {
  /// Loading spinner shown while fetching weather and Pokémon.
  static const loadingIndicator = Key('weather_loading');

  /// ListView containing the Pokémon tiles.
  static const pokemonList = Key('weather_pokemon_list');

  /// Container shown when a fetch fails.
  static const errorView = Key('weather_error_view');

  /// Retry button inside the error view.
  static const retryButton = Key('weather_retry_button');

  /// Card showing temperature, windspeed, and suggested type.
  static const weatherCard = Key('weather_card');

  /// Latitude text field.
  static const latField = Key('weather_lat_field');

  /// Longitude text field.
  static const lonField = Key('weather_lon_field');

  /// Go button that applies manual coordinate input.
  static const goButton = Key('weather_go_button');

  /// Shuffle button in the AppBar that randomises coordinates.
  static const shuffleButton = Key('weather_shuffle_button');
}

/// Root screen for weather-based Pokémon suggestions.
/// Uses [ConsumerStatefulWidget] to manage the lat/lon [TextEditingController]s.
class WeatherPokemonScreen extends ConsumerStatefulWidget {
  /// Creates a [WeatherPokemonScreen].
  const WeatherPokemonScreen({super.key});

  @override
  ConsumerState<WeatherPokemonScreen> createState() =>
      _WeatherPokemonScreenState();
}

class _WeatherPokemonScreenState extends ConsumerState<WeatherPokemonScreen> {
  /// Text field controller for latitude input.
  late final TextEditingController _latController;

  /// Text field controller for longitude input.
  late final TextEditingController _lonController;

  /// Attached to the Pokémon list to detect scroll position for pagination.
  late final ScrollController _scrollController;

  /// Tracks the lat displayed in the text fields to avoid overwriting while typing.
  double? _syncedLat;

  /// Tracks the lon displayed in the text fields to avoid overwriting while typing.
  double? _syncedLon;

  @override
  void initState() {
    super.initState();
    _latController = TextEditingController();
    _lonController = TextEditingController();
    _scrollController = ScrollController()..addListener(_onScroll);
  }

  /// Triggers [WeatherController.loadMore] when the user reaches the list bottom.
  ///
  /// Uses a threshold of 80px rather than exact `== 0` comparison — Flutter
  /// scroll physics produce fractional extents that may never equal zero exactly,
  /// silently preventing pagination. [loadMore] guards against concurrent calls.
  void _onScroll() {
    if (_scrollController.position.extentAfter < 80) {
      ref.read(weatherControllerProvider.notifier).loadMore();
    }
  }

  @override
  void dispose() {
    _latController.dispose();
    _lonController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Syncs text fields to new coordinates from state when they differ.
  /// Called in [build] so the fields reflect randomly generated coords on first load.
  void _syncFields(double lat, double lon) {
    /// Only update when coords have actually changed — prevents cursor jumping while editing.
    if (lat != _syncedLat) {
      _syncedLat = lat;
      _latController.text = lat.toStringAsFixed(4);
    }
    if (lon != _syncedLon) {
      _syncedLon = lon;
      _lonController.text = lon.toStringAsFixed(4);
    }
  }

  /// Parses the text fields and triggers a fetch with the new coordinates.
  /// Shows a SnackBar if either value is not a valid number.
  void _applyCoordinates(BuildContext context) {
    final lat = double.tryParse(_latController.text.trim());
    final lon = double.tryParse(_lonController.text.trim());

    /// Validate both fields before fetching.
    if (lat == null || lon == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter valid numbers for lat and lon.')),
      );
      return;
    }

    /// Validate range.
    if (lat < -90 || lat > 90) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Latitude must be between −90 and 90.')),
      );
      return;
    }
    if (lon < -180 || lon > 180) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Longitude must be between −180 and 180.')),
      );
      return;
    }

    /// Dismiss keyboard and trigger fetch with the parsed values.
    FocusScope.of(context).unfocus();
    ref
        .read(weatherControllerProvider.notifier)
        .fetchWeatherSuggestions(lat: lat, lon: lon);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(weatherControllerProvider);
    final controller = ref.read(weatherControllerProvider.notifier);

    /// Sync text fields whenever the controller updates coordinates.
    _syncFields(state.lat, state.lon);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        title: const Text('Suggest by Weather'),
        centerTitle: false,
        actions: [
          /// Generates new random coordinates and re-fetches.
          IconButton(
            key: WeatherScreenKeys.shuffleButton,
            icon: const Icon(Icons.shuffle),
            tooltip: 'Randomise location',
            onPressed: state.isLoading
                ? null
                : () => controller.fetchWeatherSuggestions(randomise: true),
          ),
        ],
      ),
      body: Column(
        children: [
          /// Editable coordinate fields — allow manual location override.
          _CoordinateFields(
            latController: _latController,
            lonController: _lonController,
            isLoading: state.isLoading,
            onApply: () => _applyCoordinates(context),
          ),

          /// Weather info + Pokémon list fills the remaining space.
          Expanded(
            child: _WeatherContent(
              state: state,
              scrollController: _scrollController,
              onRetry: controller.fetchWeatherSuggestions,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Private sub-widgets
// ---------------------------------------------------------------------------

/// Two text fields (lat, lon) with an Apply button to re-fetch with new coords.
class _CoordinateFields extends StatelessWidget {
  /// Controller for the latitude text field.
  final TextEditingController latController;

  /// Controller for the longitude text field.
  final TextEditingController lonController;

  /// Disables the Apply button while a fetch is in progress.
  final bool isLoading;

  /// Called when the user confirms new coordinates via the Apply button or keyboard submit.
  final VoidCallback onApply;

  const _CoordinateFields({
    required this.latController,
    required this.lonController,
    required this.isLoading,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(
        children: [
          /// Latitude field — takes up ~40% of the row.
          Expanded(
            flex: 4,
            child: _CoordTextField(
              controller: latController,
              label: 'Latitude',
              onSubmitted: (_) => onApply(),
            ),
          ),
          const SizedBox(width: 8),

          /// Longitude field — takes up ~40% of the row.
          Expanded(
            flex: 4,
            child: _CoordTextField(
              controller: lonController,
              label: 'Longitude',
              onSubmitted: (_) => onApply(),
            ),
          ),
          const SizedBox(width: 8),

          /// Apply button — submits the current field values.
          FilledButton(
            key: WeatherScreenKeys.goButton,
            onPressed: isLoading ? null : onApply,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            ),
            child: const Text('Go'),
          ),
        ],
      ),
    );
  }
}

/// Single coordinate text field for numeric lat or lon input.
class _CoordTextField extends StatelessWidget {
  /// Controller shared with the parent so values can be read on apply.
  final TextEditingController controller;

  /// Label shown above the field.
  final String label;

  /// Called when the user presses Done/Enter on the keyboard.
  final ValueChanged<String> onSubmitted;

  const _CoordTextField({
    required this.controller,
    required this.label,
    required this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    /// Key is derived from the label so lat and lon fields are uniquely addressable.
    final key = label == 'Latitude'
        ? WeatherScreenKeys.latField
        : WeatherScreenKeys.lonField;

    return TextField(
      key: key,
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(
        signed: true,
        decimal: true,
      ),
      textInputAction: TextInputAction.done,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      ),
    );
  }
}

/// Switches between loading, error, and the weather card + Pokémon list.
class _WeatherContent extends StatelessWidget {
  /// Current state from [WeatherController].
  final WeatherState state;

  /// Attached to the list for scroll-to-bottom pagination detection.
  final ScrollController scrollController;

  /// Called when the user taps Retry after an error.
  final VoidCallback onRetry;

  const _WeatherContent({
    required this.state,
    required this.scrollController,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    /// Full-screen spinner while fetching weather and Pokémon list.
    if (state.isLoading) {
      return const Center(
        key: WeatherScreenKeys.loadingIndicator,
        child: CircularProgressIndicator(),
      );
    }

    /// Full-screen error view with retry button.
    if (state.error != null) {
      return _ErrorView(
        key: WeatherScreenKeys.errorView,
        message: state.error!,
        onRetry: onRetry,
      );
    }

    final weather = state.weather;

    /// Fallback — shown briefly before the first auto-fetch completes.
    if (weather == null) {
      return const Center(child: Text('Fetching weather…'));
    }

    return Column(
      children: [
        /// Weather summary card showing conditions and suggested type.
        _WeatherCard(key: WeatherScreenKeys.weatherCard, weather: weather),

        /// Pokémon list takes remaining vertical space.
        Expanded(
          child: state.pokemon.isEmpty
              ? const Center(
                  child: Text('No Pokémon found for this weather.'))
              : ListView.builder(
                  key: WeatherScreenKeys.pokemonList,
                  controller: scrollController,
                  padding: const EdgeInsets.only(bottom: 16),
                  /// Extra slot at end for the bottom loading spinner.
                  itemCount: state.pokemon.length + (state.isLoadingMore ? 1 : 0),
                  itemBuilder: (context, i) {
                    /// Bottom spinner while appending the next page.
                    if (i == state.pokemon.length) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    /// Reuse the same list tile as the search screen for consistency.
                    return PokemonListTile(item: state.pokemon[i]);
                  },
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

  const _WeatherCard({super.key, required this.weather});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    /// Suggested type shown as a highlighted chip.
    final type = weather.suggestedPokemonType;

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// Condition row: emoji icon + label.
            Row(
              children: [
                Text(weather.conditionIcon,
                    style: const TextStyle(fontSize: 24)),
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
                Text('Suggested type:', style: theme.textTheme.bodyMedium),
                const SizedBox(width: 8),
                Chip(
                  /// Capitalise the type name for display.
                  label: Text(
                    type[0].toUpperCase() + type.substring(1),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  backgroundColor: theme.colorScheme.primaryContainer,
                  labelStyle:
                      TextStyle(color: theme.colorScheme.onPrimaryContainer),
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

  const _ErrorView({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined,
                size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              key: WeatherScreenKeys.retryButton,
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
