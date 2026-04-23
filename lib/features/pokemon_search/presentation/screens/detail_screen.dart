/// Full Pokémon detail screen — shown when a list tile is tapped.
/// Fetches data via [pokemonDetailProvider] and renders stats, types,
/// abilities, height, weight, and a large official artwork image.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/data/models/pokemon_models.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/presentation/providers/pokemon_providers.dart';

/// Stat display labels — prettier than the raw API stat names.
const _statLabels = <String, String>{
  'hp': 'HP',
  'attack': 'Atk',
  'defense': 'Def',
  'special-attack': 'Sp. Atk',
  'special-defense': 'Sp. Def',
  'speed': 'Speed',
};

/// Detail screen for a single Pokémon identified by [pokemonName].
/// Loaded via GoRouter path parameter — no data passed directly.
class DetailScreen extends ConsumerWidget {
  /// Lowercase hyphenated Pokémon name used to fetch detail.
  final String pokemonName;

  /// Creates a [DetailScreen] for [pokemonName].
  const DetailScreen({super.key, required this.pokemonName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    /// Watch the async detail fetch — rebuilds on loading/data/error.
    final detailAsync = ref.watch(pokemonDetailProvider(pokemonName));

    return Scaffold(
      /// AppBar title shows while loading and on error.
      appBar: AppBar(
        leading: const BackButton(),
        title: detailAsync.maybeWhen(
          data: (d) => Text(_displayName(d.name)),
          orElse: () => Text(_displayName(pokemonName)),
        ),
      ),
      body: detailAsync.when(
        /// Loading state — centred spinner.
        loading: () => const Center(child: CircularProgressIndicator()),

        /// Error state — message and retry button.
        error: (err, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 12),
              Text('Failed to load Pokémon.',
                  style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 8),
              ElevatedButton(
                /// Invalidate the provider to force a fresh fetch.
                onPressed: () =>
                    ref.invalidate(pokemonDetailProvider(pokemonName)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),

        /// Data state — full detail layout.
        data: (detail) => _DetailBody(detail: detail),
      ),
    );
  }

  /// Converts hyphenated API name to title-cased display name.
  String _displayName(String name) => name
      .split('-')
      .map((w) => w.isEmpty ? '' : w[0].toUpperCase() + w.substring(1))
      .join(' ');
}

/// Scrollable body rendered once [PokemonDetail] is available.
/// Stateful to track the shiny sprite toggle.
class _DetailBody extends StatefulWidget {
  /// Full Pokémon data to render.
  final PokemonDetail detail;

  /// Creates a [_DetailBody] for [detail].
  const _DetailBody({required this.detail});

  @override
  State<_DetailBody> createState() => _DetailBodyState();
}

class _DetailBodyState extends State<_DetailBody> {
  /// Whether the shiny artwork variant is currently shown.
  bool _showShiny = false;

  @override
  Widget build(BuildContext context) {
    final detail = widget.detail;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          /// Hero image with shiny toggle button overlaid.
          _HeroImage(
            url: _showShiny
                ? detail.officialArtworkShinyUrl
                : detail.officialArtworkUrl,
            isShiny: _showShiny,
            onToggleShiny: () => setState(() => _showShiny = !_showShiny),
          ),
          const SizedBox(height: 16),

          /// Dex number and name header.
          _Header(id: detail.id, name: detail.name),
          const SizedBox(height: 12),

          /// Type badges.
          _TypeChips(types: detail.types),
          const SizedBox(height: 16),

          /// Physical stats: height, weight, base experience, and move count.
          _PhysicalStats(
            height: detail.height,
            weight: detail.weight,
            baseExperience: detail.baseExperience,
            moveCount: detail.moveCount,
          ),
          const SizedBox(height: 16),

          /// Sprite gallery — all four small sprite variants.
          _SpriteGallery(
            frontDefault: detail.spriteUrl,
            backDefault: detail.backSpriteUrl,
            frontShiny: detail.frontShinySpriteUrl,
            backShiny: detail.backShinySpriteUrl,
          ),
          const SizedBox(height: 16),

          /// Abilities list — hidden ability flagged.
          _AbilitiesCard(abilities: detail.abilities),
          const SizedBox(height: 16),

          /// Base stat bars.
          _BaseStatsCard(stats: detail.stats),
          const SizedBox(height: 16),

          /// Full moves table.
          _MovesCard(moves: detail.moves),
        ],
      ),
    );
  }
}

