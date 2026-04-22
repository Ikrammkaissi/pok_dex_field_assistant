/// Unit tests for [PokemonSearchController].
/// Uses hand-written fakes — no external mocking packages needed.
/// Tests state transitions in isolation from HTTP or Flutter widgets.
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pok_dex_field_assistant/core/error/exceptions.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/data/models/pokemon_models.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/data/pokemon_repository.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/presentation/providers/pokemon_providers.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/presentation/providers/pokemon_search_controller.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Builds a [PokemonSummary] with a predictable name from its dex [id].
PokemonSummary _fakePokemon(int id) =>
    PokemonSummary(id: id, name: 'pokemon-$id', spriteUrl: '');

/// Builds a list of [count] fake summaries starting at [startId].
List<PokemonSummary> _fakeItems(int startId, int count) =>
    List.generate(count, (i) => _fakePokemon(startId + i));

// ---------------------------------------------------------------------------
// Fake repositories
// ---------------------------------------------------------------------------

/// Flat repo: one page of [items], no more pages.
class _FlatRepository implements PokemonRepository {
  final List<PokemonSummary> items;
  int callCount = 0;

  _FlatRepository(this.items);

  @override
  Future<PokemonListPage> getPokemonList(
      {int limit = 100, int offset = 0}) async {
    callCount++;
    final slice = items.skip(offset).take(limit).toList();
    final hasMore = offset + slice.length < items.length;
    return PokemonListPage(items: slice, hasMore: hasMore);
  }

  @override
  Future<PokemonDetail> getPokemonDetail(String nameOrId) =>
      throw UnimplementedError();
}

/// Multi-page repo: 400 items spread across 4 pages of 100.
/// Simulates an API with 400 total Pokémon.
class _MultiPageRepository implements PokemonRepository {
  static final _all = _fakeItems(1, 400);
  int callCount = 0;

  @override
  Future<PokemonListPage> getPokemonList(
      {int limit = 100, int offset = 0}) async {
    callCount++;
    final slice = _all.skip(offset).take(limit).toList();
    final hasMore = offset + slice.length < _all.length;
    return PokemonListPage(items: slice, hasMore: hasMore);
  }

  @override
  Future<PokemonDetail> getPokemonDetail(String nameOrId) =>
      throw UnimplementedError();
}

/// Always throws [NetworkException].
class _ErrorRepository implements PokemonRepository {
  @override
  Future<PokemonListPage> getPokemonList(
          {int limit = 100, int offset = 0}) async =>
      throw const NetworkException('no internet');

  @override
  Future<PokemonDetail> getPokemonDetail(String nameOrId) =>
      throw UnimplementedError();
}

/// Always throws [ServerException] 404.
class _ServerErrorRepository implements PokemonRepository {
  @override
  Future<PokemonListPage> getPokemonList(
          {int limit = 100, int offset = 0}) async =>
      throw const ServerException(statusCode: 404, message: 'not found');

  @override
  Future<PokemonDetail> getPokemonDetail(String nameOrId) =>
      throw UnimplementedError();
}

// ---------------------------------------------------------------------------
// Container factory
// ---------------------------------------------------------------------------

