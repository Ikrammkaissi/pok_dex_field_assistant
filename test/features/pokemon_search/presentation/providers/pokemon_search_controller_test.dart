/// Unit tests for [PokemonSearchController].
/// Uses hand-written fakes , no external mocking packages needed.
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

/// Large repo with 400 total Pokémon.
/// The controller decides the requested limit and offset.
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

/// Two-page repo for search auto-fetch tests.
/// Page 0: 95 common items + 5 rare items named "rare-N".
/// Page 1: 82 common items + 18 rare items named "rare-N". No more pages.
/// Querying "rare" yields 5 on page 0 (below _minSearchResults=20) →
/// auto-fetch loads page 1 → total 23 rare items → auto-fetch stops.
class _SparseSearchRepository implements PokemonRepository {
  static final _page0 = <PokemonSummary>[
    ..._fakeItems(1, 95),
    ...List.generate(5,
        (i) => PokemonSummary(id: 900 + i, name: 'rare-${900 + i}', spriteUrl: '')),
  ];
  static final _page1 = <PokemonSummary>[
    ..._fakeItems(101, 82),
    ...List.generate(18,
        (i) => PokemonSummary(id: 950 + i, name: 'rare-${950 + i}', spriteUrl: '')),
  ];

  int callCount = 0;

  @override
  Future<PokemonListPage> getPokemonList(
      {int limit = 100, int offset = 0}) async {
    callCount++;
    if (offset == 0) return PokemonListPage(items: _page0, hasMore: true);
    if (offset == 100) return PokemonListPage(items: _page1, hasMore: false);
    return PokemonListPage(items: [], hasMore: false);
  }

  @override
  Future<PokemonDetail> getPokemonDetail(String nameOrId) =>
      throw UnimplementedError();
}

/// Search repo with an empty-match gap during pagination.
/// Initial search page contains exactly 20 matches so auto-fetch stops.
/// The first paged fetch contains no new matches, and the second paged fetch
/// contains one new match. Search-mode loadMore should keep fetching until that
/// new visible item appears.
class _SearchGapRepository implements PokemonRepository {
  static final _page0 = <PokemonSummary>[
    ...List.generate(
        20,
        (i) => PokemonSummary(
            id: 1000 + i, name: 'target-${1000 + i}', spriteUrl: '')),
    ..._fakeItems(1, 80),
  ];

  static final _page1 = _fakeItems(101, 30);

  static final _page2 = <PokemonSummary>[
    const PokemonSummary(id: 2000, name: 'target-2000', spriteUrl: ''),
    ..._fakeItems(131, 29),
  ];

  int callCount = 0;