/// Large Pokémon image with a shiny toggle button in the corner.
class _HeroImage extends StatelessWidget {
  /// Artwork URL to load (normal or shiny depending on [isShiny]).
  final String url;

  /// Whether the shiny variant is currently shown.
  final bool isShiny;

  /// Called when the user taps the shiny toggle button.
  final VoidCallback onToggleShiny;

  /// Creates a [_HeroImage] with shiny toggle support.
  const _HeroImage({
    required this.url,
    required this.isShiny,
    required this.onToggleShiny,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            /// Fixed size — prominent but fits small phones.
            width: 220,
            height: 220,
            child: Image.network(
              url,
              fit: BoxFit.contain,
              /// Spinner while downloading.
              loadingBuilder: (ctx, child, progress) => progress == null
                  ? child
                  : const Center(child: CircularProgressIndicator()),
              /// Pokéball icon if URL is empty or fails.
              errorBuilder: (ctx, _, __) =>
                  const Center(child: Icon(Icons.catching_pokemon, size: 80)),
            ),
          ),

          /// Shiny toggle — bottom-right corner of the image box.
          Positioned(
            bottom: 0,
            right: 0,
            child: Tooltip(
              message: isShiny ? 'Show normal' : 'Show shiny',
              child: IconButton.filledTonal(
                icon: const Icon(Icons.auto_awesome),
                /// Highlighted colour when shiny is active.
                style: isShiny
                    ? IconButton.styleFrom(
                        backgroundColor:
                            Theme.of(context).colorScheme.primaryContainer,
                      )
                    : null,
                onPressed: onToggleShiny,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dex number + name displayed as a centred headline.
class _Header extends StatelessWidget {
  /// National Pokédex number.
  final int id;

  /// Lowercase hyphenated name.
  final String name;

  /// Creates a [_Header] for Pokémon [id] and [name].
  const _Header({required this.id, required this.name});

  @override
  Widget build(BuildContext context) {
    final display = name
        .split('-')
        .map((w) => w.isEmpty ? '' : w[0].toUpperCase() + w.substring(1))
        .join(' ');

    return Column(
      children: [
        Text(
          '#${id.toString().padLeft(3, '0')}',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: Theme.of(context).colorScheme.outline),
        ),
        Text(
          display,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// Row of coloured type badges.
class _TypeChips extends StatelessWidget {
  /// Type names in slot order.
  final List<String> types;

  /// Creates [_TypeChips] for [types].
  const _TypeChips({required this.types});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: types.map((t) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Chip(
            label: Text(
              t.toUpperCase(),
              style: TextStyle(
                color: scheme.onSecondaryContainer,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            backgroundColor: scheme.secondaryContainer,
            /// Remove default padding to keep chips compact.
            padding: const EdgeInsets.symmetric(horizontal: 6),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        );
      }).toList(),
    );
  }
}

/// Four-column card: height, weight, base experience, and move count.
class _PhysicalStats extends StatelessWidget {
  /// Height in decimetres (PokéAPI unit — divide by 10 for metres).
  final int height;

  /// Weight in hectograms (PokéAPI unit — divide by 10 for kg).
  final int weight;

  /// Base experience awarded when this Pokémon is defeated in battle.
  final int baseExperience;

  /// Total number of moves this Pokémon can learn.
  final int moveCount;

  /// Creates [_PhysicalStats] from raw PokéAPI values.
  const _PhysicalStats({
    required this.height,
    required this.weight,
    required this.baseExperience,
    required this.moveCount,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            /// Height in metres with one decimal place.
            _StatItem(
              label: 'Height',
              value: '${(height / 10).toStringAsFixed(1)} m',
              icon: Icons.height,
            ),
            const VerticalDivider(width: 1),
            /// Weight in kg with one decimal place.
            _StatItem(
              label: 'Weight',
              value: '${(weight / 10).toStringAsFixed(1)} kg',
              icon: Icons.monitor_weight_outlined,
            ),
            const VerticalDivider(width: 1),
            /// Base XP — experience points gained by defeating this Pokémon.
            _StatItem(
              label: 'Base XP',
              value: '$baseExperience',
              icon: Icons.star_outline,
            ),
            const VerticalDivider(width: 1),
            /// Move count — total learnable moves.
            _StatItem(
              label: 'Moves',
              value: '$moveCount',
              icon: Icons.sports_martial_arts_outlined,
            ),
          ],
        ),
      ),
    );
  }
}

/// Single labelled stat value with an icon.
class _StatItem extends StatelessWidget {
  /// Display label (e.g. 'Height').
  final String label;

  /// Formatted value string (e.g. '1.7 m').
  final String value;

  /// Icon to show above the value.
  final IconData icon;

  /// Creates a [_StatItem] with [label], [value], and [icon].
  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 4),
        Text(value, style: Theme.of(context).textTheme.titleMedium),
        Text(
          label,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: Theme.of(context).colorScheme.outline),
        ),
      ],
    );
  }
}

