/// Smoke test , verifies the search screen renders without throwing.
/// Uses a fake repository so no real HTTP calls are made.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pok_dex_field_assistant/app/app.dart';
import 'package:pok_dex_field_assistant/features/bookmarks/presentation/providers/bookmark_providers.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/domain/entities/pokemon_detail.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/domain/entities/pokemon_list_page.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/domain/entities/pokemon_summary.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/domain/repositories/pokemon_repository.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/presentation/providers/pokemon_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Fake repository , returns two items with no HTTP calls.
// ---------------------------------------------------------------------------

/// In-memory fake used by widget tests to avoid real network access.
class _FakeRepository implements PokemonRepository {
  @override
  Future<PokemonListPage> getPokemonList(
          {int limit = 20, int offset = 0}) async =>
      const PokemonListPage(
        items: [
          PokemonSummary(id: 1, name: 'bulbasaur', spriteUrl: ''),
          PokemonSummary(id: 4, name: 'charmander', spriteUrl: ''),
        ],
        hasMore: false,
      );

  @override
  Future<PokemonDetail> getPokemonDetail(String nameOrId) async =>
      throw UnimplementedError();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  /// Reset SharedPreferences mock state before each test.
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Search screen renders AppBar title', (tester) async {
    final prefs = await SharedPreferences.getInstance();

    /// Override both the Pokémon repo and SharedPreferences so bookmark
    /// providers (added to SearchScreen) can initialise without error.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pokemonRepositoryProvider.overrideWithValue(_FakeRepository()),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const App(),
      ),
    );

    /// First pump builds the loading state.
    await tester.pump();
    expect(find.text('Pokédex'), findsOneWidget);
  });

  testWidgets('Search screen shows list after data loads', (tester) async {
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pokemonRepositoryProvider.overrideWithValue(_FakeRepository()),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const App(),
      ),
    );

    /// pumpAndSettle waits for all animations and async state to resolve.
    await tester.pumpAndSettle();

    /// Both fixture Pokémon should appear in the list.
    expect(find.text('Bulbasaur'), findsOneWidget);
    expect(find.text('Charmander'), findsOneWidget);
  });

  testWidgets('Search bar is visible on screen', (tester) async {
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pokemonRepositoryProvider.overrideWithValue(_FakeRepository()),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const App(),
      ),
    );

    await tester.pump();

    /// TextField with the search hint should be present.
    expect(find.byType(TextField), findsOneWidget);
  });
}
