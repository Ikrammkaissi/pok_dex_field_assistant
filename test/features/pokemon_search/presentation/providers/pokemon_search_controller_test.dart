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
import 'package:pok_dex_field_assistant/features/pokemon_search/presentation/providers/pokemon_search_state.dart';

// ---------------------------------------------------------------------------
// Fake repositories
// ---------------------------------------------------------------------------

/// Pre-built list items used across tests.
final _items = [
  const PokemonSummary(id: 1, name: 'bulbasaur', spriteUrl: ''),
  const PokemonSummary(id: 4, name: 'charmander', spriteUrl: ''),
  const PokemonSummary(id: 7, name: 'squirtle', spriteUrl: ''),
];

/// Repository that returns the fixture list and delegates [searchPokemon]
/// to a simple client-side substring filter — same logic as the real impl.
class _FakeRepository implements PokemonRepository {
  /// Track call count to verify caching behaviour.
  int getPokemonListCallCount = 0;

  @override
  Future<List<PokemonSummary>> getPokemonList({int limit = 151}) async {
    getPokemonListCallCount++;
    return _items;
  }

  @override
  Future<List<PokemonSummary>> searchPokemon(String query) async {
    /// Delegate to getPokemonList so caching tests still work.
    final all = await getPokemonList();
    if (query.isEmpty) return all;
    final lower = query.toLowerCase();
    return all.where((p) => p.name.contains(lower)).toList();
  }

  @override
  Future<PokemonDetail> getPokemonDetail(String nameOrId) async {
    throw UnimplementedError('not needed in these tests');
  }
}

/// Repository that always throws a [NetworkException] on [getPokemonList].
class _ErrorRepository implements PokemonRepository {
  @override
  Future<List<PokemonSummary>> getPokemonList({int limit = 151}) async {
    throw const NetworkException('no internet');
  }

  @override
  Future<List<PokemonSummary>> searchPokemon(String query) async {
    throw const NetworkException('no internet');
  }

  @override
  Future<PokemonDetail> getPokemonDetail(String nameOrId) async {
    throw UnimplementedError('not needed in these tests');
  }
}

// ---------------------------------------------------------------------------
// Helper — build an isolated controller with a fake repository
// ---------------------------------------------------------------------------

/// Creates a [PokemonSearchController] inside a [ProviderContainer] so
/// Riverpod's lifecycle management still applies.
PokemonSearchController _makeController(
    PokemonRepository fakeRepo, ProviderContainer container) {
  return container.read(pokemonSearchControllerProvider.notifier);
}

ProviderContainer _makeContainer(PokemonRepository fakeRepo) {
  return ProviderContainer(
    overrides: [
      /// Swap the real repository for the fake.
      pokemonRepositoryProvider.overrideWithValue(fakeRepo),
    ],
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('PokemonSearchController — init', () {
    test('initial state is loading with empty items', () async {
      final repo = _FakeRepository();
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      /// Read state synchronously before init completes.
      final state = container.read(pokemonSearchControllerProvider);

      expect(state.isLoading, isTrue);
      expect(state.items, isEmpty);
      expect(state.error, isNull);
    });

    test('loads items and clears loading flag after init', () async {
      final repo = _FakeRepository();
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      /// Wait for init to complete.
      final controller =
          container.read(pokemonSearchControllerProvider.notifier);
      await controller.init();

      final state = container.read(pokemonSearchControllerProvider);

      expect(state.isLoading, isFalse);
      expect(state.items.length, 3);
      expect(state.error, isNull);
    });

    test('sets error message on NetworkException', () async {
      final container = _makeContainer(_ErrorRepository());
      addTearDown(container.dispose);

      final controller =
          container.read(pokemonSearchControllerProvider.notifier);
      await controller.init();

      final state = container.read(pokemonSearchControllerProvider);

      expect(state.isLoading, isFalse);
      expect(state.error, equals('No internet connection.'));
      expect(state.items, isEmpty);
    });
  });

  group('PokemonSearchController — search', () {
    late ProviderContainer container;
    late PokemonSearchController controller;

    setUp(() async {
      container = _makeContainer(_FakeRepository());
      controller = container.read(pokemonSearchControllerProvider.notifier);
      /// Ensure initial load is done before each test.
      await controller.init();
    });

    tearDown(() => container.dispose());

    test('empty query returns all items', () async {
      await controller.search('');
      final state = container.read(pokemonSearchControllerProvider);

      expect(state.items.length, 3);
    });

    test('partial query filters correctly', () async {
      await controller.search('char');
      final state = container.read(pokemonSearchControllerProvider);

      expect(state.items.length, 1);
      expect(state.items.first.name, 'charmander');
    });

    test('search is case-insensitive', () async {
      await controller.search('BULB');
      final state = container.read(pokemonSearchControllerProvider);

      expect(state.items.length, 1);
      expect(state.items.first.name, 'bulbasaur');
    });

    test('no-match query returns empty items and no error', () async {
      await controller.search('zzz');
      final state = container.read(pokemonSearchControllerProvider);

      expect(state.items, isEmpty);
      expect(state.error, isNull);
      expect(state.isLoading, isFalse);
    });

    test('updates query field on state', () async {
      await controller.search('squirt');
      final state = container.read(pokemonSearchControllerProvider);

      expect(state.query, 'squirt');
    });
  });

  group('PokemonSearchController — retry', () {
    test('retry after error resets state and reloads', () async {
      /// Start with an error repo, then observe the error state.
      final errorRepo = _ErrorRepository();
      final container = _makeContainer(errorRepo);
      addTearDown(container.dispose);

      final controller =
          container.read(pokemonSearchControllerProvider.notifier);
      await controller.init();

      final errorState = container.read(pokemonSearchControllerProvider);
      expect(errorState.error, isNotNull);

      /// Retry with the same repo — should produce another error (not crash).
      await controller.retry();

      final afterRetry = container.read(pokemonSearchControllerProvider);
      expect(afterRetry.error, isNotNull);
      expect(afterRetry.isLoading, isFalse);
    });
  });

  group('PokemonSearchController — error messages', () {
    /// Verify each exception type maps to the correct user-facing string.
    test('NetworkException produces correct message', () async {
      final container = _makeContainer(_ErrorRepository());
      addTearDown(container.dispose);

      final controller =
          container.read(pokemonSearchControllerProvider.notifier);
      await controller.init();

      expect(
        container.read(pokemonSearchControllerProvider).error,
        'No internet connection.',
      );
    });

    test('ServerException produces correct message', () async {
      /// Inline fake that throws a ServerException.
      final repo = _ServerErrorRepository();
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      final controller =
          container.read(pokemonSearchControllerProvider.notifier);
      await controller.init();

      expect(
        container.read(pokemonSearchControllerProvider).error,
        'Server error (404).',
      );
    });
  });
}

/// Repository that always throws [ServerException] 404.
class _ServerErrorRepository implements PokemonRepository {
  @override
  Future<List<PokemonSummary>> getPokemonList({int limit = 151}) async {
    throw const ServerException(statusCode: 404, message: 'not found');
  }

  @override
  Future<List<PokemonSummary>> searchPokemon(String query) async {
    throw const ServerException(statusCode: 404, message: 'not found');
  }

  @override
  Future<PokemonDetail> getPokemonDetail(String nameOrId) async {
    throw UnimplementedError();
  }
}