/// Horizontal scrollable row of small sprite variants.
/// Shows front/back in normal and shiny — skips empty URLs.
class _SpriteGallery extends StatelessWidget {
  /// Front-default sprite URL.
  final String frontDefault;

  /// Back-default sprite URL.
  final String backDefault;

  /// Front-shiny sprite URL.
  final String frontShiny;

  /// Back-shiny sprite URL.
  final String backShiny;

  /// Creates [_SpriteGallery] from four sprite URLs.
  const _SpriteGallery({
    required this.frontDefault,
    required this.backDefault,
    required this.frontShiny,
    required this.backShiny,
  });

  @override
  Widget build(BuildContext context) {
    /// Label–URL pairs; filter out entries with empty URLs.
    final sprites = <(String, String)>[
      ('Front', frontDefault),
      ('Back', backDefault),
      ('Front ✦', frontShiny),
      ('Back ✦', backShiny),
    ].where((s) => s.$2.isNotEmpty).toList();

    if (sprites.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sprites',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: sprites.map((s) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Column(
                      children: [
                        /// Fixed 80×80 box per sprite tile.
                        SizedBox(
                          width: 80,
                          height: 80,
                          child: Image.network(
                            s.$2,
                            fit: BoxFit.contain,
                            loadingBuilder: (ctx, child, progress) =>
                                progress == null
                                    ? child
                                    : const Center(
                                        child: SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2),
                                        ),
                                      ),
                            errorBuilder: (ctx, _, __) => const Icon(
                                Icons.broken_image_outlined,
                                size: 40),
                          ),
                        ),
                        Text(
                          s.$1,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Card listing all abilities, flagging hidden ones.
class _AbilitiesCard extends StatelessWidget {
  /// Ability names in slot order (hidden last, if any).
  final List<String> abilities;

  /// Creates [_AbilitiesCard] for [abilities].
  const _AbilitiesCard({required this.abilities});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Abilities',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    )),
            const SizedBox(height: 8),
            /// Each ability on its own row; last entry may be hidden ability.
            ...abilities.asMap().entries.map((e) {
              /// PokéAPI puts hidden abilities at the last slot (slot 3).
              /// We flag the last item if count > 1 as potentially hidden.
              final isHidden =
                  abilities.length > 1 && e.key == abilities.length - 1;
              final display = e.value
                  .split('-')
                  .map((w) =>
                      w.isEmpty ? '' : w[0].toUpperCase() + w.substring(1))
                  .join(' ');

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    const Icon(Icons.bolt_outlined, size: 16),
                    const SizedBox(width: 8),
                    Text(display,
                        style: Theme.of(context).textTheme.bodyMedium),
                    if (isHidden) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .secondaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Hidden',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

/// Card showing all six base stats as labelled progress bars.
class _BaseStatsCard extends StatelessWidget {
  /// Base stat values keyed by PokéAPI stat name.
  final Map<String, int> stats;

  /// Creates [_BaseStatsCard] for [stats].
  const _BaseStatsCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    /// Render in fixed order matching official Pokédex displays.
    final order = [
      'hp',
      'attack',
      'defense',
      'special-attack',
      'special-defense',
      'speed',
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Base Stats',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    )),
            const SizedBox(height: 12),
            ...order.map((key) {
              final value = stats[key] ?? 0;
              final label = _statLabels[key] ?? key;
              return _StatBar(label: label, value: value);
            }),
          ],
        ),
      ),
    );
  }
}

/// Single stat row: label, numeric value, and colour-coded progress bar.
class _StatBar extends StatelessWidget {
  /// Short display label (e.g. 'HP', 'Sp. Atk').
  final String label;

  /// Base stat value (0–255).
  final int value;

  /// Creates a [_StatBar] for [label] with [value].
  const _StatBar({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    /// Maximum base stat across all Pokémon is 255 (Blissey HP).
    const maxStat = 255.0;

    /// Bar colour transitions from red (low) → orange → green (high).
    final ratio = value / maxStat;
    final barColor = ratio < 0.33
        ? Colors.red
        : ratio < 0.66
            ? Colors.orange
            : Colors.green;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          /// Fixed-width label column so bars align.
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ),

          /// Numeric value in fixed-width column.
          SizedBox(
            width: 32,
            child: Text(
              '$value',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: 8),

          /// Progress bar fills remaining horizontal space.
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: ratio,
                color: barColor,
                backgroundColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
                minHeight: 8,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Table listing all learnable moves, two per row, sorted alphabetically.
class _MovesCard extends StatelessWidget {
  /// All learnable move names in display order.
  final List<String> moves;

  /// Creates [_MovesCard] for [moves].
  const _MovesCard({required this.moves});

  /// Converts hyphenated API name to title-cased display name.
  String _display(String name) => name
      .split('-')
      .map((w) => w.isEmpty ? '' : w[0].toUpperCase() + w.substring(1))
      .join(' ');

  @override
  Widget build(BuildContext context) {
    if (moves.isEmpty) return const SizedBox.shrink();

    /// Sort alphabetically for easier scanning.
    final sorted = [...moves]..sort();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Moves',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                /// Move count badge.
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${moves.length}',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            /// Two-column table using DataTable for aligned rows.
            DataTable(
              /// Compact column spacing.
              columnSpacing: 16,
              headingRowHeight: 32,
              dataRowMinHeight: 28,
              dataRowMaxHeight: 36,
              dividerThickness: 0,
              columns: const [
                DataColumn(label: Text('#')),
                DataColumn(label: Text('Move')),
                DataColumn(label: Text('#')),
                DataColumn(label: Text('Move')),
              ],
              rows: List.generate(
                (sorted.length / 2).ceil(),
                (i) {
                  /// Left cell — always exists.
                  final leftIdx = i * 2;
                  /// Right cell — may not exist for odd-count lists.
                  final rightIdx = leftIdx + 1;
                  final hasRight = rightIdx < sorted.length;

                  return DataRow(cells: [
                    DataCell(Text(
                      '${leftIdx + 1}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                    )),
                    DataCell(Text(
                      _display(sorted[leftIdx]),
                      style: Theme.of(context).textTheme.bodySmall,
                    )),
                    DataCell(hasRight
                        ? Text(
                            '${rightIdx + 1}',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color:
                                      Theme.of(context).colorScheme.outline,
                                ),
                          )
                        : const SizedBox.shrink()),
                    DataCell(hasRight
                        ? Text(
                            _display(sorted[rightIdx]),
                            style: Theme.of(context).textTheme.bodySmall,
                          )
                        : const SizedBox.shrink()),
                  ]);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
