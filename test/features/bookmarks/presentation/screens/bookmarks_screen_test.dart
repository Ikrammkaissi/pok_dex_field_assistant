import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pok_dex_field_assistant/features/bookmarks/presentation/providers/bookmark_providers.dart';
import 'package:pok_dex_field_assistant/features/bookmarks/presentation/screens/bookmarks_screen.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/data/models/pokemon_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _bookmarkStorageKey = 'pokemon_bookmarks';

const _bulbasaur = PokemonSummary(
  id: 1,
  name: 'bulbasaur',
  spriteUrl: '',
  primaryType: 'grass',
);

Future<void> _pumpBookmarksScreen(
  WidgetTester tester, {
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
      ],
      child: const MaterialApp(
        home: BookmarksScreen(),
      ),
    ),
  );
}

void main() {
  testWidgets('shows empty state when no bookmarks exist', (tester) async {
    await _pumpBookmarksScreen(tester);
    await tester.pump();

    expect(find.byKey(BookmarkScreenKeys.emptyState), findsOneWidget);
    expect(find.text('No saved Pokémon yet.'), findsOneWidget);
  });

  testWidgets('shows bookmarks list when saved items exist', (tester) async {
    await _pumpBookmarksScreen(
      tester,
      initialBookmarks: const [_bulbasaur],
    );
    await tester.pump();

    expect(find.byKey(BookmarkScreenKeys.list), findsOneWidget);
    expect(find.text('Bulbasaur'), findsOneWidget);
  });

  testWidgets('can remove a bookmark from list tile action', (tester) async {
    await _pumpBookmarksScreen(
      tester,
      initialBookmarks: const [_bulbasaur],
    );
    await tester.pump();

    expect(find.text('Bulbasaur'), findsOneWidget);

    await tester.tap(find.byTooltip('Remove bookmark'));
    await tester.pump();

    expect(find.byKey(BookmarkScreenKeys.emptyState), findsOneWidget);
    expect(find.text('No saved Pokémon yet.'), findsOneWidget);
  });
}
