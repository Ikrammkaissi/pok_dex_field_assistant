/// Full Pokémon detail screen — shown when a list tile is tapped.
/// Fetches data via [pokemonDetailProvider] and renders stats, types,
/// abilities, height, weight, and a large official artwork image.
import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pok_dex_field_assistant/core/utils/display_name.dart';
import 'package:pok_dex_field_assistant/features/bookmarks/presentation/providers/bookmark_providers.dart';
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

    /// Watch per-pokemon bookmark state for the AppBar icon.
    final bookmarked = ref.watch(isBookmarkedProvider(pokemonName));

    return Scaffold(
      /// AppBar title shows while loading and on error.
      appBar: AppBar(
        leading: const BackButton(),
        title: detailAsync.maybeWhen(
          data: (d) => Text(toDisplayName(d.name)),
          orElse: () => Text(toDisplayName(pokemonName)),
        ),
        actions: [
          /// Bookmark toggle — only active once detail data is available
          /// so we have the id and spriteUrl needed to construct the summary.
          detailAsync.maybeWhen(
            data: (detail) => IconButton(
              tooltip: bookmarked ? 'Remove bookmark' : 'Bookmark',
              icon: Icon(
                bookmarked ? Icons.bookmark : Icons.bookmark_border,
              ),
              onPressed: () {
                /// Build a lightweight summary from the loaded detail.
                final summary = PokemonSummary(
                  id: detail.id,
                  name: detail.name,
                  spriteUrl: detail.spriteUrl,
                  primaryType: detail.types.isNotEmpty ? detail.types.first : '',
                );
                ref.read(bookmarkNotifierProvider.notifier).toggle(summary);
              },
            ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
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

}

/// Scrollable body rendered once [PokemonDetail] is available.
/// Stateful to track the shiny sprite toggle.
class _DetailBody extends StatefulWidget {
  /// Full Pokémon data to render.
  final PokemonDetail detail;

  /// Creates a [_DetailBody] for [detail].
  const _DetailBody({super.key, required this.detail});

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

          /// Cry audio player — latest and legacy sounds.
          _CriesCard(
            latestUrl: detail.cryLatestUrl,
            legacyUrl: detail.cryLegacyUrl,
          ),
          const SizedBox(height: 16),

          /// Sprite gallery — normal or shiny variants matching hero image mode.
          _SpriteGallery(
            frontDefault: detail.spriteUrl,
            backDefault: detail.backSpriteUrl,
            frontShiny: detail.frontShinySpriteUrl,
            backShiny: detail.backShinySpriteUrl,
            isShiny: _showShiny,
          ),
          const SizedBox(height: 16),

          /// Abilities list — hidden ability flagged.
          _AbilitiesCard(abilities: detail.abilities),
          const SizedBox(height: 16),

          /// Games this Pokémon appears in.
          _GameIndicesCard(gameIndices: detail.gameIndices),
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
    super.key,
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
            child: CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.contain,
              /// Spinner while downloading.
              placeholder: (ctx, _) =>
                  const Center(child: CircularProgressIndicator()),
              /// Pokéball icon if URL is empty or fails.
              errorWidget: (ctx, _, __) =>
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
  const _Header({super.key, required this.id, required this.name});

  @override
  Widget build(BuildContext context) {
    final display = toDisplayName(name);

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
  const _TypeChips({super.key, required this.types});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    /// Computed once per build — shared across all type chips in this row.
    final labelStyle = TextStyle(
      color: scheme.onSecondaryContainer,
      fontWeight: FontWeight.bold,
      fontSize: 12,
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: types.map((t) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Chip(
            label: Text(t.toUpperCase(), style: labelStyle),
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
    super.key,
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
    super.key,
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
/// Card with play buttons for the latest and legacy Pokémon cry audio.
/// Stateful — tracks playback state while using an injected audio dependency.
class _CriesCard extends ConsumerStatefulWidget {
  /// Latest cry OGG URL (modern games).
  final String latestUrl;

  /// Legacy cry OGG URL (older games).
  final String legacyUrl;

  /// Creates [_CriesCard] for the given cry URLs.
  const _CriesCard({
    super.key,
    required this.latestUrl,
    required this.legacyUrl,
  });

  @override
  ConsumerState<_CriesCard> createState() => _CriesCardState();
}

class _CriesCardState extends ConsumerState<_CriesCard> {

  /// Which cry is currently playing: 'latest', 'legacy', or null.
  String? _playing;

  /// Subscription to [_player.onPlayerComplete].
  /// Cancelled before every new play and in [dispose] to prevent listener
  /// accumulation — each [_toggle] call used to add a new listener without
  /// removing the old one, causing a memory leak and multiple setState calls
  /// per completion event.
  StreamSubscription<void>? _completeSub;

  @override
  void dispose() {
    /// Cancel completion listener before releasing the player.
    _completeSub?.cancel();
    super.dispose();
  }

  /// Plays [url] tagged by [key]; stops if already playing same key.
  /// Cancels any previous [onPlayerComplete] subscription before registering
  /// a new one so only one listener exists at any time.
  Future<void> _toggle(String key, String url) async {
    final player = ref.read(audioPlayerProvider);
    /// Always cancel before any state change to avoid stale listener firing.
    _completeSub?.cancel();
    _completeSub = null;

    if (_playing == key) {
      await player.stop();
      setState(() => _playing = null);
    } else {
      await player.stop();
      await player.play(UrlSource(url));
      setState(() => _playing = key);
      /// Register exactly one completion listener for this play session.
      _completeSub = player.onPlayerComplete.listen((_) {
        if (mounted) setState(() => _playing = null);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasBoth =
        widget.latestUrl.isNotEmpty && widget.legacyUrl.isNotEmpty;
    final hasAny =
        widget.latestUrl.isNotEmpty || widget.legacyUrl.isNotEmpty;

    if (!hasAny) return const SizedBox.shrink();
    /// Keep provider alive while this widget is mounted.
    ref.watch(audioPlayerProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cry',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                if (widget.latestUrl.isNotEmpty)
                  _CryButton(
                    label: hasBoth ? 'Latest' : 'Play Cry',
                    isPlaying: _playing == 'latest',
                    onTap: () => _toggle('latest', widget.latestUrl),
                  ),
                if (hasBoth) const SizedBox(width: 12),
                if (widget.legacyUrl.isNotEmpty)
                  _CryButton(
                    label: 'Legacy',
                    isPlaying: _playing == 'legacy',
                    onTap: () => _toggle('legacy', widget.legacyUrl),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Single play/stop button for one cry variant.
class _CryButton extends StatelessWidget {
  /// Display label shown next to the icon.
  final String label;

  /// Whether this cry is currently playing.
  final bool isPlaying;

  /// Called when button is tapped.
  final VoidCallback onTap;

  /// Creates a [_CryButton].
  const _CryButton({
    super.key,
    required this.label,
    required this.isPlaying,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FilledButton.tonal(
      onPressed: onTap,
      style: isPlaying
          ? FilledButton.styleFrom(
              backgroundColor: scheme.primaryContainer,
            )
          : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isPlaying ? Icons.stop_rounded : Icons.volume_up_rounded,
              size: 18),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
    );
  }
}

/// Shows front/back sprites — normal set or shiny set depending on [isShiny].
class _SpriteGallery extends StatelessWidget {
  /// Front-default sprite URL.
  final String frontDefault;

  /// Back-default sprite URL.
  final String backDefault;

  /// Front-shiny sprite URL.
  final String frontShiny;

  /// Back-shiny sprite URL.
  final String backShiny;

  /// When true, shows shiny variants; otherwise shows normal variants.
  final bool isShiny;

  /// Creates [_SpriteGallery] from four sprite URLs.
  const _SpriteGallery({
    super.key,
    required this.frontDefault,
    required this.backDefault,
    required this.frontShiny,
    required this.backShiny,
    required this.isShiny,
  });

  @override
  Widget build(BuildContext context) {
    /// Show shiny or normal pair depending on toggle; skip empty URLs.
    final sprites = isShiny
        ? <(String, String)>[('Front', frontShiny), ('Back', backShiny)]
        : <(String, String)>[('Front', frontDefault), ('Back', backDefault)];
    final visible = sprites.where((s) => s.$2.isNotEmpty).toList();

    if (visible.isEmpty) return const SizedBox.shrink();

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
                children: visible.map((s) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Column(
                      children: [
                        /// Fixed 80×80 box per sprite tile.
                        SizedBox(
                          width: 80,
                          height: 80,
                          child: CachedNetworkImage(
                            imageUrl: s.$2,
                            fit: BoxFit.contain,
                            placeholder: (ctx, _) => const Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2),
                              ),
                            ),
                            errorWidget: (ctx, _, __) => const Icon(
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
  /// Ability entries in slot order with hidden flag from API.
  final List<({String name, bool isHidden})> abilities;

  /// Creates [_AbilitiesCard] for [abilities].
  const _AbilitiesCard({super.key, required this.abilities});

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
            /// Each ability on its own row; hidden marker uses API field.
            ...abilities.map((ability) {
              final display = toDisplayName(ability.name);

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    const Icon(Icons.bolt_outlined, size: 16),
                    const SizedBox(width: 8),
                    Text(display,
                        style: Theme.of(context).textTheme.bodyMedium),
                    if (ability.isHidden) ...[
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

/// Card showing all game versions this Pokémon appears in as wrapped chips.
class _GameIndicesCard extends StatelessWidget {
  /// Version names in API order (e.g. ['red', 'blue', 'gold']).
  final List<String> gameIndices;

  /// Creates [_GameIndicesCard] for [gameIndices].
  const _GameIndicesCard({super.key, required this.gameIndices});

  @override
  Widget build(BuildContext context) {
    if (gameIndices.isEmpty) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Available In',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: scheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${gameIndices.length}',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            /// Wrap chips — they flow to next line automatically.
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: gameIndices.map((g) {
                return Chip(
                  label: Text(
                    toDisplayName(g),
                    style: TextStyle(
                      fontSize: 11,
                      color: scheme.onSecondaryContainer,
                    ),
                  ),
                  backgroundColor: scheme.secondaryContainer,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                );
              }).toList(),
            ),
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
  const _BaseStatsCard({super.key, required this.stats});

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
  const _StatBar({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    /// Maximum base stat across all Pokémon is 255 (Blissey HP).
    const maxStat = 255.0;

    /// Bar colour transitions low → mid → high using theme-aware colours.
    /// [ColorScheme.error] for low stats, harmonised orange/green for mid/high
    /// so bars respect the active theme seed rather than hard-coded hues.
    final ratio = value / maxStat;
    final scheme = Theme.of(context).colorScheme;
    final barColor = _statColor(ratio, scheme);

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

  /// Maps a 0–1 stat ratio to a theme-aware colour using [ColorScheme] only.
  /// No hardcoded hues — all three tones are derived from the active seed:
  ///   low  → [ColorScheme.error]     (semantic red, seed-adaptive)
  ///   mid  → [ColorScheme.tertiary]  (seed-generated warning tone)
  ///   high → [ColorScheme.secondary] (seed-generated positive tone)
  Color _statColor(double ratio, ColorScheme scheme) {
    if (ratio < 0.33) return scheme.error;
    if (ratio < 0.66) return scheme.tertiary;
    return scheme.secondary;
  }
}

/// Move method display labels and sort priority.
const _methodLabels = <String, String>{
  'level-up': 'Level Up',
  'machine': 'TM/HM',
  'egg': 'Egg',
  'tutor': 'Tutor',
};

/// Sort order for learn method groups.
const _methodOrder = ['level-up', 'machine', 'egg', 'tutor'];

/// Card showing all learnable moves grouped by learn method.
/// Within each group: level-up sorted by level, rest alphabetical.
class _MovesCard extends StatefulWidget {
  /// All learnable moves with method and level data.
  final List<MoveEntry> moves;

  /// Creates [_MovesCard] for [moves].
  const _MovesCard({super.key, required this.moves});

  @override
  State<_MovesCard> createState() => _MovesCardState();
}

class _MovesCardState extends State<_MovesCard> {
  /// Grouped and sorted moves — computed once per unique [moves] list.
  late Map<String, List<MoveEntry>> _groups;

  /// Ordered group keys — known methods first, unknowns appended.
  late List<String> _orderedKeys;

  @override
  void initState() {
    super.initState();
    _computeGroups(widget.moves);
  }

  @override
  void didUpdateWidget(_MovesCard old) {
    super.didUpdateWidget(old);
    /// Re-compute only when the moves list reference changes (new detail load).
    if (!identical(old.moves, widget.moves)) {
      _computeGroups(widget.moves);
    }
  }

  /// Groups and sorts [moves] once; result stored in [_groups] and [_orderedKeys].
  void _computeGroups(List<MoveEntry> moves) {
    final groups = <String, List<MoveEntry>>{};
    for (final m in moves) {
      (groups[m.learnMethod] ??= []).add(m);
    }
    for (final entry in groups.entries) {
      if (entry.key == 'level-up') {
        entry.value.sort((a, b) => a.levelLearnedAt.compareTo(b.levelLearnedAt));
      } else {
        entry.value.sort((a, b) => a.name.compareTo(b.name));
      }
    }
    _groups = groups;
    _orderedKeys = [
      ..._methodOrder.where(groups.containsKey),
      ...groups.keys.where((k) => !_methodOrder.contains(k)),
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (widget.moves.isEmpty) return const SizedBox.shrink();

    final groups = _groups;
    final orderedKeys = _orderedKeys;

    final scheme = Theme.of(context).colorScheme;
    final labelStyle = Theme.of(context)
        .textTheme
        .bodySmall
        ?.copyWith(color: scheme.outline);
    final valueStyle = Theme.of(context).textTheme.bodySmall;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// Header with total count badge.
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
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: scheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${widget.moves.length}',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            /// One section per learn method.
            for (final key in orderedKeys) ...[
              /// Section header — method label + group count.
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 4),
                child: Row(
                  children: [
                    Text(
                      _methodLabels[key] ?? toDisplayName(key),
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: scheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '(${groups[key]!.length})',
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: scheme.outline),
                    ),
                  ],
                ),
              ),
              /// DataTable for this group.
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columnSpacing: 16,
                  headingRowHeight: 28,
                  dataRowMinHeight: 28,
                  dataRowMaxHeight: 32,
                  dividerThickness: 0.5,
                  columns: [
                    const DataColumn(label: Text('#')),
                    const DataColumn(label: Text('Move')),
                    /// Show Lv. column only for level-up moves.
                    if (key == 'level-up')
                      const DataColumn(label: Text('Lv.'), numeric: true),
                  ],
                  rows: groups[key]!.asMap().entries.map((e) {
                    return DataRow(cells: [
                      DataCell(Text('${e.key + 1}', style: labelStyle)),
                      DataCell(Text(toDisplayName(e.value.name), style: valueStyle)),
                      if (key == 'level-up')
                        DataCell(Text(
                          e.value.levelLearnedAt == 0
                              ? '—'
                              : '${e.value.levelLearnedAt}',
                          style: valueStyle,
                        )),
                    ]);
                  }).toList(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