ProviderContainer _makeContainer(PokemonRepository fakeRepo) =>
    ProviderContainer(overrides: [
      pokemonRepositoryProvider.overrideWithValue(fakeRepo),
    ]);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('PokemonSearchController — init', () {
    test('initial state is loading with empty items', () async {
      final container = _makeContainer(_MultiPageRepository());
      addTearDown(container.dispose);

      final state = container.read(pokemonSearchControllerProvider);

      expect(state.isLoading, isTrue);
      expect(state.items, isEmpty);
      expect(state.error, isNull);
    });

    test('loads first 100 items and clears loading flag', () async {
      final container = _makeContainer(_MultiPageRepository());
      addTearDown(container.dispose);

      await container
          .read(pokemonSearchControllerProvider.notifier)
          .init();

      final state = container.read(pokemonSearchControllerProvider);

      expect(state.isLoading, isFalse);
      expect(state.items.length, 100);
      expect(state.hasMore, isTrue);
      expect(state.hasPrevious, isFalse);
      expect(state.windowStartOffset, 0);
    });

    test('sets error message on NetworkException', () async {
      final container = _makeContainer(_ErrorRepository());
      addTearDown(container.dispose);

      await container
          .read(pokemonSearchControllerProvider.notifier)
          .init();

      final state = container.read(pokemonSearchControllerProvider);

      expect(state.isLoading, isFalse);
      expect(state.error, 'No internet connection.');
      expect(state.items, isEmpty);
    });
  });

  group('PokemonSearchController — loadMore (window growth)', () {
    late ProviderContainer container;
    late PokemonSearchController controller;

    setUp(() async {
      container = _makeContainer(_MultiPageRepository());
      controller = container.read(pokemonSearchControllerProvider.notifier);
      await controller.init(); // load page 0 → 100 items
    });

    tearDown(() => container.dispose());

    test('appends second page — 200 items, no window shift', () async {
      await controller.loadMore();

      final state = container.read(pokemonSearchControllerProvider);

      expect(state.items.length, 200);
      expect(state.windowStartOffset, 0);
      expect(state.hasPrevious, isFalse);
      expect(state.hasMore, isTrue);
    });

    test('appends third page — 300 items, no window shift', () async {
      await controller.loadMore(); // 200
      await controller.loadMore(); // 300

      final state = container.read(pokemonSearchControllerProvider);

      expect(state.items.length, 300);
      expect(state.windowStartOffset, 0);
    });

    test('fourth load drops leading page — window stays at 300, start shifts',
        () async {
      await controller.loadMore(); // 200
      await controller.loadMore(); // 300
      await controller.loadMore(); // would be 400 → drop first 100

      final state = container.read(pokemonSearchControllerProvider);

      expect(state.items.length, 300);
      expect(state.windowStartOffset, 100); // leading page dropped
      expect(state.hasPrevious, isTrue);
      expect(state.items.first.name, 'pokemon-101'); // id 101 is now first
    });

    test('no-op when hasMore is false', () async {
      /// 3-item repo — one page, no more.
      final container2 =
          _makeContainer(_FlatRepository(_fakeItems(1, 3)));
      addTearDown(container2.dispose);

      final ctrl2 =
          container2.read(pokemonSearchControllerProvider.notifier);
      await ctrl2.init();

      expect(container2.read(pokemonSearchControllerProvider).hasMore, isFalse);

      final sizeBefore =
          container2.read(pokemonSearchControllerProvider).items.length;
      await ctrl2.loadMore();

      expect(
          container2.read(pokemonSearchControllerProvider).items.length,
          sizeBefore);
    });
  });

  group('PokemonSearchController — loadPrevious (window shift back)', () {
    late ProviderContainer container;
    late PokemonSearchController controller;

    setUp(() async {
      container = _makeContainer(_MultiPageRepository());
      controller = container.read(pokemonSearchControllerProvider.notifier);
      await controller.init();    // 0..99
      await controller.loadMore(); // 0..199
      await controller.loadMore(); // 0..299
      await controller.loadMore(); // 100..399 (window shifted, start=100)
    });

    tearDown(() => container.dispose());

    test('setup: window at start=100, size=300', () {
      final s = container.read(pokemonSearchControllerProvider);
      expect(s.windowStartOffset, 100);
      expect(s.items.length, 300);
      expect(s.hasPrevious, isTrue);
    });

    test('loadPrevious prepends page 0, drops trailing page', () async {
      await controller.loadPrevious();

      final state = container.read(pokemonSearchControllerProvider);

      /// Window shifts back: now covers 0..299 again.
      expect(state.windowStartOffset, 0);
      expect(state.items.length, 300);
      expect(state.hasPrevious, isFalse); // back at origin
      expect(state.items.first.name, 'pokemon-1'); // starts from id 1
    });

    test('loadPrevious no-op when at offset 0', () async {
      await controller.loadPrevious(); // back to start
      final stateAtOrigin = container.read(pokemonSearchControllerProvider);
      expect(stateAtOrigin.hasPrevious, isFalse);

      final sizeBefore = stateAtOrigin.items.length;
      await controller.loadPrevious(); // should be no-op

      expect(
          container.read(pokemonSearchControllerProvider).items.length,
          sizeBefore);
    });
  });

  group('PokemonSearchController — search', () {
    late ProviderContainer container;
    late PokemonSearchController controller;

    setUp(() async {
      /// 5 named items for easy substring testing.
      final items = [
        const PokemonSummary(id: 1, name: 'bulbasaur', spriteUrl: ''),
        const PokemonSummary(id: 4, name: 'charmander', spriteUrl: ''),
        const PokemonSummary(id: 7, name: 'squirtle', spriteUrl: ''),
        const PokemonSummary(id: 25, name: 'pikachu', spriteUrl: ''),
        const PokemonSummary(id: 6, name: 'charizard', spriteUrl: ''),
      ];
      container = _makeContainer(_FlatRepository(items));
      controller = container.read(pokemonSearchControllerProvider.notifier);
      await controller.init();
    });

    tearDown(() => container.dispose());

    test('empty query returns all window items', () async {
      await controller.search('');
      expect(container.read(pokemonSearchControllerProvider).items.length, 5);
    });

    test('partial query filters correctly', () async {
      await controller.search('char');
      final items =
          container.read(pokemonSearchControllerProvider).items;
      expect(items.length, 2);
      expect(items.map((p) => p.name),
          containsAll(['charmander', 'charizard']));
    });

    test('search is case-insensitive', () async {
      await controller.search('BULB');
      expect(container.read(pokemonSearchControllerProvider).items.length, 1);
    });

    test('no-match returns empty items without error', () async {
      await controller.search('zzz');
      final state = container.read(pokemonSearchControllerProvider);
      expect(state.items, isEmpty);
      expect(state.error, isNull);
    });

    test('clearing query restores full window', () async {
      await controller.search('char');
      await controller.search('');
      expect(container.read(pokemonSearchControllerProvider).items.length, 5);
    });

    test('loadMore no-op while query is active', () async {
      await controller.search('char');
      final sizeBefore =
          container.read(pokemonSearchControllerProvider).items.length;
      await controller.loadMore();
      expect(
          container.read(pokemonSearchControllerProvider).items.length,
          sizeBefore);
    });
  });

  group('PokemonSearchController — retry', () {
    test('retry after error resets and reloads', () async {
      final container = _makeContainer(_ErrorRepository());
      addTearDown(container.dispose);

      final controller =
          container.read(pokemonSearchControllerProvider.notifier);
      await controller.init();

      expect(container.read(pokemonSearchControllerProvider).error, isNotNull);

      await controller.retry();

      final state = container.read(pokemonSearchControllerProvider);
      expect(state.error, isNotNull); // same error repo → error again
      expect(state.isLoading, isFalse);
    });
  });

  group('PokemonSearchController — error messages', () {
    test('NetworkException maps to correct message', () async {
      final container = _makeContainer(_ErrorRepository());
      addTearDown(container.dispose);

      await container
          .read(pokemonSearchControllerProvider.notifier)
          .init();

      expect(container.read(pokemonSearchControllerProvider).error,
          'No internet connection.');
    });

    test('ServerException maps to correct message', () async {
      final container = _makeContainer(_ServerErrorRepository());
      addTearDown(container.dispose);

      await container
          .read(pokemonSearchControllerProvider.notifier)
          .init();

      expect(container.read(pokemonSearchControllerProvider).error,
          'Server error (404).');
    });
  });
}