  @override
  Future<PokemonListPage> getPokemonList(
      {int limit = 100, int offset = 0}) async {
    callCount++;
    if (offset == 0) return PokemonListPage(items: _page0, hasMore: true);
    if (offset == 100) return PokemonListPage(items: _page1, hasMore: true);
    if (offset == 130) return PokemonListPage(items: _page2, hasMore: false);
    return PokemonListPage(items: [], hasMore: false);
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

Future<void> _loadMoreTimes(
  PokemonSearchController controller,
  int times,
) async {
  for (var i = 0; i < times; i++) {
    await controller.loadMore();
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('PokemonSearchController , init', () {
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

  group('PokemonSearchController , loadMore (list growth)', () {
    late ProviderContainer container;
    late PokemonSearchController controller;

    setUp(() async {
      container = _makeContainer(_MultiPageRepository());
      controller = container.read(pokemonSearchControllerProvider.notifier);
      await controller.init(); // load page 0 → 100 items
    });

    tearDown(() => container.dispose());

    test('appends 30 items after the initial 100', () async {
      await controller.loadMore();

      final state = container.read(pokemonSearchControllerProvider);

      expect(state.items.length, 130);
      expect(state.hasMore, isTrue);
    });

    test('keeps growing in 30-item steps', () async {
      await controller.loadMore(); // 130
      await controller.loadMore(); // 160
      await controller.loadMore(); // 190

      final state = container.read(pokemonSearchControllerProvider);

      expect(state.items.length, 190);
      expect(state.items.first.name, 'pokemon-1');
    });

    test('no-op when hasMore is false', () async {
      /// 3-item repo , one page, no more.
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

  group('PokemonSearchController , search', () {
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

    test('empty query returns all loaded items', () async {
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

    test('clearing query shows all loaded items without re-fetching', () async {
      await controller.search('char');
      await controller.search('');
      expect(container.read(pokemonSearchControllerProvider).items.length, 5);
    });

    test('clearing search shows all loaded items with no extra API call',
        () async {
      final repo = _MultiPageRepository();
      final container2 = _makeContainer(repo);
      addTearDown(container2.dispose);
      final ctrl2 =
          container2.read(pokemonSearchControllerProvider.notifier);
      await ctrl2.init();
      await _loadMoreTimes(ctrl2, 3); // list grows to 190 items

      await ctrl2.search('pokemon-1');

      final searchState = container2.read(pokemonSearchControllerProvider);
      expect(searchState.items.any((p) => p.name == 'pokemon-1'), isTrue);
      final callsBeforeClear = repo.callCount;

      await ctrl2.search('');

      final browseState = container2.read(pokemonSearchControllerProvider);
      // All loaded items visible, no re-fetch.
      expect(browseState.items.isNotEmpty, isTrue);
      expect(browseState.items.first.name, 'pokemon-1');
      expect(repo.callCount, callsBeforeClear); // zero new calls
    });
  });

  group('PokemonSearchController , search + pagination', () {
    test(
        'loadMore during search keeps fetching until a new matching item appears',
        () async {
      final repo = _SearchGapRepository();
      final container2 = _makeContainer(repo);
      addTearDown(container2.dispose);
      final ctrl2 =
          container2.read(pokemonSearchControllerProvider.notifier);
      await ctrl2.init();

      await ctrl2.search('target');
      expect(container2.read(pokemonSearchControllerProvider).items.length, 20);
      final callsBeforeLoadMore = repo.callCount;

      await ctrl2.loadMore();

      final state = container2.read(pokemonSearchControllerProvider);
      expect(state.items.length, 21);
      expect(state.items.last.name, 'target-2000');
      expect(state.hasMore, isFalse);
      expect(repo.callCount, callsBeforeLoadMore + 2);
    });

    test('loadMore during search fetches more and applies filter', () async {
      final container2 =
          _makeContainer(_MultiPageRepository()); // 400 generic items
      addTearDown(container2.dispose);
      final ctrl2 =
          container2.read(pokemonSearchControllerProvider.notifier);
      await ctrl2.init(); // 100 generic items

      await ctrl2.search('pokemon-1'); // matches pokemon-1, pokemon-10..19, pokemon-100..199
      final afterSearch =
          container2.read(pokemonSearchControllerProvider).items.length;
      /// Auto-fetch should kick in when results < 20.
      expect(afterSearch, greaterThanOrEqualTo(1));
    });

    test('auto-fetch loads pages until minSearchResults reached', () async {
      final container2 = _makeContainer(_SparseSearchRepository());
      addTearDown(container2.dispose);
      final ctrl2 =
          container2.read(pokemonSearchControllerProvider.notifier);
      await ctrl2.init();

      /// Page 0 has 5 "rare" items , below threshold of 20.
      /// Auto-fetch should trigger and load page 1 (18 more) → total 23.
      await ctrl2.search('rare');

      final state = container2.read(pokemonSearchControllerProvider);
      expect(state.items.length, 23); // 5 + 18 from both pages
      expect(state.items.every((p) => p.name.startsWith('rare')), isTrue);
    });

    test('clearing search shows all accumulated items without re-fetching',
        () async {
      final repo = _MultiPageRepository();
      final container2 = _makeContainer(repo);
      addTearDown(container2.dispose);
      final ctrl2 =
          container2.read(pokemonSearchControllerProvider.notifier);
      await ctrl2.init(); // 100 items

      await ctrl2.search('pokemon');
      await _loadMoreTimes(ctrl2, 3); // loads 90 more → 190 total in _items
      final callsBeforeClear = repo.callCount;

      await ctrl2.search('');

      final state = container2.read(pokemonSearchControllerProvider);
      // All 190 accumulated items visible — no re-fetch.
      expect(state.items.length, 190);
      expect(state.query, '');
      expect(repo.callCount, callsBeforeClear); // zero new calls
    });
  });

  group('PokemonSearchController , retry', () {
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

  group('PokemonSearchController , error messages', () {
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
