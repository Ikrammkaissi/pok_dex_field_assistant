/// Smoke test — verifies the search screen renders without throwing.
/// Uses a fake repository so no real HTTP calls are made.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pok_dex_field_assistant/app/app.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/data/models/pokemon_models.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/data/pokemon_repository.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/presentation/providers/pokemon_providers.dart';

// ---------------------------------------------------------------------------
// Fake repository — returns two items with no HTTP calls.
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
  testWidgets('Search screen renders AppBar title', (tester) async {
    /// Override the repository provider with a fake that makes no HTTP calls.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pokemonRepositoryProvider.overrideWithValue(_FakeRepository()),
        ],
        child: const App(),
      ),
    );

    /// First pump builds the loading state.
    await tester.pump();
    expect(find.text('Pokédex'), findsOneWidget);
  });

  testWidgets('Search screen shows list after data loads', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pokemonRepositoryProvider.overrideWithValue(_FakeRepository()),
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
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pokemonRepositoryProvider.overrideWithValue(_FakeRepository()),
        ],
        child: const App(),
      ),
    );

    await tester.pump();

    /// TextField with the search hint should be present.
    expect(find.byType(TextField), findsOneWidget);
  });
}
