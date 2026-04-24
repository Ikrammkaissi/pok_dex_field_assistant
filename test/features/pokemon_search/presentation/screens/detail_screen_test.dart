import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pok_dex_field_assistant/features/bookmarks/presentation/providers/bookmark_providers.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/data/models/pokemon_models.dart';
import 'package:pok_dex_field_assistant/features/pokemon_detail/presentation/providers/pokemon_detail_providers.dart';
import 'package:pok_dex_field_assistant/features/pokemon_detail/presentation/screens/detail_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _bookmarkStorageKey = 'pokemon_bookmarks';

const _detail = PokemonDetail(
  id: 1,
  name: 'bulbasaur',
  spriteUrl: '',
  backSpriteUrl: '',
  frontShinySpriteUrl: '',
  backShinySpriteUrl: '',
  officialArtworkUrl: '',
  officialArtworkShinyUrl: '',
  baseExperience: 64,
  moveCount: 2,
  moves: [
    MoveEntry(name: 'tackle', learnMethod: 'level-up', levelLearnedAt: 1),
    MoveEntry(name: 'vine-whip', learnMethod: 'level-up', levelLearnedAt: 7),
  ],
  types: ['grass', 'poison'],
  height: 7,
  weight: 69,
  abilities: [
    (name: 'overgrow', isHidden: false),
    (name: 'chlorophyll', isHidden: true),
  ],
  stats: {
    'hp': 45,
    'attack': 49,
    'defense': 49,
    'special-attack': 65,
    'special-defense': 65,
    'speed': 45,
  },
  gameIndices: ['red', 'blue'],
  cryLatestUrl: '',
  cryLegacyUrl: '',
);

Future<void> _pumpDetailScreen(
  WidgetTester tester, {
  required Override detailOverride,
  List<PokemonSummary> initialBookmarks = const [],
}) async {
  SharedPreferences.setMockInitialValues({
    _bookmarkStorageKey: initialBookmarks
        .map((p) => jsonEncode(p.toJson()))
        .toList(growable: false),
  });
  final prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        detailOverride,
      ],
      child: const MaterialApp(
        home: DetailScreen(pokemonName: 'bulbasaur'),
      ),
    ),
  );
}

void main() {
  testWidgets('shows loading spinner while detail is loading', (tester) async {
    final completer = Completer<PokemonDetail>();
    await _pumpDetailScreen(
      tester,
      detailOverride: pokemonDetailProvider('bulbasaur').overrideWith((ref) {
        return completer.future;
      }),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    completer.complete(_detail);
  });

  testWidgets('renders detail content when provider returns data', (tester) async {
    await _pumpDetailScreen(
      tester,
      detailOverride: pokemonDetailProvider('bulbasaur').overrideWith(
        (ref) async => _detail,
      ),
    );

    await tester.pump();

    expect(find.text('Bulbasaur'), findsAtLeastNWidgets(1));
    expect(find.text('#001'), findsOneWidget);
    expect(find.text('Abilities'), findsOneWidget);
    expect(find.text('Moves'), findsAtLeastNWidgets(1));
    expect(find.byTooltip('Bookmark'), findsOneWidget);
  });

  testWidgets('shows bookmarked icon state when pokemon is saved',
      (tester) async {
    const saved = PokemonSummary(
      id: 1,
      name: 'bulbasaur',
      spriteUrl: '',
      primaryType: 'grass',
    );

    await _pumpDetailScreen(
      tester,
      detailOverride: pokemonDetailProvider('bulbasaur').overrideWith(
        (ref) async => _detail,
      ),
      initialBookmarks: const [saved],
    );

    await tester.pump();

    expect(find.byTooltip('Remove bookmark'), findsOneWidget);
  });

  testWidgets('shows error state and retry re-triggers fetch', (tester) async {
    var callCount = 0;

    await _pumpDetailScreen(
      tester,
      detailOverride: pokemonDetailProvider('bulbasaur').overrideWith((ref) {
        callCount++;
        throw Exception('boom');
      }),
    );

    await tester.pump();

    expect(find.text('Failed to load Pokémon.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(callCount, 1);

    await tester.tap(find.text('Retry'));
    await tester.pump();

    expect(callCount, greaterThanOrEqualTo(2));
  });
}
